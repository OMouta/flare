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
	_hooks: HookChains,
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

local function copyHookList(source: { HookHandler }): { HookHandler }
	local target: { HookHandler } = {}

	for _, handler in source do
		table.insert(target, handler)
	end

	table.freeze(target)

	return target
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
		onRequest = copyHookList(chains.onRequest),
		preParsing = copyHookList(chains.preParsing),
		preValidation = copyHookList(chains.preValidation),
		preHandler = copyHookList(chains.preHandler),
		onSend = copyHookList(chains.onSend),
		onError = copyHookList(chains.onError),
		onResponse = copyHookList(chains.onResponse),
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

	table.insert(hookList(state._hooks, name :: HookName), handler)

	return app
end

return Hooks
