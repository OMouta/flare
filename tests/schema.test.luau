local assert = require("@std/test/assert")
local test = require("@std/test")

local Executor = require("@flare/executor")
local Types = require("@flare/types")
local flare = require("@flare")

type Validator = Types.Validator<unknown>

local function validator(parse: (unknown) -> unknown): Validator
	return {
		parse = function(_self: Validator, input: unknown): unknown
			return parse(input)
		end,
	} :: Validator
end

test.suite("schema validation", function(suite)
	suite:case("replaces params query headers and body with parsed values", function()
		local app = flare.new()

		app:post("/users/:id", {
			schema = {
				params = validator(function(input)
					local params = input :: { [string]: string }
					return {
						id = tonumber(params.id),
					}
				end),
				query = validator(function(input)
					local query = input :: { [string]: string }
					return {
						page = tonumber(query.page),
					}
				end),
				headers = validator(function(input)
					local headers = input :: { [string]: string }
					return {
						token = headers.authorization,
					}
				end),
				body = validator(function(input)
					local body = input :: { [string]: unknown }
					return {
						name = body.name,
					}
				end),
			},
			handler = function(request)
				assert.eq((request.params :: any).id, 42)
				assert.eq((request.query :: any).page, 3)
				assert.eq((request.headers :: any).token, "Bearer token")
				assert.eq((request.body :: any).name, "Ada")

				return "ok"
			end,
		})

		local response = Executor.execute(app, {
			method = "POST",
			path = "/users/42",
			queryString = "page=3",
			headers = {
				Authorization = "Bearer token",
				["Content-Type"] = "application/json",
			},
			body = '{ "name": "Ada" }',
		})

		assert.eq(response.status, 200)
		assert.eq(response.body, "ok")
	end)

	suite:case("validation failures produce client errors", function()
		local app = flare.new()

		app:get("/users/:id", {
			schema = {
				params = validator(function()
					error("id must be numeric", 0)
					return nil
				end),
			},
			handler = function()
				return "unreachable"
			end,
		})

		local response = Executor.execute(app, {
			method = "GET",
			path = "/users/abc",
		})

		assert.eq(response.status, 400)
		assert.eq(response.headers["content-type"], "application/json")
		assert.strContains(response.body :: string, '"error": "Validation Error"')
		assert.strContains(response.body :: string, '"target": "params"')
		assert.strContains(response.body :: string, "id must be numeric")
	end)

	suite:case("body validation parses form bodies from content type", function()
		local app = flare.new()

		app:post("/form", {
			schema = {
				body = validator(function(input)
					local form = input :: { [string]: string }
					return {
						name = form.name,
					}
				end),
			},
			handler = function(request)
				return (request.body :: any).name
			end,
		})

		local response = Executor.execute(app, {
			method = "POST",
			path = "/form",
			headers = {
				["Content-Type"] = "application/x-www-form-urlencoded",
			},
			body = "name=flare",
		})

		assert.eq(response.status, 200)
		assert.eq(response.body, "flare")
	end)

	suite:case("body validation reads lazily only when a body schema exists", function()
		local app = flare.new()
		local reads = 0

		app:post("/without-schema", function()
			return "ok"
		end)

		app:post("/with-schema", {
			schema = {
				body = validator(function(input)
					return input
				end),
			},
			handler = function()
				return "ok"
			end,
		})

		Executor.execute(app, {
			method = "POST",
			path = "/without-schema",
			readBody = function()
				reads += 1
				return "{}"
			end,
		})

		assert.eq(reads, 0)

		Executor.execute(app, {
			method = "POST",
			path = "/with-schema",
			headers = {
				["Content-Type"] = "application/json",
			},
			readBody = function()
				reads += 1
				return "{}"
			end,
		})

		assert.eq(reads, 1)
	end)

	suite:case("preHandler sees parsed schema values", function()
		local app = flare.new()
		local seen = nil :: number?

		app:get("/users/:id", {
			schema = {
				params = validator(function(input)
					local params = input :: { [string]: string }
					return {
						id = tonumber(params.id),
					}
				end),
			},
			handler = function()
				return "ok"
			end,
		})

		app:hook("preHandler", function(request)
			seen = (request.params :: any).id
			return nil
		end)

		Executor.execute(app, {
			method = "GET",
			path = "/users/42",
		})

		assert.eq(seen, 42)
	end)
end)
