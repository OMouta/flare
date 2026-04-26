local Request = require("./request")
local Reply = require("./reply")
local Routing = require("./routing")
local Hooks = require("./hooks")
local Types = require("./types")

type App = Types.App
type AppOptions = Types.AppOptions
type ErrorHandler = Types.ErrorHandler
type Handler = Types.Handler
type HandlerResult = Types.HandlerResult
type HookChains = Hooks.HookChains
type HookHandler = Types.HookHandler
type ReplyType = Types.Reply
type RequestType = Types.Request
type Response = Types.Response
type RequestSource = Request.RequestSource

type ExecutableApp = App & {
	_options: AppOptions,
	_notFoundHandler: Handler?,
	_errorHandler: ErrorHandler?,
	_compiledHooks: HookChains?,
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

local function maybeResponseFromHookResult(reply: ReplyType, result: HandlerResult): Response?
	if result == nil and not reply.sent then
		return nil
	end

	return responseFromResult(reply, result)
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

local function runHook(
	hook: HookHandler,
	request: RequestType,
	reply: ReplyType,
	value: unknown?
): (boolean, Response? | unknown)
	local ok, result = pcall(hook, request, reply, value)
	if not ok then
		return false, result
	end

	local normalizedOk, response = pcall(maybeResponseFromHookResult, reply, result)
	if not normalizedOk then
		return false, response
	end

	return true, response
end

local function runShortCircuitHooks(
	hooks: { HookHandler },
	request: RequestType,
	reply: ReplyType
): (boolean, Response? | unknown)
	for _, hook in hooks do
		local ok, responseOrError = runHook(hook, request, reply, nil)
		if not ok or responseOrError ~= nil then
			return ok, responseOrError
		end
	end

	return true, nil
end

local function runOnSendHooks(
	hooks: { HookHandler },
	request: RequestType,
	response: Response
): (boolean, Response | unknown)
	local current = response

	for _, hook in hooks do
		local reply = Reply.create()
		local ok, responseOrError = runHook(hook, request, reply, current)
		if not ok then
			return false, responseOrError
		end

		if responseOrError ~= nil then
			current = responseOrError :: Response
		end
	end

	return true, current
end

local function runOnResponseHooks(hooks: { HookHandler }, request: RequestType, response: Response): ()
	for _, hook in hooks do
		local reply = Reply.create()
		pcall(hook, request, reply, response)
	end
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

local function applyOnErrorHooks(
	hooks: { HookHandler },
	request: RequestType,
	err: unknown,
	response: Response
): Response
	local current = response

	for _, hook in hooks do
		local reply = Reply.create()
		local ok, responseOrError = runHook(hook, request, reply, err)
		if ok and responseOrError ~= nil then
			current = responseOrError :: Response
		end
	end

	return current
end

local function createErrorResponse(
	state: ExecutableApp,
	hooks: HookChains,
	request: RequestType,
	err: unknown
): Response
	local errorReply = Reply.create()
	local response = runErrorHandler(state._errorHandler or defaultErrorHandler, request, errorReply, err)

	return applyOnErrorHooks(hooks.onError, request, err, response)
end

local function finalizeResponse(
	state: ExecutableApp,
	hooks: HookChains,
	request: RequestType,
	response: Response
): Response
	local ok, sentOrError = runOnSendHooks(hooks.onSend, request, response)
	local finalResponse: Response

	if ok then
		finalResponse = sentOrError :: Response
	else
		finalResponse = createErrorResponse(state, hooks, request, sentOrError)
	end

	runOnResponseHooks(hooks.onResponse, request, finalResponse)

	return finalResponse
end

local function appendHooks(target: { HookHandler }, source: { HookHandler }): { HookHandler }
	for _, hook in source do
		table.insert(target, hook)
	end

	return target
end

local function combineHooks(global: HookChains, routeHooks): HookChains
	return {
		onRequest = appendHooks(appendHooks({}, global.onRequest), routeHooks.onRequest),
		preParsing = appendHooks(appendHooks({}, global.preParsing), routeHooks.preParsing),
		preValidation = appendHooks(appendHooks({}, global.preValidation), routeHooks.preValidation),
		preHandler = appendHooks(appendHooks({}, global.preHandler), routeHooks.preHandler),
		onSend = appendHooks(appendHooks({}, global.onSend), routeHooks.onSend),
		onError = appendHooks(appendHooks({}, global.onError), routeHooks.onError),
		onResponse = appendHooks(appendHooks({}, global.onResponse), routeHooks.onResponse),
	}
end

function Executor.execute(app: App, source: RequestSource): Response
	local state = (app :: unknown) :: ExecutableApp
	Routing.compile(app)

	local globalHooks = state._compiledHooks :: HookChains
	local request = Request.create(source, state._options)
	local reply = Reply.create()
	local match = Routing.match(app, request.method, request.path)
	local hooks = if match.kind == "found" then combineHooks(globalHooks, match.route.hooks) else globalHooks

	local preHookGroups = {
		hooks.onRequest,
		hooks.preParsing,
		hooks.preValidation,
		hooks.preHandler,
	}

	for _, group in preHookGroups do
		local ok, responseOrError = runShortCircuitHooks(group, request, reply)
		if not ok then
			return finalizeResponse(state, hooks, request, createErrorResponse(state, hooks, request, responseOrError))
		end

		if responseOrError ~= nil then
			return finalizeResponse(state, hooks, request, responseOrError :: Response)
		end
	end

	if match.kind == "found" then
		request.params = match.params
		local ok, responseOrError = runHandler(match.route.handler, request, reply)
		if ok then
			return finalizeResponse(state, hooks, request, responseOrError :: Response)
		end

		return finalizeResponse(state, hooks, request, createErrorResponse(state, hooks, request, responseOrError))
	end

	local notFoundHandler = state._notFoundHandler or defaultNotFoundHandler
	local ok, responseOrError = runHandler(notFoundHandler, request, reply)
	if ok then
		return finalizeResponse(state, hooks, request, responseOrError :: Response)
	end

	return finalizeResponse(state, hooks, request, createErrorResponse(state, hooks, request, responseOrError))
end

return Executor
