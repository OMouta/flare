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
type RouteSchema = Types.RouteSchema
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

local function validationErrorResponse(reply: ReplyType, target: string, err: unknown): Response
	return reply:code(400):send({
		error = "Validation Error",
		target = target,
		message = tostring(err),
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

local function contentTypeIncludes(request: RequestType, expected: string): boolean
	local contentType = request.headers["content-type"]
	if contentType == nil then
		return false
	end

	return string.find(string.lower(contentType), expected, 1, true) ~= nil
end

local function validationBody(request: RequestType): unknown
	if contentTypeIncludes(request, "application/json") then
		return request:json()
	elseif contentTypeIncludes(request, "application/x-www-form-urlencoded") then
		return request:form()
	end

	return request:text()
end

local function applyValidator(
	schema: RouteSchema,
	request: RequestType,
	target: string,
	bodyInput: unknown?
): (boolean, unknown)
	local validator

	if target == "params" then
		validator = schema.params
	elseif target == "query" then
		validator = schema.query
	elseif target == "headers" then
		validator = schema.headers
	else
		validator = schema.body
	end

	if validator == nil then
		return true, nil
	end

	local input: unknown
	if target == "params" then
		input = request.params
	elseif target == "query" then
		input = request.query
	elseif target == "headers" then
		input = request.headers
	else
		input = bodyInput
	end

	local ok, parsed = pcall(validator.parse, validator, input)
	if not ok then
		return false, parsed
	end

	if target == "params" then
		request.params = parsed :: any
	elseif target == "query" then
		request.query = parsed :: any
	elseif target == "headers" then
		request.headers = parsed :: any
	else
		request.body = parsed
	end

	return true, nil
end

local function validateRequest(schema: RouteSchema?, request: RequestType): (boolean, Response?)
	if schema == nil then
		return true, nil
	end

	local bodyInput = if schema.body == nil then nil else validationBody(request)

	for _, target in { "params", "query", "headers", "body" } do
		local ok, err = applyValidator(schema, request, target, bodyInput)
		if not ok then
			return false, validationErrorResponse(Reply.create(), target, err)
		end
	end

	return true, nil
end

function Executor.execute(app: App, source: RequestSource): Response
	local state = (app :: unknown) :: ExecutableApp
	Routing.compile(app)

	local globalHooks = state._compiledHooks :: HookChains
	local request = Request.create(source, state._options)
	local reply = Reply.create()
	local match = Routing.match(app, request.method, request.path)
	local hooks = if match.kind == "found" then combineHooks(globalHooks, match.route.hooks) else globalHooks

	for _, group in { hooks.onRequest, hooks.preParsing, hooks.preValidation } do
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
		local valid, validationResponse = validateRequest(match.route.schema, request)
		if not valid then
			return finalizeResponse(state, hooks, request, validationResponse :: Response)
		end

		local hooksOk, hookResponseOrError = runShortCircuitHooks(hooks.preHandler, request, reply)
		if not hooksOk then
			return finalizeResponse(
				state,
				hooks,
				request,
				createErrorResponse(state, hooks, request, hookResponseOrError)
			)
		end

		if hookResponseOrError ~= nil then
			return finalizeResponse(state, hooks, request, hookResponseOrError :: Response)
		end

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
