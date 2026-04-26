local Errors = {}

function Errors.raise(message: string): never
	error("[flare] " .. message, 2)
end

return Errors
