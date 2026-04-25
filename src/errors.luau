local Errors = {}

function Errors.raise(message: string): never
	error("[flare] " .. message, 2)
end

function Errors.notImplemented(feature: string, task: string): never
	return Errors.raise(feature .. " is not implemented yet; see " .. task .. ".")
end

return Errors
