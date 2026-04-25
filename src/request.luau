local Errors = require("./errors")
local Types = require("./types")

type Request = Types.Request

local RequestModule = {}

function RequestModule.create(_source: unknown): Request
	return Errors.notImplemented("request object creation", "Task 6")
end

return RequestModule
