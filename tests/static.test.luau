local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local static = require("@flare/plugins/static")
local flare = require("@flare")

local ROOT = "tests/fixtures/static"

test.suite("static plugin", function(suite)
	suite:case("serves files from the configured root and prefix", function()
		local app = flare.new()

		app:plugin(static, {
			root = ROOT,
			prefix = "/public",
		})

		local response = Executor.execute(app, {
			method = "GET",
			path = "/public/assets/app.js",
		})

		assert.eq(response.status, 200)
		assert.eq(response.headers["content-type"], "application/javascript")
		assert.eq(response.body, 'console.log("flare");\n')
	end)

	suite:case("serves configured index files", function()
		local app = flare.new()

		app:plugin(static, {
			root = ROOT,
			prefix = "/public",
			index = { "index.html" },
		})

		local rootIndex = Executor.execute(app, {
			method = "GET",
			path = "/public",
		})
		local nestedIndex = Executor.execute(app, {
			method = "GET",
			path = "/public/about",
		})

		assert.eq(rootIndex.status, 200)
		assert.eq(rootIndex.body, "<h1>Home</h1>\n")
		assert.eq(nestedIndex.status, 200)
		assert.eq(nestedIndex.body, "<h1>About</h1>\n")
	end)

	suite:case("infers MIME types and supports cache headers", function()
		local app = flare.new()

		app:plugin(static, {
			root = ROOT,
			prefix = "/static",
			cacheControl = "public, max-age=60",
		})

		local response = Executor.execute(app, {
			method = "GET",
			path = "/static/data.json",
		})

		assert.eq(response.status, 200)
		assert.eq(response.headers["content-type"], "application/json")
		assert.eq(response.headers["cache-control"], "public, max-age=60")
		assert.eq(response.body, '{ "ok": true}\n')
	end)

	suite:case("returns 404 for missing files", function()
		local app = flare.new()

		app:plugin(static, {
			root = ROOT,
			prefix = "/public",
		})

		local response = Executor.execute(app, {
			method = "GET",
			path = "/public/missing.txt",
		})

		assert.eq(response.status, 404)
		assert.eq(response.body, nil)
	end)

	suite:case("supports SPA fallback", function()
		local app = flare.new()

		app:plugin(static, {
			root = ROOT,
			prefix = "/app",
			spaFallback = "index.html",
		})

		local response = Executor.execute(app, {
			method = "GET",
			path = "/app/dashboard/settings",
		})

		assert.eq(response.status, 200)
		assert.eq(response.headers["content-type"], "text/html")
		assert.eq(response.body, "<h1>Home</h1>\n")
	end)

	suite:case("prevents path traversal", function()
		local app = flare.new()

		app:plugin(static, {
			root = ROOT,
			prefix = "/public",
		})

		local plainTraversal = Executor.execute(app, {
			method = "GET",
			path = "/public/../schema.test.luau",
		})
		local encodedTraversal = Executor.execute(app, {
			method = "GET",
			path = "/public/%2e%2e/schema.test.luau",
		})

		assert.eq(plainTraversal.status, 404)
		assert.eq(encodedTraversal.status, 404)
	end)
end)
