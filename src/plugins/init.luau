local Errors = require("./errors")
local Hooks = require("./hooks")
local Types = require("./types")

type App = Types.App
type HookChains = Hooks.HookChains
type Plugin = Types.Plugin

local Plugins = {}

type PluginApp = App & {
	_compiled: boolean,
	_options: Types.AppOptions,
	_routes: { unknown },
	_routePaths: { [string]: true },
	_routePatterns: { [string]: string },
	_compiledRouter: unknown?,
	_notFoundHandler: Types.Handler?,
	_errorHandler: Types.ErrorHandler?,
	_hooks: HookChains,
	_scopeHooks: HookChains,
	_compiledHooks: HookChains?,
	_prefix: string,
	_isScoped: boolean,
	_decorations: { [string]: unknown },
	_parentScope: PluginApp?,
}

local function findDecoration(scope: PluginApp?, name: string): (boolean, unknown)
	local current = scope

	while current ~= nil do
		local decorations = rawget(current :: any, "_decorations") :: { [string]: unknown }?
		if decorations ~= nil then
			local value = decorations[name]
			if value ~= nil then
				return true, value
			end
		end

		current = rawget(current :: any, "_parentScope") :: PluginApp?
	end

	return false, nil
end

function Plugins.lookup(app: App, name: string): unknown?
	local found, value = findDecoration((app :: unknown) :: PluginApp, name)
	if found then
		return value
	end

	return nil
end

function Plugins.register(app: App, plugin: Plugin, options: { [string]: unknown }?): App
	local state = (app :: unknown) :: PluginApp

	if state._compiled then
		Errors.raise("plugins cannot be registered after compilation")
	end

	if type(plugin) ~= "function" then
		Errors.raise("plugin must be a function")
	end

	local scope: PluginApp = setmetatable({
		_options = state._options,
		_compiled = state._compiled,
		_routes = state._routes,
		_routePaths = state._routePaths,
		_routePatterns = state._routePatterns,
		_compiledRouter = state._compiledRouter,
		_notFoundHandler = state._notFoundHandler,
		_errorHandler = state._errorHandler,
		_hooks = state._hooks,
		_scopeHooks = Hooks.copyChains(state._scopeHooks),
		_compiledHooks = state._compiledHooks,
		_prefix = state._prefix,
		_isScoped = true,
		_decorations = {},
		_parentScope = state,
	}, getmetatable(app :: any)) :: any

	local ok, err = pcall(plugin, (scope :: unknown) :: App, options)
	if not ok then
		Errors.raise("plugin registration failed: " .. tostring(err))
	end

	return app
end

function Plugins.decorate(app: App, name: string, value: unknown): App
	local state = (app :: unknown) :: PluginApp

	if type(name) ~= "string" or name == "" then
		Errors.raise("decoration name must be a non-empty string")
	end

	local decorations = rawget(state :: any, "_decorations") :: { [string]: unknown }
	if decorations[name] ~= nil then
		Errors.raise("duplicate decoration '" .. name .. "'")
	end

	local foundInParent = findDecoration(rawget(state :: any, "_parentScope") :: PluginApp?, name)
	if foundInParent then
		Errors.raise("decoration '" .. name .. "' already exists in a parent scope")
	end

	decorations[name] = value

	return app
end

return Plugins
