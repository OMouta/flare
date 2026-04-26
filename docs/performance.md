# Performance

Flare compiles route definitions into method-specific lookup tables before serving requests. Exact routes are checked first, then param routes, then wildcard routes.

## Route Shape

Prefer exact routes for hot paths:

```luau
app:get("/health", function()
    return {
        ok = true,
    }
end)
```

Use params when a segment is variable:

```luau
app:get("/users/:id", function(request)
    return {
        id = request.params.id,
    }
end)
```

Use wildcards for suffix-style route families such as static assets:

```luau
app:get("/assets/*", function(_request, reply)
    return reply:type("text/plain"):send("asset")
end)
```

Wildcard routes should be broad fallback routes, not the default shape for normal API endpoints.

## Request Work

Query strings and bodies are parsed lazily. If a handler does not read `request.query`, `request:text()`, `request:json()`, or `request:form()`, Flare does not do that parsing work.

```luau
app:get("/ping", function()
    return "pong"
end)

app:post("/users", function(request)
    local body = request:json()

    return {
        created = true,
        body = body,
    }
end)
```

Set `bodyLimit` for apps that accept request bodies:

```luau
local app = flare.new({
    bodyLimit = 1024 * 1024,
})
```

## Hooks And Plugins

Hooks are useful for shared behavior, but each hook is part of the request path. Keep global hooks focused and put route-specific work close to the route when possible.

```luau
app:hook("preHandler", function(request, reply)
    if request.headers.authorization == nil then
        return reply:code(401):send({
            error = "unauthorized",
        })
    end

    return nil
end)
```

Plugins compose the same route and hook primitives. Use them to package shared behavior without adding work to routes that do not need it.
