local json = require("@std/json")
local Types = require("./types")

type AppOptions = Types.AppOptions
type Request = Types.Request

export type RequestSource = {
	method: string?,
	path: string?,
	url: string?,
	queryString: string?,
	params: { [string]: string }?,
	headers: { [string]: string }?,
	body: string?,
	readBody: (() -> string)?,
	state: { [string]: unknown }?,
	env: { [string]: string }?,
	remoteAddress: string?,
}

type ParsedQuery = { [string]: string | { string } }

type RequestInternal = Request & {
	_bodyLimit: number?,
	_bodyReader: (() -> string)?,
	_bodyText: string?,
	_bodyTextRead: boolean,
	_jsonRead: boolean,
	_jsonValue: unknown?,
	_formRead: boolean,
	_formValue: ParsedQuery?,
	_queryParsed: boolean,
	_queryValue: ParsedQuery?,
}

local RequestModule = {}

local RequestMethods = {}
RequestMethods.__index = RequestMethods

local function normalizeHeaderName(name: string): string
	return string.lower(name)
end

local function normalizeHeaders(headers: { [string]: string }?): { [string]: string }
	local normalized: { [string]: string } = {}

	if headers == nil then
		return normalized
	end

	for name, value in headers do
		if type(name) ~= "string" then
			error("[flare] request header names must be strings", 3)
		end

		if type(value) ~= "string" then
			error("[flare] request header values must be strings", 3)
		end

		normalized[normalizeHeaderName(name)] = value
	end

	return normalized
end

local function splitUrl(url: string): (string, string?)
	local queryStart = string.find(url, "?", 1, true)
	if queryStart == nil then
		return url, nil
	end

	return string.sub(url, 1, queryStart - 1), string.sub(url, queryStart + 1)
end

local function percentDecode(value: string): string
	local withSpaces = string.gsub(value, "+", " ")

	local decoded = string.gsub(withSpaces, "%%(%x%x)", function(hex: string): string
		local byte = tonumber(hex, 16)
		if byte == nil then
			return "%" .. hex
		end

		return string.char(byte :: number)
	end)

	return decoded
end

local function putRepeated(target: ParsedQuery, key: string, value: string): ()
	local existing = target[key]

	if existing == nil then
		target[key] = value
	elseif type(existing) == "table" then
		table.insert(existing, value)
	else
		target[key] = { existing, value }
	end
end

local function parseKeyValueString(source: string?): ParsedQuery
	local parsed: ParsedQuery = {}

	if source == nil or source == "" then
		return parsed
	end

	for _, pair in string.split(source, "&") do
		if pair == "" then
			continue
		end

		local equals = string.find(pair, "=", 1, true)
		local rawKey: string
		local rawValue: string

		if equals == nil then
			rawKey = pair
			rawValue = ""
		else
			rawKey = string.sub(pair, 1, equals - 1)
			rawValue = string.sub(pair, equals + 1)
		end

		putRepeated(parsed, percentDecode(rawKey), percentDecode(rawValue))
	end

	return parsed
end

local function parseQueryFor(request: RequestInternal): ParsedQuery
	if request._queryParsed and request._queryValue ~= nil then
		return request._queryValue
	end

	local parsed = parseKeyValueString(request.queryString)
	request._queryValue = parsed
	request._queryParsed = true

	return parsed
end

local QueryProxy = {}

function QueryProxy.__index(proxy: any, key: unknown): (string | { string })?
	local request = rawget(proxy, "_request") :: RequestInternal
	if type(key) ~= "string" then
		return nil
	end

	return parseQueryFor(request)[key]
end

function QueryProxy.__iter(proxy: any)
	local request = rawget(proxy, "_request") :: RequestInternal
	return next, parseQueryFor(request)
end

local function createQueryProxy(request: RequestInternal): ParsedQuery
	return setmetatable({
		_request = request,
	}, QueryProxy) :: any
end

local function readBodyText(request: RequestInternal): string
	if request._bodyTextRead then
		return request._bodyText or ""
	end

	local text = ""
	if request._bodyReader ~= nil then
		text = request._bodyReader()
	elseif type(request.body) == "string" then
		text = request.body :: string
	end

	if request._bodyLimit ~= nil and #text > request._bodyLimit then
		error("[flare] request body exceeded configured bodyLimit", 3)
	end

	request._bodyText = text
	request._bodyTextRead = true
	request.body = text

	return text
end

function RequestMethods:text(): string
	return readBodyText((self :: unknown) :: RequestInternal)
end

function RequestMethods:json(): unknown
	local request = (self :: unknown) :: RequestInternal
	if request._jsonRead then
		return request._jsonValue
	end

	local parsed = json.deserialize(readBodyText(request))
	request._jsonRead = true
	request._jsonValue = parsed
	request.body = parsed

	return parsed
end

function RequestMethods:form(): ParsedQuery
	local request = (self :: unknown) :: RequestInternal
	if request._formRead and request._formValue ~= nil then
		return request._formValue
	end

	local parsed = parseKeyValueString(readBodyText(request))
	request._formRead = true
	request._formValue = parsed
	request.body = parsed

	return parsed
end

local function normalizeSource(source: RequestSource): (string, string, string, string?)
	local method = source.method or "GET"
	local url = source.url
	local path = source.path
	local queryString = source.queryString

	if url ~= nil and (path == nil or queryString == nil) then
		local urlPath, urlQueryString = splitUrl(url)

		if path == nil then
			path = if urlPath == "" then "/" else urlPath
		end

		if queryString == nil then
			queryString = urlQueryString
		end
	end

	path = path or "/"
	url = url or if queryString == nil or queryString == "" then path else path .. "?" .. queryString

	return method, path, url, queryString
end

function RequestModule.create(source: RequestSource, options: AppOptions?): Request
	if type(source) ~= "table" then
		error("[flare] request source must be a table", 2)
	end

	local method, path, url, queryString = normalizeSource(source)
	local request: RequestInternal = setmetatable({
		method = string.upper(method),
		path = path,
		url = url,
		queryString = queryString,
		params = source.params or {},
		query = {},
		headers = normalizeHeaders(source.headers),
		body = source.body,
		state = source.state or {},
		env = source.env or {},
		remoteAddress = source.remoteAddress,

		_bodyLimit = if options == nil then nil else options.bodyLimit,
		_bodyReader = source.readBody,
		_bodyText = nil,
		_bodyTextRead = false,
		_jsonRead = false,
		_jsonValue = nil,
		_formRead = false,
		_formValue = nil,
		_queryParsed = false,
		_queryValue = nil,
	}, RequestMethods) :: any

	request.query = createQueryProxy(request)

	return request
end

return RequestModule
