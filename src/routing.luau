local Errors = require("./errors")
local RoutePattern = require("./route_pattern")
local Types = require("./types")

type App = Types.App
type Handler = Types.Handler
type RouteHandlerOptions = Types.RouteHandlerOptions
type RouteOptions = Types.RouteOptions
type RouteSchema = Types.RouteSchema
type ParsedPattern = RoutePattern.ParsedPattern

export type RouteHooks = {
	onRequest: { unknown },
	preParsing: { unknown },
	preValidation: { unknown },
	preHandler: { unknown },
	onSend: { unknown },
	onError: { unknown },
	onResponse: { unknown },
}

export type RouteRecord = {
	method: string,
	path: string,
	pattern: ParsedPattern,
	handler: Handler,
	schema: RouteSchema?,
	config: { [string]: unknown }?,
	hooks: RouteHooks,
}

type AppRoutingState = App & {
	_compiled: boolean,
	_routes: { RouteRecord },
	_routePaths: { [string]: true },
	_routePatterns: { [string]: string },
}

local Routing = {}

local SUPPORTED_METHODS: { [string]: true } = {
	DELETE = true,
	GET = true,
	HEAD = true,
	OPTIONS = true,
	PATCH = true,
	POST = true,
	PUT = true,
}

local function emptyHooks(): RouteHooks
	return {
		onRequest = {},
		preParsing = {},
		preValidation = {},
		preHandler = {},
		onSend = {},
		onError = {},
		onResponse = {},
	}
end

local function normalizeMethod(method: string): string
	if type(method) ~= "string" then
		Errors.raise("route method must be a string")
	end

	local normalized = string.upper(method)
	if SUPPORTED_METHODS[normalized] ~= true then
		Errors.raise("unsupported route method '" .. method .. "'")
	end

	return normalized
end

local function assertPath(path: string): string
	if type(path) ~= "string" then
		Errors.raise("route path must be a string")
	end

	return path
end

local function assertHandler(handler: Handler?): Handler
	if type(handler) ~= "function" then
		Errors.raise("route handler must be a function")
	end

	return handler :: Handler
end

local function patternConflictKey(pattern: ParsedPattern): string
	local parts: { string } = {}

	for _, segment in pattern.segments do
		if segment.kind == "static" then
			table.insert(parts, segment.value)
		elseif segment.kind == "param" then
			table.insert(parts, ":")
		else
			table.insert(parts, "*")
		end
	end

	return "/" .. table.concat(parts, "/")
end

local function routePathKey(method: string, path: string): string
	return method .. " " .. path
end

local function routePatternKey(method: string, pattern: ParsedPattern): string
	return method .. " " .. patternConflictKey(pattern)
end

local function assertCanRegister(app: AppRoutingState): ()
	if app._compiled then
		Errors.raise("routes cannot be registered after compilation")
	end
end

function Routing.route(app: App, options: RouteOptions): App
	local state = (app :: unknown) :: AppRoutingState
	assertCanRegister(state)

	if type(options) ~= "table" then
		Errors.raise("route options must be a table")
	end

	local method = normalizeMethod(options.method)
	local parsedPattern = RoutePattern.parse(assertPath(options.path))
	local handler = assertHandler(options.handler)
	local pathKey = routePathKey(method, parsedPattern.path)
	local patternKey = routePatternKey(method, parsedPattern)

	if state._routePaths[pathKey] == true then
		Errors.raise("duplicate route '" .. pathKey .. "'")
	end

	local existingPatternPath = state._routePatterns[patternKey]
	if existingPatternPath ~= nil then
		Errors.raise(
			"conflicting route '" .. pathKey .. "' overlaps with '" .. method .. " " .. existingPatternPath .. "'"
		)
	end

	local record: RouteRecord = {
		method = method,
		path = parsedPattern.path,
		pattern = parsedPattern,
		handler = handler,
		schema = options.schema,
		config = options.config,
		hooks = emptyHooks(),
	}

	table.insert(state._routes, record)
	state._routePaths[pathKey] = true
	state._routePatterns[patternKey] = parsedPattern.path

	return app
end

function Routing.method(app: App, method: string, path: string, handlerOrOptions: Handler | RouteHandlerOptions): App
	if type(handlerOrOptions) == "function" then
		return Routing.route(app, {
			method = method,
			path = path,
			handler = handlerOrOptions :: Handler,
		})
	end

	if type(handlerOrOptions) ~= "table" then
		Errors.raise("route handler must be a function or route options table")
	end

	local options = handlerOrOptions :: RouteHandlerOptions
	return Routing.route(app, {
		method = method,
		path = path,
		schema = options.schema,
		config = options.config,
		handler = options.handler,
	})
end

function Routing.compile(_app: App): App
	return Errors.notImplemented("route compilation", "Task 5")
end

return Routing
