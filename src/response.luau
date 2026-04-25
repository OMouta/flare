export type Response = {
	status: number,
	headers: { [string]: string },
	body: string?,
}

export type ResponseOptions = {
	status: number?,
	headers: { [string]: string }?,
	body: string?,
}

local function normalizeHeaderName(name: string): string
	return string.lower(name)
end

local function assertStatus(status: number): ()
	if status % 1 ~= 0 then
		error("[flare] response status must be an integer", 3)
	end

	if status < 100 or status > 999 then
		error("[flare] response status must be between 100 and 999", 3)
	end
end

local function response(options: ResponseOptions?): Response
	local source: ResponseOptions = options or {}
	local status = source.status or 200
	assertStatus(status)

	local headers: { [string]: string } = {}
	if source.headers ~= nil then
		for name, value in source.headers do
			if type(name) ~= "string" then
				error("[flare] response header names must be strings", 2)
			end

			if type(value) ~= "string" then
				error("[flare] response header values must be strings", 2)
			end

			headers[normalizeHeaderName(name)] = value
		end
	end

	if source.body ~= nil and type(source.body) ~= "string" then
		error("[flare] response body must be a string when provided", 2)
	end

	return {
		status = status,
		headers = headers,
		body = source.body,
	}
end

return {
	response = response,
}
