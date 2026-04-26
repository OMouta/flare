local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local cors = require("@flare/plugins/cors")
local flare = require("@flare")

local function handler()
	return "ok"
end

test.suite("cors plugin", function(suite)
	suite:case("adds CORS headers to normal responses", function()
		local app = flare.new()

		app:plugin(cors)
		app:get("/health", handler)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/health",
			headers = {
				Origin = "https://example.com",
			},
		})

		assert.eq(response.status, 200)
		assert.eq(response.headers["access-control-allow-origin"], "*")
	end)

	suite:case("handles preflight OPTIONS requests", function()
		local app = flare.new()

		app:plugin(cors, {
			methods = { "GET", "POST" },
			allowedHeaders = { "content-type", "authorization" },
		})
		app:get("/users", handler)

		local response = Executor.execute(app, {
			method = "OPTIONS",
			path = "/users",
			headers = {
				Origin = "https://example.com",
				["Access-Control-Request-Headers"] = "x-request-id",
			},
		})

		assert.eq(response.status, 204)
		assert.eq(response.body, nil)
		assert.eq(response.headers["access-control-allow-origin"], "*")
		assert.eq(response.headers["access-control-allow-methods"], "GET, POST")
		assert.eq(response.headers["access-control-allow-headers"], "content-type, authorization")
	end)

	suite:case("supports credentials with a configured origin", function()
		local app = flare.new()

		app:plugin(cors, {
			origin = "https://app.example",
			credentials = true,
		})
		app:get("/session", handler)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/session",
			headers = {
				Origin = "https://app.example",
			},
		})

		assert.eq(response.headers["access-control-allow-origin"], "https://app.example")
		assert.eq(response.headers["access-control-allow-credentials"], "true")
	end)

	suite:case("supports origin allow lists and exposed headers", function()
		local app = flare.new()

		app:plugin(cors, {
			origin = { "https://one.example", "https://two.example" },
			exposedHeaders = { "x-total-count" },
		})
		app:get("/items", handler)

		local allowed = Executor.execute(app, {
			method = "GET",
			path = "/items",
			headers = {
				Origin = "https://two.example",
			},
		})
		local denied = Executor.execute(app, {
			method = "GET",
			path = "/items",
			headers = {
				Origin = "https://other.example",
			},
		})

		assert.eq(allowed.headers["access-control-allow-origin"], "https://two.example")
		assert.eq(allowed.headers["access-control-expose-headers"], "x-total-count")
		assert.eq(allowed.headers.vary, "Origin")
		assert.eq(denied.headers["access-control-allow-origin"], nil)
	end)

	suite:case("echoes requested preflight headers when allowed headers are not configured", function()
		local app = flare.new()

		app:plugin(cors)

		local response = Executor.execute(app, {
			method = "OPTIONS",
			path = "/anything",
			headers = {
				["Access-Control-Request-Headers"] = "x-request-id, authorization",
			},
		})

		assert.eq(response.headers["access-control-allow-headers"], "x-request-id, authorization")
	end)

	suite:case("rejects wildcard origin with credentials", function()
		local app = flare.new()

		assert.throwsWith(
			"[flare] plugin registration failed: [flare] cors origin cannot be '*' when credentials are enabled",
			function()
				app:plugin(cors, {
					origin = "*",
					credentials = true,
				})
			end
		)
	end)

	suite:case("does not add CORS headers unless registered", function()
		local app = flare.new()

		app:get("/health", handler)

		local response = Executor.execute(app, {
			method = "GET",
			path = "/health",
			headers = {
				Origin = "https://example.com",
			},
		})

		assert.eq(response.headers["access-control-allow-origin"], nil)
	end)
end)
