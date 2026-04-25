export type StaticSegment = {
	kind: "static",
	value: string,
}

export type ParamSegment = {
	kind: "param",
	name: string,
}

export type WildcardSegment = {
	kind: "wildcard",
}

export type Segment = StaticSegment | ParamSegment | WildcardSegment

export type ParsedPattern = {
	path: string,
	segments: { Segment },
	params: { string },
	hasWildcard: boolean,
}

local RoutePattern = {}

local function fail(path: string, message: string): never
	error("[flare] invalid route pattern '" .. path .. "': " .. message, 3)
end

local function normalizeRoot(path: string): string
	if path == "" or path == "/" then
		return "/"
	end

	return path
end

local function pushSegment(result: { Segment }, segment: Segment): ()
	table.insert(result, segment)
end

function RoutePattern.parse(path: string): ParsedPattern
	local normalizedPath = normalizeRoot(path)

	if string.sub(normalizedPath, 1, 1) ~= "/" then
		fail(path, "path must start with '/'")
	end

	if normalizedPath == "/" then
		return {
			path = "/",
			segments = {},
			params = {},
			hasWildcard = false,
		}
	end

	local parts = string.split(string.sub(normalizedPath, 2), "/")
	local segments: { Segment } = {}
	local params: { string } = {}
	local hasWildcard = false

	for index, part in parts do
		if part == "" then
			fail(path, "empty path segments are not supported")
		end

		if part == "*" then
			if index ~= #parts then
				fail(path, "wildcard segments must be final")
			end

			hasWildcard = true
			pushSegment(segments, {
				kind = "wildcard",
			})
		elseif string.sub(part, 1, 1) == ":" then
			local name = string.sub(part, 2)

			if name == "" then
				fail(path, "parameter segments must include a name")
			end

			table.insert(params, name)
			pushSegment(segments, {
				kind = "param",
				name = name,
			})
		else
			pushSegment(segments, {
				kind = "static",
				value = part,
			})
		end
	end

	return {
		path = normalizedPath,
		segments = segments,
		params = params,
		hasWildcard = hasWildcard,
	}
end

return RoutePattern
