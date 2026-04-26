local Io = require("@std/io")
local Process = require("@std/process")
local Time = require("@std/time")

local Types = require("../types")

type App = Types.App
type Request = Types.Request
type Response = Types.Response
type Instant = Time.Instant

export type LogLevel = "debug" | "info" | "warn" | "error" | "silent"

export type LogEntry = {
	level: LogLevel,
	method: string,
	path: string,
	status: number,
	duration: number,
	error: string?,
}

export type LoggerOptions = {
	level: LogLevel?,
	development: boolean?,
	color: boolean?,
	sink: ((entry: LogEntry) -> ())?,
	now: (() -> Instant)?,
}

local LEVELS: { [string]: number } = {
	debug = 10,
	info = 20,
	warn = 30,
	error = 40,
	silent = math.huge,
}

local COLORS: { [string]: string } = {
	debug = "\27[90m",
	info = "\27[32m",
	warn = "\27[33m",
	error = "\27[31m",
}

local RESET = "\27[0m"
local START_KEY = "__flare_logger_start"
local ERROR_KEY = "__flare_logger_error"

local Logger = {}

local function assertLevel(level: unknown): LogLevel
	if type(level) ~= "string" or LEVELS[level] == nil then
		error("[flare] logger level must be 'debug', 'info', 'warn', 'error', or 'silent'", 3)
	end

	return level :: LogLevel
end

local function validateOptions(options: { [string]: unknown }?): LoggerOptions
	local source = (options or {}) :: LoggerOptions

	if type(source) ~= "table" then
		error("[flare] logger options must be a table", 3)
	end

	local level = if source.level == nil then "info" else assertLevel(source.level)

	if source.development ~= nil and type(source.development) ~= "boolean" then
		error("[flare] logger development option must be a boolean", 3)
	end

	if source.color ~= nil and type(source.color) ~= "boolean" then
		error("[flare] logger color option must be a boolean", 3)
	end

	if source.sink ~= nil and type(source.sink) ~= "function" then
		error("[flare] logger sink option must be a function", 3)
	end

	if source.now ~= nil and type(source.now) ~= "function" then
		error("[flare] logger now option must be a function", 3)
	end

	return {
		level = level,
		development = source.development == true,
		color = source.color == true,
		sink = source.sink,
		now = source.now,
	}
end

local function terminalSupportsColor(): boolean
	local env = Process.env

	return env.NO_COLOR == nil and env.TERM ~= nil and env.TERM ~= "" and env.TERM ~= "dumb"
end

local function levelEnabled(configured: LogLevel, entryLevel: LogLevel): boolean
	return (LEVELS[entryLevel] :: number) >= (LEVELS[configured] :: number)
end

local function levelForStatus(status: number, hasError: boolean): LogLevel
	if hasError or status >= 500 then
		return "error"
	elseif status >= 400 then
		return "warn"
	end

	return "info"
end

local function formatEntry(entry: LogEntry, color: boolean): string
	local level = string.upper(entry.level)
	local prefix = level

	if color and COLORS[entry.level] ~= nil then
		prefix = (COLORS[entry.level] :: string) .. level .. RESET
	end

	local line =
		string.format("%s %s %s %d %.3fms", prefix, entry.method, entry.path, entry.status, entry.duration * 1000)

	if entry.error ~= nil then
		line ..= " " .. entry.error
	end

	return line
end

local function defaultSink(color: boolean): (LogEntry) -> ()
	local useColor = color and terminalSupportsColor()

	return function(entry: LogEntry)
		Io.write(formatEntry(entry, useColor), "\n")
	end
end

local function hookTarget(app: App): App
	return (rawget(app :: any, "_parentScope") :: App?) or app
end

function Logger.plugin(app: App, options: { [string]: unknown }?): ()
	local config = validateOptions(options)
	local configuredLevel = config.level :: LogLevel
	local now = config.now or Time.now
	local sink = config.sink or defaultSink(config.color == true)
	local target = hookTarget(app)

	target:hook("onRequest", function(request: Request)
		request.state[START_KEY] = now()
		return nil
	end)

	target:hook("onError", function(request: Request, _reply, err: unknown)
		request.state[ERROR_KEY] = err
		return nil
	end)

	target:hook("onResponse", function(request: Request, _reply, value: unknown?)
		local response = value :: Response
		local start = request.state[START_KEY] :: Instant?
		local duration = if start == nil then 0 else Time.since(start)
		local err = request.state[ERROR_KEY]
		local level = levelForStatus(response.status, err ~= nil)

		if not levelEnabled(configuredLevel, level) then
			return nil
		end

		sink({
			level = level,
			method = request.method,
			path = request.path,
			status = response.status,
			duration = duration,
			error = if config.development and err ~= nil then tostring(err) else nil,
		})

		return nil
	end)
end

return Logger.plugin
