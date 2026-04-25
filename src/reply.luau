local json = require("@std/json")
local ResponseModule = require("./response")
local Types = require("./types")

type Reply = Types.Reply
type Response = Types.Response

type ReplyState = {
	statusCode: number,
	sent: boolean,
	_headers: { [string]: string },
	_statusSet: boolean,
	_response: Response?,
}

type ReplyInternal = Reply & ReplyState

local ReplyModule = {}

local ReplyMethods = {}
ReplyMethods.__index = ReplyMethods

local function normalizeHeaderName(name: string): string
	return string.lower(name)
end

local function contentTypeIsSet(headers: { [string]: string }): boolean
	return headers["content-type"] ~= nil
end

local function copyHeaders(headers: { [string]: string }): { [string]: string }
	local result: { [string]: string } = {}

	for name, value in headers do
		result[normalizeHeaderName(name)] = value
	end

	return result
end

local function mergeHeaders(base: { [string]: string }, overrides: { [string]: string }): { [string]: string }
	local result = copyHeaders(base)

	for name, value in overrides do
		result[normalizeHeaderName(name)] = value
	end

	return result
end

local function isResponse(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end

	local candidate = value :: { [string]: unknown }
	return type(candidate.status) == "number"
		and type(candidate.headers) == "table"
		and (candidate.body == nil or type(candidate.body) == "string")
end

local function completeResponse(status: number, headers: { [string]: string }, body: string?): Response
	return ResponseModule.response({
		status = status,
		headers = headers,
		body = body,
	})
end

local function ensureNotSent(self: ReplyInternal): ()
	if self.sent then
		error("[flare] reply was already sent", 2)
	end
end

local function markSent(self: ReplyInternal, response: Response): Response
	self.sent = true
	self._response = response
	return response
end

function ReplyMethods:code(status: number): Reply
	ensureNotSent(self)

	self.statusCode = status
	self._statusSet = true

	return self
end

function ReplyMethods:status(status: number): Reply
	return self:code(status)
end

function ReplyMethods:header(name: string, value: string): Reply
	ensureNotSent(self)

	if type(name) ~= "string" then
		error("[flare] response header name must be a string", 2)
	end

	if type(value) ~= "string" then
		error("[flare] response header value must be a string", 2)
	end

	self._headers[normalizeHeaderName(name)] = value

	return self
end

function ReplyMethods:headers(headers: { [string]: string }): Reply
	ensureNotSent(self)

	for name, value in headers do
		self:header(name, value)
	end

	return self
end

function ReplyMethods:type(contentType: string): Reply
	return self:header("content-type", contentType)
end

function ReplyMethods:send(body: unknown?): Response
	ensureNotSent(self)

	if isResponse(body) then
		local raw = body :: Response
		local headers = mergeHeaders(self._headers, raw.headers)
		local status = if self._statusSet then self.statusCode else raw.status

		return markSent(self, completeResponse(status, headers, raw.body))
	end

	local headers = copyHeaders(self._headers)
	local status = self.statusCode
	local responseBody: string? = nil
	local bodyType = type(body)

	if body == nil then
		if not self._statusSet then
			status = 204
		end
	elseif bodyType == "string" then
		responseBody = body :: string

		if not contentTypeIsSet(headers) then
			headers["content-type"] = "text/plain"
		end
	elseif bodyType == "number" or bodyType == "boolean" then
		responseBody = tostring(body)

		if not contentTypeIsSet(headers) then
			headers["content-type"] = "text/plain"
		end
	elseif bodyType == "table" then
		responseBody = json.serialize(body :: any)

		if not contentTypeIsSet(headers) then
			headers["content-type"] = "application/json"
		end
	else
		error("[flare] unsupported reply body type '" .. bodyType .. "'", 2)
	end

	return markSent(self, completeResponse(status, headers, responseBody))
end

function ReplyMethods:redirect(location: string, status: number?): Response
	ensureNotSent(self)

	local redirectStatus = status or 302
	self:header("location", location)

	return markSent(self, completeResponse(redirectStatus, self._headers, nil))
end

function ReplyMethods:empty(status: number?): Response
	ensureNotSent(self)

	local emptyStatus = status or self.statusCode

	return markSent(self, completeResponse(emptyStatus, self._headers, nil))
end

function ReplyModule.create(): Reply
	local reply: ReplyInternal = setmetatable({
		statusCode = 200,
		sent = false,
		_headers = {},
		_statusSet = false,
		_response = nil :: Response?,
	}, ReplyMethods) :: any

	return reply
end

function ReplyModule.sentResponse(reply: Reply): Response?
	return ((reply :: unknown) :: ReplyInternal)._response
end

return ReplyModule
