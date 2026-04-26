local Executor = require("./executor")
local Request = require("./request")
local Routing = require("./routing")
local Types = require("./types")

type App = Types.App
type ListenOptions = Types.ListenOptions
type Response = Types.Response
type RequestSource = Request.RequestSource

export type ReceivedRequest = {
	method: string,
	path: string,
	body: string,
	query: { [string]: string },
	headers: { [string]: string },
}

export type ServerResponse = {
	status: number?,
	body: string?,
	headers: { [string]: string }?,
}

type LuteServerModule = {
	serve: (
		config: {
			hostname: string?,
			port: number?,
			reuseport: boolean?,
			handler: (request: ReceivedRequest, server: unknown) -> ServerResponse,
		}
	) -> unknown,
}

type ListenableApp = App & {
	_server: unknown?,
}

local Listen = {}

local function queryStringFromQuery(query: { [string]: string }): string?
	local parts: { string } = {}

	for key, value in query do
		table.insert(parts, key .. "=" .. value)
	end

	if #parts == 0 then
		return nil
	end

	return table.concat(parts, "&")
end

function Listen.toRequestSource(request: ReceivedRequest): RequestSource
	local queryString = queryStringFromQuery(request.query)

	return {
		method = request.method,
		path = request.path,
		url = if queryString == nil then request.path else request.path .. "?" .. queryString,
		queryString = queryString,
		headers = request.headers,
		body = request.body,
		readBody = function()
			return request.body
		end,
	}
end

function Listen.toServerResponse(response: Response): ServerResponse
	return {
		status = response.status,
		headers = response.headers,
		body = response.body,
	}
end

function Listen.createHandler(app: App): (ReceivedRequest, unknown) -> ServerResponse
	Routing.compile(app)

	return function(request: ReceivedRequest, _server: unknown): ServerResponse
		return Listen.toServerResponse(Executor.execute(app, Listen.toRequestSource(request)))
	end
end

local function validateOptions(options: ListenOptions): ListenOptions
	if type(options) ~= "table" then
		error("[flare] listen options must be a table", 3)
	end

	if options.port ~= nil and type(options.port) ~= "number" then
		error("[flare] listen options port must be a number", 3)
	end

	if options.hostname ~= nil and type(options.hostname) ~= "string" then
		error("[flare] listen options hostname must be a string", 3)
	end

	return options
end

function Listen.listenWithServer(app: App, options: ListenOptions, serverModule: LuteServerModule): unknown
	local listenOptions = validateOptions(options)
	local handler = Listen.createHandler(app)
	local ok, serverOrError = pcall(serverModule.serve, {
		hostname = listenOptions.hostname,
		port = listenOptions.port,
		reuseport = listenOptions.reuseport,
		handler = handler,
	})

	if not ok then
		error("[flare] failed to start Lute server: " .. tostring(serverOrError), 2)
	end

	((app :: unknown) :: ListenableApp)._server = serverOrError

	return serverOrError
end

function Listen.listen(app: App, options: ListenOptions): unknown
	local serverModule = require("@lute/net/server") :: LuteServerModule

	return Listen.listenWithServer(app, options, serverModule)
end

return Listen
