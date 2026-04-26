local flare = require("@flare")

type Todo = {
	id: number,
	title: string,
	done: boolean,
}

local function todoBody(todo: Todo): { [string]: unknown }
	return {
		id = todo.id,
		title = todo.title,
		done = todo.done,
	}
end

local app = flare.new({
	bodyLimit = 1024 * 1024,
})

local todos: { Todo } = {
	{
		id = 1,
		title = "try Flare",
		done = false,
	},
}

local nextId = 2

app:get("/todos", function()
	return {
		todos = todos,
	}
end)

app:get("/todos/:id", function(request, reply)
	local id = tonumber(request.params.id)

	for _, todo in todos do
		if todo.id == id then
			return reply:send(todoBody(todo))
		end
	end

	return reply:code(404):send({
		error = "todo_not_found",
	})
end)

app:post("/todos", function(request, reply)
	local body = request:json() :: { [string]: unknown }
	local title = body.title

	if type(title) ~= "string" or title == "" then
		return reply:code(400):send({
			error = "title_required",
		})
	end

	local todo: Todo = {
		id = nextId,
		title = title,
		done = false,
	}

	nextId += 1
	table.insert(todos, todo)

	return reply:code(201):send(todoBody(todo))
end)

app:listen({
	port = 3000,
})
