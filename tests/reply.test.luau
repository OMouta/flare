local assert = require("@std/test/assert")
local test = require("@std/test")

local flare = require("@flare")
local Reply = require("@flare/reply")

test.suite("reply status helpers", function(suite)
	suite:case("code and status set status and return the same reply", function()
		local reply = Reply.create()

		assert.eq(reply:code(201), reply)
		assert.eq(reply.statusCode, 201)
		assert.eq(reply:status(202), reply)
		assert.eq(reply.statusCode, 202)

		local response = reply:send("created")
		assert.eq(response.status, 202)
		assert.eq(response.body, "created")
	end)
end)

test.suite("reply header helpers", function(suite)
	suite:case("header normalizes a single response header", function()
		local response = Reply.create():header("Content-Type", "text/html"):send("<h1>ok</h1>")

		assert.eq(response.headers, {
			["content-type"] = "text/html",
		})
	end)

	suite:case("headers applies every provided header", function()
		local response = Reply.create()
			:headers({
				["X-Request-Id"] = "abc",
				["Cache-Control"] = "no-store",
			})
			:send("ok")

		assert.eq(response.headers, {
			["cache-control"] = "no-store",
			["content-type"] = "text/plain",
			["x-request-id"] = "abc",
		})
	end)

	suite:case("type sets content-type", function()
		local response = Reply.create():type("application/custom"):send("ok")

		assert.eq(response.headers["content-type"], "application/custom")
	end)
end)

test.suite("reply send conversions", function(suite)
	suite:case("sends strings as text/plain", function()
		local response = Reply.create():send("hello")

		assert.eq(response.status, 200)
		assert.eq(response.headers["content-type"], "text/plain")
		assert.eq(response.body, "hello")
	end)

	suite:case("sends numbers and booleans as text/plain", function()
		local numberResponse = Reply.create():send(42)
		local booleanResponse = Reply.create():send(false)

		assert.eq(numberResponse.headers["content-type"], "text/plain")
		assert.eq(numberResponse.body, "42")
		assert.eq(booleanResponse.headers["content-type"], "text/plain")
		assert.eq(booleanResponse.body, "false")
	end)

	suite:case("sends tables as JSON", function()
		local response = Reply.create():send({
			ok = true,
		})

		assert.eq(response.status, 200)
		assert.eq(response.headers["content-type"], "application/json")
		assert.eq(response.body, '{ "ok": true}')
	end)

	suite:case("preserves an explicit content type for plain values", function()
		local response = Reply.create():type("application/vnd.api+json"):send({
			ok = true,
		})

		assert.eq(response.headers["content-type"], "application/vnd.api+json")
		assert.eq(response.body, '{ "ok": true}')
	end)

	suite:case("sends nil as 204 unless status was explicitly set", function()
		local defaultResponse = Reply.create():send(nil)
		local explicitResponse = Reply.create():code(202):send(nil)

		assert.eq(defaultResponse.status, 204)
		assert.eq(defaultResponse.body, nil)
		assert.eq(explicitResponse.status, 202)
		assert.eq(explicitResponse.body, nil)
	end)

	suite:case("accepts raw responses", function()
		local response = Reply.create():send(flare.response({
			status = 203,
			headers = {
				["Content-Type"] = "text/plain",
			},
			body = "raw",
		}))

		assert.eq(response.status, 203)
		assert.eq(response.headers, {
			["content-type"] = "text/plain",
		})
		assert.eq(response.body, "raw")
	end)
end)

test.suite("reply terminal helpers", function(suite)
	suite:case("redirect returns a default 302 redirect response", function()
		local response = Reply.create():redirect("/login")

		assert.eq(response.status, 302)
		assert.eq(response.headers.location, "/login")
		assert.eq(response.body, nil)
	end)

	suite:case("redirect accepts a custom status", function()
		local response = Reply.create():redirect("/moved", 301)

		assert.eq(response.status, 301)
		assert.eq(response.headers.location, "/moved")
	end)

	suite:case("empty returns an empty response with the requested status", function()
		local response = Reply.create():empty(204)

		assert.eq(response.status, 204)
		assert.eq(response.body, nil)
	end)

	suite:case("sending twice is reported as an error", function()
		local reply = Reply.create()
		reply:send("first")

		assert.throws(function()
			reply:send("second")
		end)
	end)
end)
