local Errors = require("./errors")
local Hooks = require("./hooks")
local RoutePattern = require("./route_pattern")
local Types = require("./types")

type App = Types.App
type Handler = Types.Handler
type HookChains = Hooks.HookChains
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

export type CompiledMethodRoutes = {
	exact: { [string]: RouteRecord },
	params: { RouteRecord },
	wildcards: { RouteRecord },
}

export type CompiledRouter = {
	methods: { [string]: CompiledMethodRoutes },
}

export type MatchFound = {
	kind: "found",
	route: RouteRecord,
	params: { [string]: string },
}

export type MatchMiss = {
	kind: "path_miss" | "method_miss",
}

export type MatchResult = MatchFound | MatchMiss

type AppRoutingState = App & {
	_compiled: boolean,
	_routes: { RouteRecord },
	_routePaths: { [string]: true },
	_routePatterns: { [string]: string },
	_compiledRouter: CompiledRouter?,
	_hooks: HookChains,
	_compiledHooks: HookChains?,
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

local function splitPath(path: string): { string }?
	local normalized = if path == "" then "/" else path

	if string.sub(normalized, 1, 1) ~= "/" then
		return nil
	end

	if normalized == "/" then
		return {}
	end

	local rawSegments = string.split(string.sub(normalized, 2), "/")
	local segments: { string } = {}

	for _, segment in rawSegments do
		if segment == "" then
			return nil
		end

		table.insert(segments, segment)
	end

	return segments
end

local function normalizedRequestPath(path: string): string?
	if path == "" then
		return "/"
	end

	if string.sub(path, 1, 1) ~= "/" then
		return nil
	end

	return path
end

local function newCompiledMethodRoutes(): CompiledMethodRoutes
	return {
		exact = {},
		params = {},
		wildcards = {},
	}
end

local function getCompiledMethodRoutes(router: CompiledRouter, method: string): CompiledMethodRoutes
	local routes = router.methods[method]
	if routes == nil then
		routes = newCompiledMethodRoutes()
		router.methods[method] = routes
	end

	return routes
end

local function freezeCompiledMethodRoutes(routes: CompiledMethodRoutes): ()
	table.freeze(routes.exact)
	table.freeze(routes.params)
	table.freeze(routes.wildcards)
	table.freeze(routes)
end

local function routeHasDynamicParams(route: RouteRecord): boolean
	return #route.pattern.params > 0 and route.pattern.hasWildcard == false
end

local function routeIsWildcard(route: RouteRecord): boolean
	return route.pattern.hasWildcard
end

local function routeMatchesSegments(route: RouteRecord, pathSegments: { string }): { [string]: string }?
	local patternSegments = route.pattern.segments
	local params: { [string]: string } = {}

	if route.pattern.hasWildcard then
		if #pathSegments < #patternSegments - 1 then
			return nil
		end
	else
		if #pathSegments ~= #patternSegments then
			return nil
		end
	end

	for index, patternSegment in patternSegments do
		local pathSegment = pathSegments[index]

		if patternSegment.kind == "wildcard" then
			return params
		elseif pathSegment == nil then
			return nil
		elseif patternSegment.kind == "static" then
			if patternSegment.value ~= pathSegment then
				return nil
			end
		else
			params[patternSegment.name] = pathSegment
		end
	end

	return params
end

local function matchInMethod(routes: CompiledMethodRoutes, path: string, pathSegments: { string }): MatchFound?
	local exact = routes.exact[path]
	if exact ~= nil then
		return {
			kind = "found",
			route = exact,
			params = {},
		}
	end

	for _, route in routes.params do
		local params = routeMatchesSegments(route, pathSegments)
		if params ~= nil then
			return {
				kind = "found",
				route = route,
				params = params,
			}
		end
	end

	for _, route in routes.wildcards do
		local params = routeMatchesSegments(route, pathSegments)
		if params ~= nil then
			return {
				kind = "found",
				route = route,
				params = params,
			}
		end
	end

	return nil
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

function Routing.compile(app: App): App
	local state = (app :: unknown) :: AppRoutingState

	if state._compiled then
		return app
	end

	local router: CompiledRouter = {
		methods = {},
	}

	for _, route in state._routes do
		local methodRoutes = getCompiledMethodRoutes(router, route.method)

		if routeIsWildcard(route) then
			table.insert(methodRoutes.wildcards, route)
		elseif routeHasDynamicParams(route) then
			table.insert(methodRoutes.params, route)
		else
			methodRoutes.exact[route.path] = route
		end
	end

	for _, methodRoutes in router.methods do
		freezeCompiledMethodRoutes(methodRoutes)
	end

	table.freeze(router.methods)
	table.freeze(router)

	state._compiledRouter = (router :: unknown) :: CompiledRouter?
	state._compiledHooks = Hooks.compile(state._hooks)
	state._compiled = true

	return app
end

function Routing.match(app: App, method: string, path: string): MatchResult
	local state = (app :: unknown) :: AppRoutingState
	if not state._compiled or state._compiledRouter == nil then
		Routing.compile(app)
	end

	local router = state._compiledRouter :: CompiledRouter
	local normalizedMethod = normalizeMethod(method)
	local normalizedPath = normalizedRequestPath(path)
	local pathSegments = splitPath(path)

	if normalizedPath == nil or pathSegments == nil then
		return {
			kind = "path_miss",
		}
	end

	local methodRoutes = router.methods[normalizedMethod]
	if methodRoutes ~= nil then
		local found = matchInMethod(methodRoutes, normalizedPath, pathSegments)
		if found ~= nil then
			return found
		end
	end

	for otherMethod, otherRoutes in router.methods do
		if otherMethod == normalizedMethod then
			continue
		end

		if matchInMethod(otherRoutes, normalizedPath, pathSegments) ~= nil then
			return {
				kind = "method_miss",
			}
		end
	end

	return {
		kind = "path_miss",
	}
end

return Routing
