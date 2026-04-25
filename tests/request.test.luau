local assert = require("@std/test/assert")
local test = require("@std/test")

local Request = require("@flare/request")

test.suite("request creation", function(suite)
	suite:case("normalizes core request fields and headers", function()
		local request = Request.create({
			method = "post",
			url = "/users?active=true",
			headers = {
				["Content-Type"] = "application/json",
				["X-Request-Id"] = "abc",
			},
			params = {
				id = "42",
			},
			env = {
				MODE = "test",
			},
			remoteAddress = "127.0.0.1",
		})

		assert.eq(request.method, "POST")
		assert.eq(request.path, "/users")
		assert.eq(request.url, "/users?active=true")
		assert.eq(request.queryString, "active=true")
		assert.eq(request.params, {
			id = "42",
		})
		assert.eq(request.headers, {
			["content-type"] = "application/json",
			["x-request-id"] = "abc",
		})
		assert.eq(request.env.MODE, "test")
		assert.eq(request.remoteAddress, "127.0.0.1")
	end)

	suite:case("defaults missing fields", function()
		local request = Request.create({})

		assert.eq(request.method, "GET")
		assert.eq(request.path, "/")
		assert.eq(request.url, "/")
		assert.eq(request.queryString, nil)
		assert.eq(request.params, {})
		assert.eq(request.headers, {})
		assert.eq(request.state, {})
		assert.eq(request.env, {})
	end)
end)

test.suite("request query parsing", function(suite)
	suite:case("parses query lazily", function()
		local request = Request.create({
			url = "/search?q=flare&page=1",
		})

		assert.eq((request :: any)._queryParsed, false)
		assert.eq(request.query.q, "flare")
		assert.eq((request :: any)._queryParsed, true)
		assert.eq(request.query.page, "1")
	end)

	suite:case("supports repeated query keys as arrays", function()
		local request = Request.create({
			queryString = "tag=lua&tag=web&empty=&encoded=hello+world%21",
		})

		assert.eq(request.query.tag, { "lua", "web" })
		assert.eq(request.query.empty, "")
		assert.eq(request.query.encoded, "hello world!")
	end)
end)

test.suite("request body parsing", function(suite)
	suite:case("reads and caches body text lazily", function()
		local reads = 0
		local request = Request.create({
			readBody = function()
				reads += 1
				return "hello"
			end,
		})

		assert.eq(reads, 0)
		assert.eq((request :: any)._bodyTextRead, false)
		assert.eq(request:text(), "hello")
		assert.eq(request:text(), "hello")
		assert.eq(reads, 1)
		assert.eq((request :: any)._bodyTextRead, true)
		assert.eq(request.body, "hello")
	end)

	suite:case("parses cached JSON lazily", function()
		local reads = 0
		local request = Request.create({
			readBody = function()
				reads += 1
				return '{ "ok": true, "count": 2 }'
			end,
		})

		assert.eq(reads, 0)

		local body = request:json() :: any

		assert.eq(reads, 1)
		assert.eq(body.ok, true)
		assert.eq(body.count, 2)
		assert.eq((request:json() :: any).count, 2)
		assert.eq(reads, 1)
	end)

	suite:case("parses cached form bodies lazily", function()
		local reads = 0
		local request = Request.create({
			readBody = function()
				reads += 1
				return "name=flare&tag=lua&tag=web"
			end,
		})

		local form = request:form()

		assert.eq(reads, 1)
		assert.eq(form.name, "flare")
		assert.eq(form.tag, { "lua", "web" })
		assert.eq(request:form(), form)
		assert.eq(reads, 1)
	end)

	suite:case("checks body size limit before parsing", function()
		local request = Request.create({
			body = "abcdef",
		}, {
			bodyLimit = 3,
		})

		assert.throws(function()
			request:text()
		end)
	end)

	suite:case("does not parse body when body helpers are not called", function()
		local reads = 0
		local request = Request.create({
			readBody = function()
				reads += 1
				return "unused"
			end,
		})

		request.state.seen = true

		assert.eq(reads, 0)
		assert.eq(request.state.seen, true)
	end)
end)
