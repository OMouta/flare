export type AppOptions = {
	logger: boolean?,
	caseSensitive: boolean?,
	trailingSlash: ("strict" | "ignore" | "redirect")?,
	bodyLimit: number?,
}

export type Validator<T> = {
	parse: (self: Validator<T>, input: unknown) -> T,
}

export type RouteSchema = {
	params: Validator<unknown>?,
	query: Validator<unknown>?,
	headers: Validator<unknown>?,
	body: Validator<unknown>?,
}

export type Response = {
	status: number,
	headers: { [string]: string },
	body: string?,
}

export type Request = {
	method: string,
	path: string,
	url: string,
	queryString: string?,
	params: { [string]: string },
	query: { [string]: string | { string } },
	headers: { [string]: string },
	body: unknown?,
	state: { [string]: unknown },
	env: { [string]: string },
	remoteAddress: string?,

	text: (self: Request) -> string,
	json: (self: Request) -> unknown,
	form: (self: Request) -> { [string]: string | { string } },
}

export type Reply = {
	statusCode: number,
	sent: boolean,

	code: (self: Reply, status: number) -> Reply,
	status: (self: Reply, status: number) -> Reply,
	header: (self: Reply, name: string, value: string) -> Reply,
	headers: (self: Reply, headers: { [string]: string }) -> Reply,
	type: (self: Reply, contentType: string) -> Reply,
	send: (self: Reply, body: unknown?) -> Response,
	redirect: (self: Reply, location: string, status: number?) -> Response,
	empty: (self: Reply, status: number?) -> Response,
}

export type HandlerResult = Response | string | boolean | number | { [string]: unknown } | nil

export type Handler = (request: Request, reply: Reply) -> HandlerResult

export type RouteHandlerOptions = {
	schema: RouteSchema?,
	config: { [string]: unknown }?,
	handler: Handler,
}

export type RouteOptions = {
	method: string,
	path: string,
	schema: RouteSchema?,
	config: { [string]: unknown }?,
	handler: Handler,
}

export type Plugin = (app: App, options: { [string]: unknown }?) -> ()

export type App = {
	get: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	post: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	put: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	patch: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	delete: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	head: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	options: (self: App, path: string, handler: Handler | RouteHandlerOptions) -> App,
	route: (self: App, options: RouteOptions) -> App,
	hook: (self: App, name: string, handler: Handler) -> App,
	group: (self: App, prefix: string, callback: (scope: App) -> ()) -> App,
	plugin: (self: App, plugin: Plugin, options: { [string]: unknown }?) -> App,
	decorate: (self: App, name: string, value: unknown) -> App,
	setNotFoundHandler: (self: App, handler: Handler) -> App,
	setErrorHandler: (self: App, handler: Handler) -> App,
	compile: (self: App) -> App,
	listen: (self: App, options: { [string]: unknown }) -> App,
	printRoutes: (self: App) -> string,
}

return {}
