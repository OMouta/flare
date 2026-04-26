local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local logger = require("@flare/plugins/logger")
local flare = require("@flare")

type LogLevel = "debug" | "info" | "warn" | "error" | "silent"

type LogEntry = {
	level: LogLevel,
	method: string,
	path: string,
	status: number,
	duration: number,
	error: string?,
}

local function collect(entries: { LogEntry }): (LogEntry) -> ()
	return function(entry: LogEntry)
		table.insert(entries, entry)
	end
end

test.suite("logger plugin", function(suite)
	suite:case("logs request method path status and duration", function()
		local app = flare.new()
		local entries: { LogEntry } = {}

		app:plugin(logger, {
			sink = collect(entries),
		})

		app:get("/health", function()
			return "ok"
		end)

		Executor.execute(app, {
			method = "GET",
			path = "/health",
		})

		assert.eq(#entries, 1)
		assert.eq(entries[1].level, "info")
		assert.eq(entries[1].method, "GET")
		assert.eq(entries[1].path, "/health")
		assert.eq(entries[1].status, 200)
		assert.eq(entries[1].error, nil)
		assert.that(entries[1].duration >= 0)
	end)

	suite:case("logs error details in development mode", function()
		local app = flare.new()
		local entries: { LogEntry } = {}

		app:plugin(logger, {
			development = true,
			sink = collect(entries),
		})

		app:get("/boom", function()
			error("boom", 0)
			return nil
		end)

		Executor.execute(app, {
			method = "GET",
			path = "/boom",
		})

		assert.eq(#entries, 1)
		assert.eq(entries[1].level, "error")
		assert.eq(entries[1].status, 500)
		assert.eq(entries[1].error, "boom")
	end)

	suite:case("omits error details outside development mode", function()
		local app = flare.new()
		local entries: { LogEntry } = {}

		app:plugin(logger, {
			sink = collect(entries),
		})

		app:get("/boom", function()
			error("boom", 0)
			return nil
		end)

		Executor.execute(app, {
			method = "GET",
			path = "/boom",
		})

		assert.eq(#entries, 1)
		assert.eq(entries[1].level, "error")
		assert.eq(entries[1].error, nil)
	end)

	suite:case("filters entries below the configured level", function()
		local app = flare.new()
		local entries: { LogEntry } = {}

		app:plugin(logger, {
			level = "error",
			sink = collect(entries),
		})

		app:get("/ok", function()
			return "ok"
		end)

		app:get("/boom", function()
			error("boom", 0)
			return nil
		end)

		Executor.execute(app, {
			method = "GET",
			path = "/ok",
		})
		Executor.execute(app, {
			method = "GET",
			path = "/boom",
		})

		assert.eq(#entries, 1)
		assert.eq(entries[1].path, "/boom")
		assert.eq(entries[1].level, "error")
	end)

	suite:case("validates log level options", function()
		local app = flare.new()

		assert.throwsWith("[flare] logger level must be 'debug', 'info', 'warn', 'error', or 'silent'", function()
			app:plugin(logger, {
				level = "verbose",
			})
		end)
	end)

	suite:case("does not force lazy body parsing", function()
		local app = flare.new()
		local reads = 0

		app:plugin(logger, {
			sink = function() end,
		})

		app:post("/body", function()
			return "ok"
		end)

		Executor.execute(app, {
			method = "POST",
			path = "/body",
			body = "name=flare",
			readBody = function()
				reads += 1
				return "name=flare"
			end,
		})

		assert.eq(reads, 0)
	end)
end)
