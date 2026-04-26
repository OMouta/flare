local flare = require("@flare")

local app = flare.new()

app:setNotFoundHandler(function(request, reply)
	return reply:code(404):send({
		error = "not_found",
		path = request.path,
	})
end)

app:setErrorHandler(function(_request, reply, err)
	return reply:code(500):send({
		error = "internal_error",
		message = tostring(err),
	})
end)

app:get("/", function()
	return {
		message = "open /missing or /boom",
	}
end)

app:get("/boom", function()
	error("something went wrong")
	return nil
end)

app:listen({
	port = 3000,
})
