local Errors = require("./errors")
local Types = require("./types")

type Reply = Types.Reply

local ReplyModule = {}

function ReplyModule.create(): Reply
	return Errors.notImplemented("reply helper creation", "Task 2")
end

return ReplyModule
