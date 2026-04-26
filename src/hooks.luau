local Errors = require("./errors")
local Types = require("./types")

type App = Types.App
type HookHandler = Types.HookHandler

export type HookName = "onRequest" | "preParsing" | "preValidation" | "preHandler" | "onSend" | "onError" | "onResponse"

export type HookChains = {
	onRequest: { HookHandler },
	preParsing: { HookHandler },
	preValidation: { HookHandler },
	preHandler: { HookHandler },
	onSend: { HookHandler },
	onError: { HookHandler },
	onResponse: { HookHandler },
}

type HookedApp = App & {
	_compiled: boolean,
	_isScoped: boolean,
	_hooks: HookChains,
	_scopeHooks: HookChains,
	_compiledHooks: HookChains?,
}

local Hooks = {}

local VALID_HOOKS: { [string]: true } = {
	onRequest = true,
	preParsing = true,
	preValidation = true,
	preHandler = true,
	onSend = true,
	onError = true,
	onResponse = true,
}

function Hooks.emptyChains(): HookChains
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

local function copyHookList(source: { HookHandler }, freeze: boolean): { HookHandler }
	local target: { HookHandler } = {}

	for _, handler in source do
		table.insert(target, handler)
	end

	if freeze then
		table.freeze(target)
	end

	return target
end

function Hooks.copyChains(chains: HookChains): HookChains
	return {
		onRequest = copyHookList(chains.onRequest, false),
		preParsing = copyHookList(chains.preParsing, false),
		preValidation = copyHookList(chains.preValidation, false),
		preHandler = copyHookList(chains.preHandler, false),
		onSend = copyHookList(chains.onSend, false),
		onError = copyHookList(chains.onError, false),
		onResponse = copyHookList(chains.onResponse, false),
	}
end

local function hookList(chains: HookChains, name: HookName): { HookHandler }
	if name == "onRequest" then
		return chains.onRequest
	elseif name == "preParsing" then
		return chains.preParsing
	elseif name == "preValidation" then
		return chains.preValidation
	elseif name == "preHandler" then
		return chains.preHandler
	elseif name == "onSend" then
		return chains.onSend
	elseif name == "onError" then
		return chains.onError
	else
		return chains.onResponse
	end
end

function Hooks.compile(chains: HookChains): HookChains
	return table.freeze({
		onRequest = copyHookList(chains.onRequest, true),
		preParsing = copyHookList(chains.preParsing, true),
		preValidation = copyHookList(chains.preValidation, true),
		preHandler = copyHookList(chains.preHandler, true),
		onSend = copyHookList(chains.onSend, true),
		onError = copyHookList(chains.onError, true),
		onResponse = copyHookList(chains.onResponse, true),
	}) :: HookChains
end

function Hooks.register(app: App, name: string, handler: HookHandler): App
	local state = (app :: unknown) :: HookedApp

	if state._compiled then
		Errors.raise("hooks cannot be registered after compilation")
	end

	if VALID_HOOKS[name] ~= true then
		Errors.raise("unknown hook '" .. name .. "'")
	end

	if type(handler) ~= "function" then
		Errors.raise("hook handler must be a function")
	end

	if state._isScoped then
		table.insert(hookList(state._scopeHooks, name :: HookName), handler)
	else
		table.insert(hookList(state._hooks, name :: HookName), handler)
	end

	return app
end

return Hooks
