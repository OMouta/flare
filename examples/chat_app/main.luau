local flare = require("@flare")
local logger = require("@flare/plugins/logger")
local static = require("@flare/plugins/static")

type Message = {
	id: number,
	username: string,
	text: string,
}

local app = flare.new({
	bodyLimit = 16 * 1024,
})

local messages: { Message } = {}
local nextId = 1
local host = "127.0.0.1"
local port = 3000

local function trim(value: string): string
	local trimmed = string.gsub(value, "^%s*(.-)%s*$", "%1")
	return trimmed
end

local function messageBody(message: Message): { [string]: unknown }
	return {
		id = message.id,
		username = message.username,
		text = message.text,
	}
end

local function allMessages(): { { [string]: unknown } }
	local result: { { [string]: unknown } } = {}

	for _, message in messages do
		table.insert(result, messageBody(message))
	end

	return result
end

app:get("/api/messages", function()
	return {
		messages = allMessages(),
	}
end)

app:post("/api/messages", function(request, reply)
	local body = request:json()
	local username = body.username
	local text = body.text

	if type(username) ~= "string" or trim(username) == "" then
		return reply:code(400):send({
			error = "username_required",
		})
	end

	if type(text) ~= "string" or trim(text) == "" then
		return reply:code(400):send({
			error = "message_required",
		})
	end

	local message: Message = {
		id = nextId,
		username = string.sub(trim(username), 1, 32),
		text = string.sub(trim(text), 1, 500),
	}

	nextId += 1
	table.insert(messages, message)

	if #messages > 100 then
		table.remove(messages, 1)
	end

	return reply:code(201):send(messageBody(message))
end)

app:plugin(logger, {
	level = "info",
	development = true,
	color = true,
})

app:plugin(static, {
	root = "examples/chat_app/public",
	prefix = "/",
	index = "index.html",
	cacheControl = "no-store",
})

print("Flare chat app started at http://" .. host .. ":" .. tostring(port))

app:listen({
	hostname = host,
	port = port,
})
