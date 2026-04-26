local flare = require("@flare")

local app = flare.new()

app:group("/api", function(api)
	api:get("/health", function()
		return {
			ok = true,
		}
	end)

	api:group("/users", function(users)
		users:get("/", function()
			return {
				users = {
					{
						id = "1",
						name = "Ada",
					},
					{
						id = "2",
						name = "Linus",
					},
				},
			}
		end)

		users:get("/:id", function(request)
			return {
				id = request.params.id,
			}
		end)
	end)
end)

app:listen({
	port = 3000,
})
