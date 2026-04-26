local assert = require("@std/test/assert")
local test = require("@std/test")

local Listen = require("@flare/listen")
local flare = require("@flare")

test.suite("listen integration", function(suite)
	suite:case("converts Lute requests into Flare requests and responses back to Lute", function()
		local app = flare.new()

		app:get("/health", function(request)
			return {
				ok = request.query.ok,
			}
		end)

		local handler = Listen.createHandler(app)
		local response = handler({
			method = "GET",
			path = "/health",
			body = "",
			query = {
				ok = "true",
			},
			headers = {
				["X-Test"] = "yes",
			},
		}, {})

		assert.eq(response.status, 200)
		assert.eq(response.headers :: any, {
			["content-type"] = "application/json",
		})
		assert.eq(response.body, '{ "ok": "true"}')
	end)

	suite:case("listen compiles once before serving and stores the server handle", function()
		local app = flare.new()
		local servedConfig = nil :: any
		local fakeServer = {
			hostname = "127.0.0.1",
			port = 3000,
			close = function() end,
			upgrade = function()
				return false
			end,
		}
		local fakeModule = {
			serve = function(config)
				servedConfig = config
				return fakeServer
			end,
		}

		app:get("/health", function()
			return {
				ok = true,
			}
		end)

		local server = Listen.listenWithServer(app, {
			hostname = "127.0.0.1",
			port = 3000,
		}, fakeModule)

		assert.eq(server, fakeServer)
		assert.eq((app :: any)._compiled, true)
		assert.eq((app :: any)._server, fakeServer)
		assert.eq(servedConfig.hostname, "127.0.0.1")
		assert.eq(servedConfig.port, 3000)

		local response = servedConfig.handler({
			method = "GET",
			path = "/health",
			body = "",
			query = {},
			headers = {},
		}, fakeServer)

		assert.eq(response.status, 200)
		assert.eq(response.body, '{ "ok": true}')
	end)

	suite:case("startup locks route hook group and plugin registration", function()
		local app = flare.new()
		local fakeModule = {
			serve = function()
				return {}
			end,
		}

		Listen.listenWithServer(app, {
			port = 3000,
		}, fakeModule)

		assert.throws(function()
			app:get("/late", function()
				return "late"
			end)
		end)

		assert.throws(function()
			app:hook("preHandler", function()
				return nil
			end)
		end)

		assert.throws(function()
			app:group("/late", function(group)
				group:get("/route", function()
					return "late"
				end)
			end)
		end)

		assert.throws(function()
			app:plugin(function(plugin)
				plugin:get("/route", function()
					return "late"
				end)
			end)
		end)
	end)

	suite:case("reports startup errors clearly", function()
		local app = flare.new()
		local fakeModule = {
			serve = function()
				error("bind failed", 0)
			end,
		}

		assert.throwsWith("[flare] failed to start Lute server: bind failed", function()
			Listen.listenWithServer(app, {
				port = 3000,
			}, fakeModule)
		end)
	end)
end)
