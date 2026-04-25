local assert = require("@std/test/assert")
local test = require("@std/test")

local RoutePattern = require("@flare/route_pattern")

test.suite("route pattern parsing", function(suite)
	suite:case("parses static paths", function()
		local pattern = RoutePattern.parse("/users")

		assert.eq(pattern.path, "/users")
		assert.eq(pattern.params, {})
		assert.eq(pattern.hasWildcard, false)
		assert.eq(pattern.segments, {
			{
				kind = "static",
				value = "users",
			},
		})
	end)

	suite:case("parses parameter paths", function()
		local pattern = RoutePattern.parse("/users/:id")

		assert.eq(pattern.path, "/users/:id")
		assert.eq(pattern.params, { "id" })
		assert.eq(pattern.hasWildcard, false)
		assert.eq(pattern.segments, {
			{
				kind = "static",
				value = "users",
			},
			{
				kind = "param",
				name = "id",
			},
		})
	end)

	suite:case("parses multi-parameter paths in order", function()
		local pattern = RoutePattern.parse("/users/:id/posts/:postId")

		assert.eq(pattern.params, { "id", "postId" })
		assert.eq(pattern.segments, {
			{
				kind = "static",
				value = "users",
			},
			{
				kind = "param",
				name = "id",
			},
			{
				kind = "static",
				value = "posts",
			},
			{
				kind = "param",
				name = "postId",
			},
		})
	end)

	suite:case("parses suffix wildcard paths", function()
		local pattern = RoutePattern.parse("/assets/*")

		assert.eq(pattern.path, "/assets/*")
		assert.eq(pattern.params, {})
		assert.eq(pattern.hasWildcard, true)
		assert.eq(pattern.segments, {
			{
				kind = "static",
				value = "assets",
			},
			{
				kind = "wildcard",
			},
		})
	end)

	suite:case("normalizes empty and root paths to root", function()
		local empty = RoutePattern.parse("")
		local root = RoutePattern.parse("/")

		assert.eq(empty.path, "/")
		assert.eq(empty.segments, {})
		assert.eq(empty.params, {})
		assert.eq(root.path, "/")
		assert.eq(root.segments, {})
		assert.eq(root.params, {})
	end)

	suite:case("rejects malformed paths that do not start with slash", function()
		assert.throws(function()
			RoutePattern.parse("users")
		end)
	end)

	suite:case("rejects wildcard segments that are not final", function()
		assert.throws(function()
			RoutePattern.parse("/files/*/meta")
		end)
	end)

	suite:case("rejects malformed parameter and empty segments", function()
		assert.throws(function()
			RoutePattern.parse("/users/:")
		end)

		assert.throws(function()
			RoutePattern.parse("/users//posts")
		end)
	end)
end)
