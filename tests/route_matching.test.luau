local assert = require("@std/test/assert")
local test = require("@std/test")

local flare = require("@flare")
local Routing = require("@flare/routing")

local function exactHandler()
	return "exact"
end

local function paramHandler()
	return "param"
end

local function wildcardHandler()
	return "wildcard"
end

local function postHandler()
	return "post"
end

local function compiledRouter(app)
	return (app :: any)._compiledRouter
end

test.suite("route compilation", function(suite)
	suite:case("builds immutable per-method exact and dynamic route tables", function()
		local app = flare.new()

		app:get("/health", exactHandler)
		app:get("/users/:id", paramHandler)
		app:get("/assets/*", wildcardHandler)

		assert.eq(app:compile(), app)

		local router = compiledRouter(app)
		local getRoutes = router.methods.GET

		assert.eq((app :: any)._compiled, true)
		assert.eq(getRoutes.exact["/health"].handler, exactHandler)
		assert.eq(getRoutes.params[1].handler, paramHandler)
		assert.eq(getRoutes.wildcards[1].handler, wildcardHandler)

		assert.throws(function()
			getRoutes.params[2] = getRoutes.params[1]
		end)
	end)

	suite:case("rejects route registration after compilation", function()
		local app = flare.new()

		app:get("/health", exactHandler)
		app:compile()

		assert.throws(function()
			app:get("/late", exactHandler)
		end)
	end)
end)

test.suite("route matching", function(suite)
	suite:case("matches exact routes", function()
		local app = flare.new()

		app:get("/health", exactHandler)
		app:compile()

		local result = Routing.match(app, "GET", "/health")

		assert.eq(result.kind, "found")
		assert.eq((result :: any).route.handler, exactHandler)
		assert.eq((result :: any).params, {})
	end)

	suite:case("matches parameter routes and returns params", function()
		local app = flare.new()

		app:get("/users/:id/posts/:postId", paramHandler)
		app:compile()

		local result = Routing.match(app, "GET", "/users/42/posts/99")

		assert.eq(result.kind, "found")
		assert.eq((result :: any).route.handler, paramHandler)
		assert.eq((result :: any).params, {
			id = "42",
			postId = "99",
		})
	end)

	suite:case("matches wildcard routes", function()
		local app = flare.new()

		app:get("/assets/*", wildcardHandler)
		app:compile()

		local result = Routing.match(app, "GET", "/assets/css/app.css")

		assert.eq(result.kind, "found")
		assert.eq((result :: any).route.handler, wildcardHandler)
		assert.eq((result :: any).params, {})
	end)

	suite:case("distinguishes path misses from method misses", function()
		local app = flare.new()

		app:get("/health", exactHandler)
		app:compile()

		assert.eq(Routing.match(app, "GET", "/missing").kind, "path_miss")
		assert.eq(Routing.match(app, "POST", "/health").kind, "method_miss")
	end)

	suite:case("uses exact before params and params before wildcards", function()
		local app = flare.new()

		app:get("/users/:id", paramHandler)
		app:get("/users/me", exactHandler)
		app:get("/users/*", wildcardHandler)
		app:post("/users/:id", postHandler)
		app:compile()

		local exact = Routing.match(app, "GET", "/users/me")
		local param = Routing.match(app, "GET", "/users/123")
		local wildcard = Routing.match(app, "GET", "/users/123/settings")

		assert.eq(exact.kind, "found")
		assert.eq((exact :: any).route.handler, exactHandler)
		assert.eq(param.kind, "found")
		assert.eq((param :: any).route.handler, paramHandler)
		assert.eq((param :: any).params, {
			id = "123",
		})
		assert.eq(wildcard.kind, "found")
		assert.eq((wildcard :: any).route.handler, wildcardHandler)
	end)

	suite:case("can compile lazily through match", function()
		local app = flare.new()

		app:get("/health", exactHandler)

		local result = Routing.match(app, "GET", "/health")

		assert.eq(result.kind, "found")
		assert.eq((app :: any)._compiled, true)
	end)
end)
