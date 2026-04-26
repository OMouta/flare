local Routing = require("./routing")
local Types = require("./types")

type App = Types.App
type RouteRecord = Routing.RouteRecord

type PrintableApp = App & {
	_routes: { RouteRecord },
}

local RoutePrinter = {}

local function routeComesBefore(left: RouteRecord, right: RouteRecord): boolean
	if left.method == right.method then
		return left.path < right.path
	end

	return left.method < right.method
end

function RoutePrinter.print(app: App): string
	local state = (app :: unknown) :: PrintableApp
	local routes: { RouteRecord } = {}

	for _, route in state._routes do
		table.insert(routes, route)
	end

	table.sort(routes, routeComesBefore)

	local lines: { string } = {}
	for _, route in routes do
		table.insert(lines, string.format("%-7s %s", route.method, route.path))
	end

	return table.concat(lines, "\n")
end

return RoutePrinter
