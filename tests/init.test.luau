local assert = require("@std/test/assert")
local test = require("@std/test")

local flare = require("@flare")

test.suite("flare scaffold", function(suite)
	suite:case("can create an app with every public method", function()
		local app = flare.new()

		assert.eq(type(app.get), "function")
		assert.eq(type(app.post), "function")
		assert.eq(type(app.put), "function")
		assert.eq(type(app.patch), "function")
		assert.eq(type(app.delete), "function")
		assert.eq(type(app.head), "function")
		assert.eq(type(app.options), "function")
		assert.eq(type(app.route), "function")
		assert.eq(type(app.hook), "function")
		assert.eq(type(app.group), "function")
		assert.eq(type(app.plugin), "function")
		assert.eq(type(app.decorate), "function")
		assert.eq(type(app.setNotFoundHandler), "function")
		assert.eq(type(app.setErrorHandler), "function")
		assert.eq(type(app.compile), "function")
		assert.eq(type(app.listen), "function")
		assert.eq(type(app.printRoutes), "function")
	end)

	suite:case("rejects invalid app options", function()
		assert.throws(function()
			flare.new({
				trailingSlash = "invalid" :: any,
			})
		end)

		assert.throws(function()
			flare.new({
				bodyLimit = -1,
			})
		end)
	end)
end)

test.suite("flare.response", function(suite)
	suite:case("returns a complete response record", function()
		local response = flare.response()

		assert.eq(response.status, 200)
		assert.eq(response.body, nil)
		assert.eq(response.headers, {})
	end)

	suite:case("normalizes headers and preserves body", function()
		local response = flare.response({
			status = 202,
			headers = {
				["Content-Type"] = "text/plain",
			},
			body = "accepted",
		})

		assert.eq(response.status, 202)
		assert.eq(response.headers, {
			["content-type"] = "text/plain",
		})
		assert.eq(response.body, "accepted")
	end)

	suite:case("rejects malformed response data", function()
		assert.throws(function()
			flare.response({
				status = 99,
			})
		end)

		assert.throws(function()
			flare.response({
				status = 200.5,
			})
		end)

		assert.throws(function()
			flare.response({
				headers = {
					ok = 1 :: any,
				},
			})
		end)

		assert.throws(function()
			flare.response({
				body = true :: any,
			})
		end)
	end)
end)
