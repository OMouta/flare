local flare = require("@flare")
local Types = require("@flare/types")

type Validator<T> = Types.Validator<T>

type ParsedParams = {
	id: number,
}

type ParsedBody = {
	displayName: string,
}

local function paramsValidator(): Validator<unknown>
	return {
		parse = function(_self: Validator<unknown>, input: unknown): unknown
			local params = input :: { [string]: string }
			local id = tonumber(params.id)

			if id == nil then
				error("id must be a number")
			end

			return {
				id = id,
			}
		end,
	}
end

local function bodyValidator(): Validator<unknown>
	return {
		parse = function(_self: Validator<unknown>, input: unknown): unknown
			local body = input :: { [string]: unknown }
			local displayName = body.displayName

			if type(displayName) ~= "string" or displayName == "" then
				error("displayName is required")
			end

			return {
				displayName = displayName,
			}
		end,
	}
end

local app = flare.new()

app:patch("/users/:id", {
	schema = {
		params = paramsValidator(),
		body = bodyValidator(),
	},
	handler = function(request)
		local params = (request.params :: unknown) :: ParsedParams
		local body = request.body :: ParsedBody

		return {
			id = params.id,
			displayName = body.displayName,
		}
	end,
})

app:listen({
	port = 3000,
})
