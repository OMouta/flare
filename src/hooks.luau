local Errors = require("./errors")
local Types = require("./types")

type App = Types.App
type Handler = Types.Handler

local Hooks = {}

function Hooks.register(_app: App, _name: string, _handler: Handler): App
	return Errors.notImplemented("hook registration", "Task 8")
end

return Hooks
