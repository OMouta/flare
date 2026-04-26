# Plugins

Plugins receive an app scope and an optional options table.

```luau
local function auth(app, options)
    local config = options or {}

    app:hook("preHandler", function(request, reply)
        if request.headers.authorization ~= config.token then
            return reply:code(401):send({
                error = "unauthorized",
            })
        end

        return nil
    end)
end

app:plugin(auth, {
    token = "Bearer dev",
})
```

Plugins can register routes, hooks, nested plugins, and decorations.

```luau
app:decorate("config", {
    name = "flare",
})

app:plugin(function(api)
    api:get("/config", function()
        return (api :: any).config
    end)
end)
```

Plugin scopes can read parent decorations. Parent scopes do not receive child decorations.

## Logger

The logger plugin records request method, path, status, duration, and optional error details.

```luau
local logger = require("@flare/plugins/logger")

app:plugin(logger, {
    level = "info",
    development = true,
    color = true,
})
```

Logger options:

- `level: "debug" | "info" | "warn" | "error" | "silent"?`
- `development: boolean?`
- `color: boolean?`
- `sink: ((entry) -> ())?`
- `now: (() -> Instant)?`

Use `sink` to collect structured entries instead of writing to stdout.

```luau
local entries = {}

app:plugin(logger, {
    sink = function(entry)
        table.insert(entries, entry)
    end,
})
```

Error details are only included in log entries when `development = true`.

## CORS

The CORS plugin adds CORS headers to responses and registers an `OPTIONS /*` preflight route.

```luau
local cors = require("@flare/plugins/cors")

app:plugin(cors, {
    origin = "https://example.com",
    methods = { "GET", "POST", "OPTIONS" },
    allowedHeaders = { "content-type", "authorization" },
    exposedHeaders = { "x-request-id" },
    credentials = true,
})
```

CORS options:

- `origin: string | { string }?`, default `*`
- `methods: { string }?`, default `{ "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS" }`
- `allowedHeaders: { string }?`
- `exposedHeaders: { string }?`
- `credentials: boolean?`

When `credentials = true`, `origin` cannot be `*`.

## Static Files

The static plugin serves files from a configured root.

```luau
local static = require("@flare/plugins/static")

app:plugin(static, {
    root = "public",
    prefix = "/assets",
    cacheControl = "public, max-age=60",
})
```

Static options:

- `root: string`
- `prefix: string?`, default `/`
- `index: string | { string }?`, default `index.html`
- `cacheControl: string?`
- `spaFallback: string?`

```luau
app:plugin(static, {
    root = "dist",
    prefix = "/app",
    spaFallback = "index.html",
})
```

The plugin rejects path traversal attempts and returns `404` when a file cannot be found.
