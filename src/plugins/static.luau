local Fs = require("@std/fs")
local Path = require("@std/path")

local Types = require("../types")

type App = Types.App
type Request = Types.Request
type Response = Types.Response

export type StaticOptions = {
	root: string,
	prefix: string?,
	index: (string | { string })?,
	cacheControl: string?,
	spaFallback: string?,
}

type StaticConfig = {
	root: string,
	prefix: string,
	route: string,
	index: { string },
	cacheControl: string?,
	spaFallback: string?,
}

local Static = {}

local MIME_TYPES: { [string]: string } = {
	[".css"] = "text/css",
	[".gif"] = "image/gif",
	[".html"] = "text/html",
	[".jpeg"] = "image/jpeg",
	[".jpg"] = "image/jpeg",
	[".js"] = "application/javascript",
	[".json"] = "application/json",
	[".png"] = "image/png",
	[".svg"] = "image/svg+xml",
	[".txt"] = "text/plain",
	[".wasm"] = "application/wasm",
	[".webp"] = "image/webp",
}

local function copyIndex(value: unknown): { string }
	if value == nil then
		return { "index.html" }
	end

	if type(value) == "string" then
		return { value }
	end

	if type(value) ~= "table" then
		error("[flare] static index option must be a string or array of strings", 3)
	end

	local result: { string } = {}
	for index, item in value :: { unknown } do
		if type(index) ~= "number" or type(item) ~= "string" then
			error("[flare] static index option must be a string or array of strings", 3)
		end

		table.insert(result, item)
	end

	return result
end

local function normalizePrefix(prefix: string?): string
	local value = prefix or "/"

	if type(value) ~= "string" or value == "" then
		error("[flare] static prefix option must be a non-empty string", 3)
	end

	if string.sub(value, 1, 1) ~= "/" then
		error("[flare] static prefix option must start with '/'", 3)
	end

	if #value > 1 and string.sub(value, -1) == "/" then
		value = string.sub(value, 1, -2)
	end

	return value
end

local function validateOptions(options: { [string]: unknown }?): StaticConfig
	if type(options) ~= "table" then
		error("[flare] static options must be a table", 3)
	end

	local source = options :: StaticOptions
	if type(source.root) ~= "string" or source.root == "" then
		error("[flare] static root option must be a non-empty string", 3)
	end

	if source.cacheControl ~= nil and type(source.cacheControl) ~= "string" then
		error("[flare] static cacheControl option must be a string", 3)
	end

	if source.spaFallback ~= nil and type(source.spaFallback) ~= "string" then
		error("[flare] static spaFallback option must be a string", 3)
	end

	local prefix = normalizePrefix(source.prefix)

	return {
		root = source.root,
		prefix = prefix,
		route = if prefix == "/" then "/*" else prefix .. "/*",
		index = copyIndex(source.index),
		cacheControl = source.cacheControl,
		spaFallback = source.spaFallback,
	}
end

local function percentDecode(value: string): string
	local decoded = string.gsub(value, "%%(%x%x)", function(hex: string): string
		local byte = tonumber(hex, 16)
		if byte == nil then
			return "%" .. hex
		end

		return string.char(byte :: number)
	end)

	return decoded
end

local function pathTail(config: StaticConfig, requestPath: string): string?
	if config.prefix == "/" then
		return string.sub(requestPath, 2)
	end

	if requestPath == config.prefix then
		return ""
	end

	local prefix = config.prefix .. "/"
	if string.sub(requestPath, 1, #prefix) ~= prefix then
		return nil
	end

	return string.sub(requestPath, #prefix + 1)
end

local function safeSegments(tail: string): { string }?
	if tail == "" then
		return {}
	end

	local result: { string } = {}
	for _, rawSegment in string.split(tail, "/") do
		local segment = percentDecode(rawSegment)

		if segment == "" or segment == "." or segment == ".." then
			return nil
		end

		if string.find(segment, "/", 1, true) ~= nil or string.find(segment, "\\", 1, true) ~= nil then
			return nil
		end

		table.insert(result, segment)
	end

	return result
end

local function pathFromSegments(root: string, segments: { string }): Path.Path
	local current: Path.Pathlike = root

	for _, segment in segments do
		current = Path.join(current, segment)
	end

	return Path.normalize(current)
end

local function mimeType(path: Path.Pathlike): string
	return MIME_TYPES[string.lower(Path.extname(path))] or "application/octet-stream"
end

local function responseForFile(config: StaticConfig, path: Path.Pathlike): Response
	local headers = {
		["content-type"] = mimeType(path),
	}

	if config.cacheControl ~= nil then
		headers["cache-control"] = config.cacheControl
	end

	return {
		status = 200,
		headers = headers,
		body = Fs.readFileToString(path),
	}
end

local function fileIfExists(path: Path.Pathlike): Path.Pathlike?
	if Fs.exists(path) and Fs.type(path) == "file" then
		return path
	end

	return nil
end

local function indexFile(config: StaticConfig, directory: Path.Pathlike): Path.Pathlike?
	for _, index in config.index do
		local path = Path.join(directory, index)
		local found = fileIfExists(path)
		if found ~= nil then
			return found
		end
	end

	return nil
end

local function requestedFile(config: StaticConfig, requestPath: string): Path.Pathlike?
	local tail = pathTail(config, requestPath)
	if tail == nil then
		return nil
	end

	local segments = safeSegments(tail)
	if segments == nil then
		return nil
	end

	local candidate = pathFromSegments(config.root, segments)
	if Fs.exists(candidate) then
		if Fs.type(candidate) == "file" then
			return candidate
		elseif Fs.type(candidate) == "dir" then
			return indexFile(config, candidate)
		end
	end

	return nil
end

local function fallbackFile(config: StaticConfig): Path.Pathlike?
	if config.spaFallback == nil then
		return nil
	end

	local segments = safeSegments(config.spaFallback)
	if segments == nil then
		return nil
	end

	return fileIfExists(pathFromSegments(config.root, segments))
end

function Static.plugin(app: App, options: { [string]: unknown }?): ()
	local config = validateOptions(options)

	app:get(config.route, function(request: Request)
		local file = requestedFile(config, request.path) or fallbackFile(config)
		if file == nil then
			return {
				status = 404,
				headers = {},
				body = nil,
			} :: Response
		end

		return responseForFile(config, file)
	end)
end

return Static.plugin
