local flare = require("@flare")

local app = flare.new()

app:get("/health", function()
	return {
		ok = true,
	} :: { [string]: unknown }
end)

app:listen({
	port = 3000,
})
