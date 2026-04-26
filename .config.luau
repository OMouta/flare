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
        ["lint"] = "lute lint src tests examples bench",
        ["test"] = "lute test",
        ["format"] = "stylua src tests examples bench",
        ["format:check"] = "stylua --check src tests examples bench",
        ["typecheck"] = "lute check src tests examples bench",
        ["bench"] = "lute bench/init.luau",
        ["ci"] = {"luu run format:check", "luu lint", "luu run typecheck", "luu test"},
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
