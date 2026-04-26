# Flare [![CI](https://github.com/OMouta/flare/actions/workflows/ci.yaml/badge.svg)](https://github.com/OMouta/flare/actions/workflows/ci.yaml)

A fast, plugin-first HTTP framework for Lute.

Flare is a small, fast, opinionated HTTP framework for Luau, built exclusively for Lute. It provides a simple and intuitive API for building web applications and APIs,
with a focus on performance, extensibility, and developer experience. It's designed to be minimal out of the box, with a powerful plugin system that allows you to add only the features you need.

> Flare is still early. The examples below show the intended experience, but the API is not yet stable and may change without warning. If you want to use or contribute to Flare, please keep this in mind.

## Install

Flare does not have any versioned releases yet, you can install it by cloning the repo:

```sh
git clone https://github.com/OMouta/flare.git
```

Then require it in your app:

```luau
local flare = require("path.to.flare")
```

## Quick Start

```luau
local flare = require("@pkg/flare")

local app = flare.new({
    logger = true,
})

app:get("/", function(request, reply)
    return {
        hello = "world",
    }
end)

app:get("/health", function(request, reply)
    return reply:send({
        ok = true,
    })
end)

app:listen({
    port = 3000,
})
```

## Routes

Define routes with the HTTP method you want to handle:

```luau
app:get("/users/:id", function(request, reply)
    return {
        id = request.params.id,
    }
end)

app:post("/users", function(request, reply)
    local body = request:json()

    return reply:code(201):send({
        created = true,
        name = body.name,
    })
end)
```

Flare supports static paths, route params, and simple wildcard routes:

```luau
app:get("/assets/*", function(request, reply)
    return reply:type("text/plain"):send("asset")
end)
```

## Groups

Group related routes under a shared prefix:

```luau
app:group("/api", function(api)
    api:get("/health", function(request, reply)
        return { ok = true }
    end)

    api:get("/users/:id", function(request, reply)
        return { id = request.params.id }
    end)
end)
```

## Plugins

Use plugins for shared behavior like logging, CORS, authentication, cookies, or
static files:

```luau
local cors = require("@pkg/flare/plugins/cors")
local logger = require("@pkg/flare/plugins/logger")

app:plugin(logger)
app:plugin(cors, {
    origin = "*",
})
```

You can also write your own plugins:

```luau
local function auth(app, options)
    app:hook("preHandler", function(request, reply)
        if request.headers.authorization ~= options.token then
            return reply:code(401):send({
                error = "unauthorized",
            })
        end
    end)
end

app:plugin(auth, {
    token = "dev",
})
```

## Error Pages

Customize not found and error responses when your app needs its own shape:

```luau
app:setNotFoundHandler(function(request, reply)
    return reply:code(404):send({
        error = "not_found",
    })
end)

app:setErrorHandler(function(request, reply, err)
    return reply:code(500):send({
        error = "internal",
    })
end)
```

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE)
file for details.
