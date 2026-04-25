local Request = require("./request")
local Reply = require("./reply")
local Routing = require("./routing")
local Types = require("./types")

type App = Types.App
type AppOptions = Types.AppOptions
type ErrorHandler = Types.ErrorHandler
type Handler = Types.Handler
type HandlerResult = Types.HandlerResult
type ReplyType = Types.Reply
type RequestType = Types.Request
type Response = Types.Response
type RequestSource = Request.RequestSource

type ExecutableApp = App & {
	_options: AppOptions,
	_notFoundHandler: Handler?,
	_errorHandler: ErrorHandler?,
}

local Executor = {}

local function defaultNotFoundHandler(_request: RequestType, reply: ReplyType): HandlerResult
	return reply:code(404):send({
		error = "Not Found",
	})
end

local function defaultErrorHandler(_request: RequestType, reply: ReplyType, _err: unknown): HandlerResult
	return reply:code(500):send({
		error = "Internal Server Error",
	})
end

local function responseFromResult(reply: ReplyType, result: HandlerResult): Response
	if reply.sent then
		local sent = Reply.sentResponse(reply)
		if sent ~= nil then
			return sent
		end
	end

	return reply:send(result)
end

local function runHandler(handler: Handler, request: RequestType, reply: ReplyType): (boolean, Response | unknown)
	local ok, result = pcall(handler, request, reply)
	if not ok then
		return false, result
	end

	local normalizedOk, response = pcall(responseFromResult, reply, result)
	if not normalizedOk then
		return false, response
	end

	return true, response
end

local function runErrorHandler(handler: ErrorHandler, request: RequestType, reply: ReplyType, err: unknown): Response
	local ok, result = pcall(handler, request, reply, err)
	if ok then
		local normalizedOk, response = pcall(responseFromResult, reply, result)
		if normalizedOk then
			return response
		end
	end

	local fallbackReply = Reply.create()
	return defaultErrorHandler(request, fallbackReply, err) :: Response
end

function Executor.execute(app: App, source: RequestSource): Response
	local state = (app :: unknown) :: ExecutableApp
	local request = Request.create(source, state._options)
	local reply = Reply.create()
	local match = Routing.match(app, request.method, request.path)

	if match.kind == "found" then
		request.params = match.params
		local ok, responseOrError = runHandler(match.route.handler, request, reply)
		if ok then
			return responseOrError :: Response
		end

		local errorReply = Reply.create()
		return runErrorHandler(state._errorHandler or defaultErrorHandler, request, errorReply, responseOrError)
	end

	local notFoundHandler = state._notFoundHandler or defaultNotFoundHandler
	local ok, responseOrError = runHandler(notFoundHandler, request, reply)
	if ok then
		return responseOrError :: Response
	end

	local errorReply = Reply.create()
	return runErrorHandler(state._errorHandler or defaultErrorHandler, request, errorReply, responseOrError)
end

return Executor
