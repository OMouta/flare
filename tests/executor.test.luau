local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local flare = require("@flare")

test.suite("handler execution pipeline", function(suite)
	suite:case("normalizes plain handler return values", function()
		local app = flare.new()

		app:get("/hello", function()
			return "hello"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/hello",
		})

		assert.eq(response.status, 200)
		assert.eq(response.headers["content-type"], "text/plain")
		assert.eq(response.body, "hello")
	end)

	suite:case("normalizes reply helper responses", function()
		local app = flare.new()

		app:get("/created", function(_request, reply)
			return reply:code(201):send({
				ok = true,
			})
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/created",
		})

		assert.eq(response.status, 201)
		assert.eq(response.headers["content-type"], "application/json")
		assert.eq(response.body, '{ "ok": true}')
	end)

	suite:case("uses an already-sent reply when handler returns nil", function()
		local app = flare.new()

		app:get("/sent", function(_request, reply)
			reply:code(202):send("accepted")
			return nil
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/sent",
		})

		assert.eq(response.status, 202)
		assert.eq(response.body, "accepted")
	end)

	suite:case("turns nil handler returns into empty responses", function()
		local app = flare.new()

		app:get("/empty", function()
			return nil
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/empty",
		})

		assert.eq(response.status, 204)
		assert.eq(response.body, nil)
	end)

	suite:case("passes route params into the request", function()
		local app = flare.new()

		app:get("/users/:id", function(request)
			return request.params.id
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/users/42",
		})

		assert.eq(response.status, 200)
		assert.eq(response.body, "42")
	end)

	suite:case("uses default not found responses for route misses", function()
		local app = flare.new()

		app:get("/health", function()
			return "ok"
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/missing",
		})

		assert.eq(response.status, 404)
		assert.eq(response.headers["content-type"], "application/json")
		assert.eq(response.body, '{ "error": "Not Found"}')
	end)

	suite:case("uses default error responses for handler errors", function()
		local app = flare.new()

		app:get("/explode", function()
			error("boom")
			return nil
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/explode",
		})

		assert.eq(response.status, 500)
		assert.eq(response.headers["content-type"], "application/json")
		assert.eq(response.body, '{ "error": "Internal Server Error"}')
	end)

	suite:case("uses custom not found handlers", function()
		local app = flare.new()

		assert.eq(
			app:setNotFoundHandler(function(_request, reply)
				return reply:code(404):send({
					error = "not_found",
				})
			end),
			app
		)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/missing",
		})

		assert.eq(response.status, 404)
		assert.eq(response.body, '{ "error": "not_found"}')
	end)

	suite:case("uses custom error handlers", function()
		local app = flare.new()

		app:setErrorHandler(function(_request, reply, err)
			return reply:code(500):send({
				error = "internal",
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

		assert.eq(response.status, 500)
		assert.eq(response.headers["content-type"], "application/json")
		assert.strContains(response.body :: string, '"error": "internal"')
		assert.strContains(response.body :: string, "boom")
	end)
end)
