local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local flare = require("@flare")

local function push(items: { string }, item: string)
	table.insert(items, item)
end

test.suite("hook registration", function(suite)
	suite:case("rejects unknown hook names", function()
		local app = flare.new()

		assert.throws(function()
			app:hook("notARealHook", function()
				return nil
			end)
		end)
	end)

	suite:case("rejects hook registration after compilation", function()
		local app = flare.new()

		app:compile()

		assert.throws(function()
			app:hook("onRequest", function()
				return nil
			end)
		end)
	end)

	suite:case("compiles flattened hook chains", function()
		local app = flare.new()

		app:hook("onRequest", function()
			return nil
		end)
		app:compile()

		local hooks = (app :: any)._compiledHooks

		assert.eq(#hooks.onRequest, 1)
		assert.throws(function()
			hooks.onRequest[2] = hooks.onRequest[1]
		end)
	end)
end)

test.suite("hook execution", function(suite)
	suite:case("executes hooks in lifecycle order", function()
		local app = flare.new()
		local order: { string } = {}

		app:hook("onRequest", function()
			push(order, "onRequest")
			return nil
		end)
		app:hook("preParsing", function()
			push(order, "preParsing")
			return nil
		end)
		app:hook("preValidation", function()
			push(order, "preValidation")
			return nil
		end)
		app:hook("preHandler", function()
			push(order, "preHandler")
			return nil
		end)
		app:hook("onSend", function(_request, _reply, response)
			push(order, "onSend")
			return response :: any
		end)
		app:hook("onResponse", function()
			push(order, "onResponse")
			return "ignored"
		end)

		app:get("/ok", function()
			push(order, "handler")
			return "ok"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/ok",
		})

		assert.eq(response.body, "ok")
		assert.eq(order, {
			"onRequest",
			"preParsing",
			"preValidation",
			"preHandler",
			"handler",
			"onSend",
			"onResponse",
		})
	end)

	suite:case("short-circuits before the handler", function()
		local app = flare.new()
		local ranHandler = false

		app:hook("preHandler", function(_request, reply)
			return reply:code(401):send({
				error = "unauthorized",
			})
		end)

		app:get("/private", function()
			ranHandler = true
			return "secret"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/private",
		})

		assert.eq(ranHandler, false)
		assert.eq(response.status, 401)
		assert.eq(response.body, '{ "error": "unauthorized"}')
	end)

	suite:case("onSend can replace the response", function()
		local app = flare.new()

		app:hook("onSend", function(_request, reply)
			return reply:code(202):send("replaced")
		end)

		app:get("/ok", function()
			return "original"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/ok",
		})

		assert.eq(response.status, 202)
		assert.eq(response.body, "replaced")
	end)

	suite:case("onError can replace an error response", function()
		local app = flare.new()

		app:hook("onError", function(_request, reply, err)
			return reply:code(503):send({
				error = "hooked",
				message = tostring(err),
			})
		end)

		app:get("/explode", function()
			error("boom")
			return nil
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/explode",
		})

		assert.eq(response.status, 503)
		assert.strContains(response.body :: string, '"error": "hooked"')
		assert.strContains(response.body :: string, "boom")
	end)

	suite:case("hook errors flow into error handling", function()
		local app = flare.new()

		app:hook("preHandler", function()
			error("bad hook")
			return nil
		end)

		app:hook("onError", function(_request, reply, err)
			return reply:code(500):send({
				error = "from_on_error",
				message = tostring(err),
			})
		end)

		app:get("/ok", function()
			return "ok"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/ok",
		})

		assert.eq(response.status, 500)
		assert.strContains(response.body :: string, "from_on_error")
		assert.strContains(response.body :: string, "bad hook")
	end)

	suite:case("onResponse cannot replace the response", function()
		local app = flare.new()
		local observedStatus = 0

		app:hook("onResponse", function(_request, _reply, response)
			observedStatus = (response :: any).status
			return {
				replaced = true,
			}
		end)

		app:get("/ok", function()
			return "ok"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/ok",
		})

		assert.eq(observedStatus, 200)
		assert.eq(response.status, 200)
		assert.eq(response.body, "ok")
	end)
end)
