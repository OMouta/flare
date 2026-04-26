local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local Routing = require("@flare/routing")
local flare = require("@flare")

local function handler()
	return "ok"
end

test.suite("plugins", function(suite)
	suite:case("registers routes in an encapsulated plugin scope", function()
		local app = flare.new()
		local hits = 0

		app:plugin(function(api)
			api:hook("preHandler", function()
				hits += 1
				return nil
			end)

			api:get("/plugin", handler)
		end)

		app:get("/root", handler)

		assert.eq(Routing.match(app, "GET", "/plugin").kind, "found")
		assert.eq(Routing.match(app, "GET", "/root").kind, "found")

		Executor.execute(app, {
			method = "GET",
			path = "/plugin",
		})
		Executor.execute(app, {
			method = "GET",
			path = "/root",
		})

		assert.eq(hits, 1)
	end)

	suite:case("child scopes can read parent decorations", function()
		local app = flare.new()

		app:decorate("config", {
			name = "root",
		})

		app:plugin(function(api)
			api:get("/config", function()
				return ((api :: any).config).name
			end)
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/config",
		})

		assert.eq(response.body, "root")
	end)

	suite:case("parent scopes do not see child decorations", function()
		local app = flare.new()

		app:plugin(function(api)
			api:decorate("secret", "child")
		end)

		assert.eq((app :: any).secret, nil)
	end)

	suite:case("rejects duplicate decorations in the same scope", function()
		local app = flare.new()

		app:decorate("db", {})

		assert.throws(function()
			app:decorate("db", {})
		end)
	end)

	suite:case("rejects decoration shadowing from child scopes", function()
		local app = flare.new()

		app:decorate("db", {})

		assert.throws(function()
			app:plugin(function(api)
				api:decorate("db", {})
			end)
		end)
	end)

	suite:case("supports nested plugins and inherited hooks", function()
		local app = flare.new()
		local order: { string } = {}

		app:plugin(function(api)
			api:decorate("prefix", "nested")
			api:hook("preHandler", function()
				table.insert(order, "outer")
				return nil
			end)

			api:plugin(function(child)
				child:hook("preHandler", function()
					table.insert(order, "inner")
					return nil
				end)

				child:get("/nested", function()
					table.insert(order, "handler")
					return (child :: any).prefix
				end)
			end)
		end)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/nested",
		})

		assert.eq(response.body, "nested")
		assert.eq(order, { "outer", "inner", "handler" })
	end)

	suite:case("rejects plugin registration after compilation", function()
		local app = flare.new()

		app:compile()

		assert.throws(function()
			app:plugin(function(api)
				api:get("/late", handler)
			end)
		end)
	end)

	suite:case("reports plugin registration context on errors", function()
		local app = flare.new()

		assert.throwsWith("plugin registration failed: boom", function()
			app:plugin(function()
				error("boom", 0)
			end)
		end)
	end)
end)
