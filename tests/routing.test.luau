local assert = require("@std/test/assert")
local test = require("@std/test")

local flare = require("@flare")

local function handler()
	return "ok"
end

local function routes(app): { any }
	return (app :: any)._routes
end

test.suite("route registration", function(suite)
	suite:case("generic route stores route metadata", function()
		local app = flare.new()
		local schema = {
			params = {
				parse = function(_self, input: unknown): unknown
					return input
				end,
			},
		} :: any
		local config = {
			auth = true,
		}

		assert.eq(
			app:route({
				method = "get",
				path = "/users/:id",
				schema = schema,
				config = config,
				handler = handler,
			}),
			app
		)

		local route = routes(app)[1]

		assert.eq(route.method, "GET")
		assert.eq(route.path, "/users/:id")
		assert.eq(route.handler, handler)
		assert.eq(route.schema, schema)
		assert.eq(route.config, config)
		assert.eq(route.pattern.params, { "id" })
		assert.eq(route.hooks, {
			onRequest = {},
			preParsing = {},
			preValidation = {},
			preHandler = {},
			onSend = {},
			onError = {},
			onResponse = {},
		})
	end)

	suite:case("method helpers delegate to route registration", function()
		local app = flare.new()

		app:get("/get", handler)
		app:post("/post", handler)
		app:put("/put", handler)
		app:patch("/patch", handler)
		app:delete("/delete", handler)
		app:head("/head", handler)
		app:options("/options", handler)

		assert.eq(routes(app)[1].method, "GET")
		assert.eq(routes(app)[2].method, "POST")
		assert.eq(routes(app)[3].method, "PUT")
		assert.eq(routes(app)[4].method, "PATCH")
		assert.eq(routes(app)[5].method, "DELETE")
		assert.eq(routes(app)[6].method, "HEAD")
		assert.eq(routes(app)[7].method, "OPTIONS")
	end)

	suite:case("method helpers accept route handler options", function()
		local app = flare.new()
		local config = {
			name = "createUser",
		}

		app:post("/users", {
			config = config,
			handler = handler,
		})

		local route = routes(app)[1]

		assert.eq(route.method, "POST")
		assert.eq(route.path, "/users")
		assert.eq(route.config, config)
		assert.eq(route.handler, handler)
	end)

	suite:case("validates method path and handler", function()
		local app = flare.new()

		assert.throws(function()
			app:route({
				method = "TRACE",
				path = "/trace",
				handler = handler,
			})
		end)

		assert.throws(function()
			app:route({
				method = "GET",
				path = "missing-slash",
				handler = handler,
			})
		end)

		assert.throws(function()
			app:get("/bad", "not a handler" :: any)
		end)
	end)

	suite:case("rejects duplicate routes for the same method and path", function()
		local app = flare.new()

		app:get("/users/:id", handler)

		assert.throws(function()
			app:get("/users/:id", handler)
		end)

		app:post("/users/:id", handler)
		assert.eq(#routes(app), 2)
	end)

	suite:case("rejects conflicting parameter route names", function()
		local app = flare.new()

		app:get("/users/:id", handler)

		assert.throws(function()
			app:get("/users/:name", handler)
		end)
	end)

	suite:case("allows static routes to coexist with parameter routes", function()
		local app = flare.new()

		app:get("/users/me", handler)
		app:get("/users/:id", handler)

		assert.eq(#routes(app), 2)
		assert.eq(routes(app)[1].path, "/users/me")
		assert.eq(routes(app)[2].path, "/users/:id")
	end)
end)
