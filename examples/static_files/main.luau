local flare = require("@flare")
local static = require("@flare/plugins/static")

local app = flare.new()

app:plugin(static, {
	root = "examples/static_files/public",
	prefix = "/",
	cacheControl = "public, max-age=60",
	index = "index.html",
})

app:listen({
	port = 3000,
})
