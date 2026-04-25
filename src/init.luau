local App = require("@self/app")
local Response = require("@self/response")
local Types = require("@self/types")

export type AppOptions = Types.AppOptions
export type App = Types.App
export type RouteOptions = Types.RouteOptions
export type Handler = Types.Handler
export type HandlerResult = Types.HandlerResult
export type Request = Types.Request
export type Reply = Types.Reply
export type Response = Types.Response
export type Plugin = Types.Plugin
export type Validator<T> = Types.Validator<T>

return {
	new = App.new,
	response = Response.response,
}
