# Routing

Flare supports `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`.

```luau
local flare = require("@flare")

local app = flare.new()

app:get("/", function()
    return "home"
end)

app:post("/users", function(request, reply)
    local body = request:json()

    return reply:code(201):send({
        created = true,
        name = body.name,
    })
end)

app:put("/users/:id", function(request)
    return {
        updated = request.params.id,
    }
end)

app:listen({
    port = 3000,
})
```

## Route Patterns

Static routes match exact paths:

```luau
app:get("/health", function()
    return {
        ok = true,
    }
end)
```

Param routes use `:name` segments. Matched values are available on `request.params`.

```luau
app:get("/users/:id/posts/:postId", function(request)
    return {
        userId = request.params.id,
        postId = request.params.postId,
    }
end)
```

Wildcard routes use `*` as the final segment and match the rest of the path.

```luau
app:get("/assets/*", function(_request, reply)
    return reply:type("text/plain"):send("asset route")
end)
```

Route paths must start with `/`. Empty segments, duplicate routes, overlapping dynamic patterns, and non-final wildcards are rejected during registration.

## Route Options

Every method helper accepts either a handler or an options table with `handler`, `schema`, and `config`.

```luau
local function stringValidator()
    return {
        parse = function(_self, input)
            local values = input :: { [string]: string }
            return {
                id = values.id,
            }
        end,
    }
end

app:get("/users/:id", {
    schema = {
        params = stringValidator(),
    },
    config = {
        requiresAuth = true,
    },
    handler = function(request)
        local params = request.params :: { id: string }
        return {
            id = params.id,
        }
    end,
})
```

Schemas can validate and replace `params`, `query`, `headers`, and `body`. A validator must provide a `parse(self, input)` method. Validation failures produce a `400` JSON response.

## Generic Routes

Use `app:route` when the method is dynamic.

```luau
app:route({
    method = "PATCH",
    path = "/profile",
    handler = function()
        return {
            ok = true,
        }
    end,
})
```

## Groups

Groups register routes under a shared prefix.

```luau
app:group("/api", function(api)
    api:get("/health", function()
        return {
            ok = true,
        }
    end)

    api:get("/users/:id", function(request)
        return {
            id = request.params.id,
        }
    end)
end)
```

`/api/health` and `/api/users/:id` are registered on the parent app.

## Compilation

Routes compile automatically on the first request or when `app:listen` starts. You can compile explicitly:

```luau
app:compile()
```

After compilation, route, hook, group, and plugin registration are closed.

Print registered routes with:

```luau
local routes = app:printRoutes()
print(routes)
```
