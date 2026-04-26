local Io = require("@std/io")
local Process = require("@std/process")
local Time = require("@std/time")

local Executor = require("@flare/executor")
local Routing = require("@flare/routing")
local flare = require("@flare")

type BenchCase = {
	name: string,
	kind: string,
	iterations: number,
	run: () -> (),
}

type BenchResult = {
	name: string,
	kind: string,
	iterations: number,
	total: number,
	average: number,
	opsPerSecond: number,
}

local DEFAULT_ITERATIONS = 10000
local COMPILE_ITERATIONS = 1000
local REGISTRATION_ITERATIONS = 1000

local function handler()
	return "ok"
end

local function jsonHandler()
	return {
		ok = true,
	}
end

local function writeLine(line: string): ()
	Io.write(line, "\n")
end

local function runTimed(iterations: number, run: () -> ()): number
	local start = Time.now()

	for _ = 1, iterations do
		run()
	end

	return Time.since(start)
end

local function runCase(case: BenchCase): BenchResult
	case.run()

	local total = runTimed(case.iterations, case.run)
	local average = total / case.iterations

	return {
		name = case.name,
		kind = case.kind,
		iterations = case.iterations,
		total = total,
		average = average,
		opsPerSecond = if total == 0 then math.huge else case.iterations / total,
	}
end

local function printResult(result: BenchResult): ()
	writeLine(string.format("case: %s", result.name))
	writeLine(string.format("kind: %s", result.kind))
	writeLine(string.format("iterations: %d", result.iterations))
	writeLine(string.format("total_seconds: %.6f", result.total))
	writeLine(string.format("average_seconds: %.9f", result.average))
	writeLine(string.format("ops_per_second: %.2f", result.opsPerSecond))
	writeLine("allocation_notes: not measured")
	writeLine("")
end

local function createRouterApp()
	local app = flare.new()

	app:get("/exact", handler)
	app:get("/users/:id", handler)
	app:get("/assets/*", handler)
	app:compile()

	return app
end

local routerApp = createRouterApp()

local function createExecutorApp(hookCount: number, routeHandler: any)
	local app = flare.new()

	for _ = 1, hookCount do
		app:hook("preHandler", function()
			return nil
		end)
	end

	app:get("/work", routeHandler)
	app:compile()

	return app
end

local oneHookApp = createExecutorApp(1, handler)
local fiveHookApp = createExecutorApp(5, handler)
local jsonApp = createExecutorApp(0, jsonHandler)

local function routeCompilationRun(): ()
	local app = flare.new()

	app:get("/exact", handler)
	app:get("/users/:id", handler)
	app:get("/assets/*", handler)
	app:post("/users", handler)
	app:delete("/users/:id", handler)
	app:compile()
end

local function pluginRegistrationRun(): ()
	local app = flare.new()

	app:plugin(function(pluginApp)
		pluginApp:hook("preHandler", function()
			return nil
		end)

		pluginApp:get("/plugin", handler)
	end)
end

local cases: { BenchCase } = {
	{
		name = "router exact match",
		kind = "router-only",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Routing.match(routerApp, "GET", "/exact")
		end,
	},
	{
		name = "router param match",
		kind = "router-only",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Routing.match(routerApp, "GET", "/users/123")
		end,
	},
	{
		name = "router wildcard match",
		kind = "router-only",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Routing.match(routerApp, "GET", "/assets/app.css")
		end,
	},
	{
		name = "router 404 miss",
		kind = "router-only",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Routing.match(routerApp, "GET", "/missing")
		end,
	},
	{
		name = "app one hook",
		kind = "app-level",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Executor.execute(oneHookApp, {
				method = "GET",
				path = "/work",
			})
		end,
	},
	{
		name = "app five hooks",
		kind = "app-level",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Executor.execute(fiveHookApp, {
				method = "GET",
				path = "/work",
			})
		end,
	},
	{
		name = "app json response",
		kind = "app-level",
		iterations = DEFAULT_ITERATIONS,
		run = function()
			Executor.execute(jsonApp, {
				method = "GET",
				path = "/work",
			})
		end,
	},
	{
		name = "plugin registration",
		kind = "startup",
		iterations = REGISTRATION_ITERATIONS,
		run = pluginRegistrationRun,
	},
	{
		name = "route compilation",
		kind = "startup",
		iterations = COMPILE_ITERATIONS,
		run = routeCompilationRun,
	},
}

writeLine("Flare benchmark results")
writeLine(string.format("environment_cwd: %s", tostring(Process.cwd())))
writeLine(string.format("environment_exec_path: %s", tostring(Process.execPath())))
writeLine(string.format("environment_luau: %s", _VERSION))
writeLine("")

for _, case in cases do
	printResult(runCase(case))
end
