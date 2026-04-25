local Errors = require("./errors")
local Types = require("./types")

type App = Types.App

local RoutePrinter = {}

function RoutePrinter.print(_app: App): string
	return Errors.notImplemented("route printing", "Task 12")
end

return RoutePrinter
