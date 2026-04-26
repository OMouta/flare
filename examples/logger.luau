local flare = require("@flare")
local logger = require("@flare/plugins/logger")

local app = flare.new()

app:plugin(logger, {
	level = "info",
	development = true,
	color = true,
})

app:get("/", function()
	return {
		message = "open /health or /boom",
	}
end)

app:get("/health", function()
	return {
		ok = true,
	}
end)

app:get("/boom", function()
	error("example failure")
	return nil
end)

app:listen({
	port = 3000,
})
