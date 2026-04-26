local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local Routing = require("@flare/routing")
local flare = require("@flare")

local function handler()
	return "ok"
end

local function routes(app): { any }
	return (app :: any)._routes
end

test.suite("groups", function(suite)
	suite:case("prefixes group route paths", function()
		local app = flare.new()

		assert.eq(
			app:group("/api", function(api)
				api:get("/health", handler)
				api:get("/", handler)
			end),
			app
		)

		assert.eq(routes(app)[1].path, "/api/health")
		assert.eq(routes(app)[2].path, "/api")
		assert.eq(Routing.match(app, "GET", "/api/health").kind, "found")
		assert.eq(Routing.match(app, "GET", "/api").kind, "found")
	end)

	suite:case("supports nested group prefixes", function()
		local app = flare.new()

		app:group("/api", function(api)
			api:group("/v1", function(v1)
				v1:get("/users", handler)
			end)
		end)

		assert.eq(routes(app)[1].path, "/api/v1/users")
		assert.eq(Routing.match(app, "GET", "/api/v1/users").kind, "found")
	end)

	suite:case("inherits parent group hooks", function()
		local app = flare.new()
		local order: { string } = {}

		app:group("/api", function(api)
			api:hook("preHandler", function()
				table.insert(order, "api")
				return nil
			end)

			api:group("/v1", function(v1)
				v1:hook("preHandler", function()
					table.insert(order, "v1")
					return nil
				end)

				v1:get("/users", function()
					table.insert(order, "handler")
					return "ok"
				end)
			end)
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/api/v1/users",
		})

		assert.eq(response.body, "ok")
		assert.eq(order, { "api", "v1", "handler" })
	end)

	suite:case("group-local hooks apply only to routes inside the group", function()
		local app = flare.new()
		local groupHits = 0

		app:group("/api", function(api)
			api:hook("preHandler", function()
				groupHits += 1
				return nil
			end)

			api:get("/inside", handler)
		end)

		app:get("/outside", handler)

		local inside = Executor.execute(app, {
			method = "GET",
			path = "/api/inside",
		})
		local outside = Executor.execute(app, {
			method = "GET",
			path = "/outside",
		})

		assert.eq(inside.status, 200)
		assert.eq(outside.status, 200)
		assert.eq(groupHits, 1)
	end)

	suite:case("global hooks still apply to grouped routes", function()
		local app = flare.new()
		local order: { string } = {}

		app:hook("preHandler", function()
			table.insert(order, "global")
			return nil
		end)

		app:group("/api", function(api)
			api:hook("preHandler", function()
				table.insert(order, "group")
				return nil
			end)

			api:get("/health", function()
				table.insert(order, "handler")
				return "ok"
			end)
		end)

		Executor.execute(app, {
			method = "GET",
			path = "/api/health",
		})

		assert.eq(order, { "global", "group", "handler" })
	end)

	suite:case("rejects group registration after compilation", function()
		local app = flare.new()

		app:compile()

		assert.throws(function()
			app:group("/late", function(late)
				late:get("/route", handler)
			end)
		end)
	end)
end)
