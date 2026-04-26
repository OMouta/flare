# Flare Documentation

Flare is a small HTTP framework for Luau on Lute.

## Quick Start

Create an app, register routes, and start Lute's HTTP server through `app:listen`.

```luau
local flare = require("@flare")

local app = flare.new()

app:get("/health", function()
    return {
        ok = true,
    }
end)

app:get("/users/:id", function(request)
    return {
        id = request.params.id,
    }
end)

app:listen({
    port = 3000,
})
```

Run it with Lute:

```sh
lute path/to/app.luau
```

`app:listen` accepts:

- `port: number?`
- `hostname: string?`
- `reuseport: boolean?`

## App Options

```luau
local app = flare.new({
    bodyLimit = 1024 * 1024,
})
```

Set a body limit when request bodies should be capped:

- `bodyLimit: number?`

## Guides

- [Routing](./routing.md)
- [Requests, Replies, And Responses](./requests-replies-responses.md)
- [Hooks](./hooks.md)
- [Plugins](./plugins.md)
- [Performance](./performance.md)
- [Running An App](./running-an-app.md)
