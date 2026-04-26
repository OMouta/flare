local flare = require("@flare")

local app = flare.new()

app:hook("preHandler", function(request, reply)
	if request.path == "/health" then
		return nil
	end

	if request.headers.authorization ~= "Bearer dev" then
		return reply:code(401):send({
			error = "unauthorized",
		})
	end

	return nil
end)

app:get("/health", function()
	return {
		ok = true,
	}
end)

app:get("/account", function()
	return {
		id = "acct_123",
		plan = "developer",
	}
end)

app:listen({
	port = 3000,
})
