local Errors = require("./errors")
local Types = require("./types")

type App = Types.App
type Handler = Types.Handler
type RouteHandlerOptions = Types.RouteHandlerOptions
type RouteOptions = Types.RouteOptions

local Routing = {}

function Routing.route(_app: App, _options: RouteOptions): App
	return Errors.notImplemented("route registration", "Task 4")
end

function Routing.method(_app: App, _method: string, _path: string, _handler: Handler | RouteHandlerOptions): App
	return Errors.notImplemented("method route registration", "Task 4")
end

function Routing.compile(_app: App): App
	return Errors.notImplemented("route compilation", "Task 5")
end

return Routing
