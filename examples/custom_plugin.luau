local flare = require("@flare")
local Types = require("@flare/types")

type App = Types.App
type Request = Types.Request
type Response = Types.Response

local function requestId(app: App, _options: { [string]: unknown }?): ()
	app:hook("preHandler", function(request: Request)
		request.state.requestId = "req_example"
		return nil
	end)

	app:hook("onSend", function(request: Request, _reply, response)
		local current = response :: Response
		current.headers["x-request-id"] = tostring(request.state.requestId)
		return current
	end)

	app:get("/", function(request: Request)
		return {
			requestId = tostring(request.state.requestId),
		}
	end)
end

local app = flare.new()

app:plugin(requestId)

app:listen({
	port = 3000,
})
