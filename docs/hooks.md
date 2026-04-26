# Hooks

Hooks run around route execution.

```luau
app:hook("preHandler", function(request, reply)
    if request.headers.authorization ~= "Bearer dev" then
        return reply:code(401):send({
            error = "unauthorized",
        })
    end

    return nil
end)
```

Supported hook names:

- `onRequest`
- `preParsing`
- `preValidation`
- `preHandler`
- `onSend`
- `onError`
- `onResponse`

## Lifecycle

For a successful request, hooks run in this order:

1. `onRequest`
2. `preParsing`
3. `preValidation`
4. `preHandler`
5. route handler
6. `onSend`
7. `onResponse`

`onRequest`, `preParsing`, `preValidation`, and `preHandler` may short-circuit by returning a handler result.

```luau
app:hook("onRequest", function(request, reply)
    if request.headers["x-blocked"] == "true" then
        return reply:code(403):send({
            error = "blocked",
        })
    end

    return nil
end)
```

## onSend

`onSend` receives the current response as the third argument and can replace it.

```luau
app:hook("onSend", function(_request, _reply, response)
    local current = response
    current.headers["x-powered-by"] = "flare"
    return current
end)
```

## onError

`onError` runs when a handler or earlier hook errors. It receives the error value as the third argument and may replace the error response.

```luau
app:hook("onError", function(_request, reply, err)
    return reply:code(500):send({
        error = "internal",
        message = tostring(err),
    })
end)
```

## onResponse

`onResponse` runs after the final response has been produced. It can observe the response but cannot replace it.

```luau
app:hook("onResponse", function(request, _reply, response)
    local final = response
    print(request.method .. " " .. request.path .. " " .. tostring(final.status))
    return nil
end)
```

Hooks must be registered before the app compiles.
