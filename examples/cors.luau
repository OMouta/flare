local flare = require("@flare")
local cors = require("@flare/plugins/cors")

local app = flare.new()

app:plugin(cors, {
	origin = "http://localhost:5173",
	methods = { "GET", "POST", "OPTIONS" },
	allowedHeaders = { "content-type", "authorization" },
	exposedHeaders = { "x-request-id" },
	credentials = true,
})

app:get("/api/profile", function(_request, reply)
	return reply:header("x-request-id", "example-request"):send({
		id = "user_123",
		name = "Flare User",
	})
end)

app:post("/api/messages", function(request, reply)
	local body = request:json()

	return reply:code(201):send({
		created = true,
		message = body.message,
	})
end)

app:listen({
	port = 3000,
})
