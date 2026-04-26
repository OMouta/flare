# Requests, Replies, And Responses

Handlers receive `request` and `reply`.

```luau
app:get("/search", function(request)
    return {
        term = request.query.q,
    }
end)
```

## Request

Request fields:

- `method: string`
- `path: string`
- `url: string`
- `queryString: string?`
- `params: { [string]: string }`
- `query: { [string]: string | { string } }`
- `headers: { [string]: string }`
- `body: unknown?`
- `state: { [string]: unknown }`
- `env: { [string]: string }`
- `remoteAddress: string?`

Headers are normalized to lowercase. Query values are parsed lazily and repeated query keys become arrays.

```luau
app:get("/search", function(request)
    return {
        q = request.query.q,
        tags = request.query.tag,
    }
end)
```

For `/search?q=flare&tag=luau&tag=lute`, `request.query.tag` is `{ "luau", "lute" }`.

## Body Helpers

Bodies are read lazily.

```luau
app:post("/echo-text", function(request)
    return request:text()
end)

app:post("/echo-json", function(request)
    local body = request:json()
    return {
        body = body,
    }
end)

app:post("/submit", function(request)
    local form = request:form()
    return {
        name = form.name,
    }
end)
```

`request:text()` returns the raw body string. `request:json()` parses JSON and stores the parsed value on `request.body`. `request:form()` parses URL-encoded form data and stores the parsed table on `request.body`.

If `bodyLimit` is set on `flare.new`, body reads fail when the body exceeds that byte count.

## Reply

Use `reply` when you need status codes, headers, redirects, or empty responses.

```luau
app:post("/users", function(_request, reply)
    return reply
        :code(201)
        :header("x-created-by", "flare")
        :send({
            created = true,
        })
end)
```

Reply helpers:

- `reply:code(status)` and `reply:status(status)`
- `reply:header(name, value)`
- `reply:headers(headers)`
- `reply:type(contentType)`
- `reply:send(body)`
- `reply:redirect(location, status?)`
- `reply:empty(status?)`

Header names are normalized to lowercase. A reply can only be sent once.

## Return Values

Handlers may return a raw response, string, number, boolean, table, or nil.

```luau
app:get("/plain", function()
    return "hello"
end)

app:get("/json", function()
    return {
        ok = true,
    }
end)

app:get("/empty", function()
    return nil
end)
```

String, number, and boolean responses use `text/plain` by default. Tables are serialized as JSON and use `application/json` by default. Returning nil produces an empty `204` unless a reply status was explicitly set.

## Raw Responses

Use `flare.response` when you need exact response shape.

```luau
local flare = require("@flare")

app:get("/raw", function()
    return flare.response({
        status = 203,
        headers = {
            ["content-type"] = "text/plain",
        },
        body = "raw",
    })
end)
```

Raw response bodies must be strings when provided.

## Errors

Customize not found and error responses:

```luau
app:setNotFoundHandler(function(_request, reply)
    return reply:code(404):send({
        error = "not_found",
    })
end)

app:setErrorHandler(function(_request, reply, err)
    return reply:code(500):send({
        error = "internal",
        message = tostring(err),
    })
end)
```
