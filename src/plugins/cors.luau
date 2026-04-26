local Types = require("../types")

type App = Types.App
type Request = Types.Request
type Response = Types.Response

export type CorsOptions = {
	origin: (string | { string })?,
	methods: { string }?,
	allowedHeaders: { string }?,
	exposedHeaders: { string }?,
	credentials: boolean?,
}

type CorsConfig = {
	origin: string | { string },
	methods: { string },
	allowedHeaders: { string }?,
	exposedHeaders: { string }?,
	credentials: boolean,
}

local DEFAULT_METHODS = { "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS" }

local Cors = {}

local function copyStringList(value: unknown, name: string): { string }
	if type(value) ~= "table" then
		error("[flare] cors " .. name .. " option must be an array of strings", 3)
	end

	local result: { string } = {}
	for index, item in value :: { unknown } do
		if type(index) ~= "number" or type(item) ~= "string" then
			error("[flare] cors " .. name .. " option must be an array of strings", 3)
		end

		table.insert(result, item)
	end

	return result
end

local function originContainsWildcard(origin: string | { string }): boolean
	if type(origin) == "string" then
		return origin == "*"
	end

	for _, item in origin do
		if item == "*" then
			return true
		end
	end

	return false
end

local function validateOrigin(value: unknown): string | { string }
	if value == nil then
		return "*"
	end

	if type(value) == "string" then
		return value
	end

	return copyStringList(value, "origin")
end

local function validateOptions(options: { [string]: unknown }?): CorsConfig
	local source = (options or {}) :: CorsOptions

	if type(source) ~= "table" then
		error("[flare] cors options must be a table", 3)
	end

	if source.credentials ~= nil and type(source.credentials) ~= "boolean" then
		error("[flare] cors credentials option must be a boolean", 3)
	end

	local origin = validateOrigin(source.origin)
	local credentials = source.credentials == true

	if credentials and originContainsWildcard(origin) then
		error("[flare] cors origin cannot be '*' when credentials are enabled", 3)
	end

	return {
		origin = origin,
		methods = if source.methods == nil then DEFAULT_METHODS else copyStringList(source.methods, "methods"),
		allowedHeaders = if source.allowedHeaders == nil
			then nil
			else copyStringList(source.allowedHeaders, "allowedHeaders"),
		exposedHeaders = if source.exposedHeaders == nil
			then nil
			else copyStringList(source.exposedHeaders, "exposedHeaders"),
		credentials = credentials,
	}
end

local function join(values: { string }): string
	return table.concat(values, ", ")
end

local function resolveOrigin(config: CorsConfig, requestOrigin: string?): string?
	local origin = config.origin

	if type(origin) == "string" then
		return origin
	end

	if requestOrigin == nil then
		return nil
	end

	for _, allowed in origin do
		if allowed == requestOrigin then
			return requestOrigin
		end
	end

	return nil
end

local function setCorsHeaders(
	headers: { [string]: string },
	config: CorsConfig,
	request: Request,
	preflight: boolean
): ()
	local allowOrigin = resolveOrigin(config, request.headers.origin)
	if allowOrigin ~= nil then
		headers["access-control-allow-origin"] = allowOrigin
	end

	if type(config.origin) == "table" then
		local vary = headers.vary
		headers.vary = if vary == nil then "Origin" else vary .. ", Origin"
	end

	if config.credentials then
		headers["access-control-allow-credentials"] = "true"
	end

	if preflight then
		headers["access-control-allow-methods"] = join(config.methods)

		local allowedHeaders = config.allowedHeaders
		if allowedHeaders ~= nil then
			headers["access-control-allow-headers"] = join(allowedHeaders)
		elseif request.headers["access-control-request-headers"] ~= nil then
			headers["access-control-allow-headers"] = request.headers["access-control-request-headers"]
		end
	elseif config.exposedHeaders ~= nil then
		headers["access-control-expose-headers"] = join(config.exposedHeaders)
	end
end

local function cloneHeaders(headers: { [string]: string }): { [string]: string }
	local result: { [string]: string } = {}

	for name, value in headers do
		result[name] = value
	end

	return result
end

local function withCorsHeaders(config: CorsConfig, request: Request, response: Response, preflight: boolean): Response
	local headers = cloneHeaders(response.headers)
	setCorsHeaders(headers, config, request, preflight)

	return {
		status = response.status,
		headers = headers,
		body = response.body,
	}
end

local function hookTarget(app: App): App
	return (rawget(app :: any, "_parentScope") :: App?) or app
end

function Cors.plugin(app: App, options: { [string]: unknown }?): ()
	local config = validateOptions(options)
	local target = hookTarget(app)

	target:options("/*", function(request: Request)
		return withCorsHeaders(config, request, {
			status = 204,
			headers = {},
			body = nil,
		}, true)
	end)

	target:hook("onSend", function(request: Request, _reply, value: unknown?)
		return withCorsHeaders(config, request, value :: Response, false)
	end)
end

return Cors.plugin
