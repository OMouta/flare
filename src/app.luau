local Errors = require("./errors")
local Hooks = require("./hooks")
local Plugins = require("./plugins")
local RoutePrinter = require("./route_printer")
local Routing = require("./routing")
local Types = require("./types")

type App = Types.App
type AppOptions = Types.AppOptions
type ErrorHandler = Types.ErrorHandler
type Handler = Types.Handler
type HookChains = Hooks.HookChains
type HookHandler = Types.HookHandler
type Plugin = Types.Plugin
type CompiledRouter = Routing.CompiledRouter
type RouteRecord = Routing.RouteRecord
type RouteHandlerOptions = Types.RouteHandlerOptions
type RouteOptions = Types.RouteOptions

type AppState = {
	_options: AppOptions,
	_compiled: boolean,
	_routes: { RouteRecord },
	_routePaths: { [string]: true },
	_routePatterns: { [string]: string },
	_compiledRouter: CompiledRouter?,
	_notFoundHandler: Handler?,
	_errorHandler: ErrorHandler?,
	_hooks: HookChains,
	_scopeHooks: HookChains,
	_compiledHooks: HookChains?,
	_prefix: string,
	_isScoped: boolean,
	_decorations: { [string]: unknown },
	_parentScope: any?,
}

local AppMethods = {}
AppMethods.__index = function(self: any, key: any): any
	local method = AppMethods[key]
	if method ~= nil then
		return method
	end

	if type(key) == "string" then
		if string.sub(key, 1, 1) == "_" then
			return nil
		end

		return Plugins.lookup((self :: unknown) :: App, key)
	end

	return nil
end

type AppInternal = typeof(setmetatable({} :: AppState, AppMethods))

function AppMethods:route(options: RouteOptions): App
	return Routing.route((self :: unknown) :: App, options)
end

function AppMethods:get(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "GET", path, handler)
end

function AppMethods:post(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "POST", path, handler)
end

function AppMethods:put(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "PUT", path, handler)
end

function AppMethods:patch(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "PATCH", path, handler)
end

function AppMethods:delete(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "DELETE", path, handler)
end

function AppMethods:head(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "HEAD", path, handler)
end

function AppMethods:options(path: string, handler: Handler | RouteHandlerOptions): App
	return Routing.method((self :: unknown) :: App, "OPTIONS", path, handler)
end

function AppMethods:hook(name: string, handler: HookHandler): App
	return Hooks.register((self :: unknown) :: App, name, handler)
end

local function joinGroupPrefix(parentPrefix: string, prefix: string): string
	if type(prefix) ~= "string" then
		Errors.raise("group prefix must be a string")
	end

	if prefix == "" or prefix == "/" then
		return if parentPrefix == "" then "/" else parentPrefix
	end

	if string.sub(prefix, 1, 1) ~= "/" then
		Errors.raise("group prefix must start with '/'")
	end

	if parentPrefix == "" or parentPrefix == "/" then
		return prefix
	end

	return parentPrefix .. prefix
end

function AppMethods:group(prefix: string, callback: (scope: App) -> ()): App
	if self._compiled then
		Errors.raise("groups cannot be registered after compilation")
	end

	if type(callback) ~= "function" then
		Errors.raise("group callback must be a function")
	end

	local group: AppInternal = setmetatable({
		_options = self._options,
		_compiled = self._compiled,
		_routes = self._routes,
		_routePaths = self._routePaths,
		_routePatterns = self._routePatterns,
		_compiledRouter = self._compiledRouter,
		_notFoundHandler = self._notFoundHandler,
		_errorHandler = self._errorHandler,
		_hooks = self._hooks,
		_scopeHooks = Hooks.copyChains(self._scopeHooks),
		_compiledHooks = self._compiledHooks,
		_prefix = joinGroupPrefix(self._prefix, prefix),
		_isScoped = true,
		_decorations = {},
		_parentScope = self,
	}, AppMethods) :: any

	callback((group :: unknown) :: App)

	return (self :: unknown) :: App
end

function AppMethods:plugin(plugin: Plugin, options: { [string]: unknown }?): App
	return Plugins.register((self :: unknown) :: App, plugin, options)
end

function AppMethods:decorate(name: string, value: unknown): App
	return Plugins.decorate((self :: unknown) :: App, name, value)
end

function AppMethods:setNotFoundHandler(handler: Handler): App
	if type(handler) ~= "function" then
		Errors.raise("not found handler must be a function")
	end

	self._notFoundHandler = handler

	return (self :: unknown) :: App
end

function AppMethods:setErrorHandler(handler: ErrorHandler): App
	if type(handler) ~= "function" then
		Errors.raise("error handler must be a function")
	end

	self._errorHandler = handler

	return (self :: unknown) :: App
end

function AppMethods:compile(): App
	return Routing.compile((self :: unknown) :: App)
end

function AppMethods:listen(_options: { [string]: unknown }): App
	return Errors.notImplemented("Lute listen integration", "Task 11")
end

function AppMethods:printRoutes(): string
	return RoutePrinter.print((self :: unknown) :: App)
end

local function validateOptions(options: AppOptions?): AppOptions
	local source: AppOptions = options or {}
	local trailingSlash = source.trailingSlash
	local normalizedTrailingSlash: ("strict" | "ignore" | "redirect")? = nil

	if trailingSlash == "strict" then
		normalizedTrailingSlash = "strict"
	elseif trailingSlash == "ignore" then
		normalizedTrailingSlash = "ignore"
	elseif trailingSlash == "redirect" then
		normalizedTrailingSlash = "redirect"
	elseif trailingSlash ~= nil then
		Errors.raise("AppOptions.trailingSlash must be 'strict', 'ignore', or 'redirect'")
	end

	if source.bodyLimit ~= nil and source.bodyLimit < 0 then
		Errors.raise("AppOptions.bodyLimit must be non-negative")
	end

	return {
		logger = source.logger,
		caseSensitive = source.caseSensitive,
		trailingSlash = normalizedTrailingSlash,
		bodyLimit = source.bodyLimit,
	}
end

local function new(options: AppOptions?): App
	local app: AppInternal = setmetatable({
		_options = validateOptions(options),
		_compiled = false,
		_routes = {},
		_routePaths = {},
		_routePatterns = {},
		_compiledRouter = nil :: CompiledRouter?,
		_notFoundHandler = nil :: Handler?,
		_errorHandler = nil :: ErrorHandler?,
		_hooks = Hooks.emptyChains(),
		_scopeHooks = Hooks.emptyChains(),
		_compiledHooks = nil :: HookChains?,
		_prefix = "",
		_isScoped = false,
		_decorations = {},
		_parentScope = nil,
	}, AppMethods)

	return (app :: unknown) :: App
end

return {
	new = new,
}
