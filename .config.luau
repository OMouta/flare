-- To be able to run tasks, you will need to install Luumen
-- For more information, see https://luumen.dev.

return {
    package = {
        name = "flare",
        version = "0.0.0",
        description = "A fast, plugin-first HTTP framework for Lute.",
        author = "OMouta",
        license = "MIT"
    },

    tasks = {
        ["lint:lute"] = "lute lint",
        ["lint"] = "selene src tests examples",
        ["test"] = "lute test",
        ["format"] = "stylua src tests examples benchmarks",
        ["format:check"] = "stylua --check src tests examples benchmarks",
        ["bench:luau"] = "lute benchmarks/luau-dotenv.luau",
        ["bench:js"] = "npm --prefix benchmarks run bench --silent",
        ["bench"] = {"luu run bench:luau", "luu run bench:js"},
        ["ci"] = {"luu lint", "luu run lint:lute", "luu test", "luu run format:check"},
        ["types"] = "lute setup"
    },

    luu = {
         install = {
            tools = true,
            packages = true
        },
    },

    luau = {
        languageMode = "strict",
        aliases = {
            std = "~/.lute/typedefs/1.0.0/std",
            lint = "~/.lute/typedefs/1.0.0/lint",
            lute = "~/.lute/typedefs/1.0.0/lute",
            flare = "./src"
        }
    }
}
