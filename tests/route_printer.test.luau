local assert = require("@std/test/assert")
local test = require("@std/test")

local flare = require("@flare")

local function handler()
	return "ok"
end

test.suite("route printer", function(suite)
	suite:case("prints methods and paths sorted consistently", function()
		local app = flare.new()

		app:post("/users", handler)
		app:get("/users/:id", handler)
		app:get("/health", handler)

		assert.eq(app:printRoutes(), "GET     /health\nGET     /users/:id\nPOST    /users")
	end)

	suite:case("includes grouped routes", function()
		local app = flare.new()

		app:group("/api", function(api)
			api:get("/health", handler)
			api:post("/users", handler)
		end)

		assert.eq(app:printRoutes(), "GET     /api/health\nPOST    /api/users")
	end)

	suite:case("includes plugin routes", function()
		local app = flare.new()

		app:plugin(function(api)
			api:get("/plugin", handler)
		end)

		app:get("/root", handler)

		assert.eq(app:printRoutes(), "GET     /plugin\nGET     /root")
	end)

	suite:case("prints the same output before and after compilation", function()
		local app = flare.new()

		app:delete("/users/:id", handler)
		app:get("/health", handler)

		local before = app:printRoutes()
		app:compile()

		assert.eq(app:printRoutes(), before)
	end)
end)
