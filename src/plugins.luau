local Errors = require("./errors")
local Types = require("./types")

type App = Types.App
type Plugin = Types.Plugin

local Plugins = {}

function Plugins.register(_app: App, _plugin: Plugin, _options: { [string]: unknown }?): App
	return Errors.notImplemented("plugin registration", "Task 10")
end

function Plugins.decorate(_app: App, _name: string, _value: unknown): App
	return Errors.notImplemented("app decoration", "Task 10")
end

return Plugins
