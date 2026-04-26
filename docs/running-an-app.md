# Running An App

Start a Flare app with `app:listen`.

```luau
local flare = require("@flare")

local app = flare.new()

app:get("/health", function()
    return {
        ok = true,
    }
end)

app:listen({
    hostname = "0.0.0.0",
    port = 3000,
})
```

Run the file with Lute:

```sh
lute server.luau
```

## Listen Options

`app:listen` accepts:

- `hostname: string?`
- `port: number?`
- `reuseport: boolean?`

Calling `app:listen` compiles the app before the server starts. Register routes, hooks, groups, and plugins before calling it.

```luau
local flare = require("@flare")
local logger = require("@flare/plugins/logger")

local app = flare.new()

app:plugin(logger)

app:get("/", function()
    return {
        message = "hello",
    }
end)

app:listen({
    port = 3000,
})
```
