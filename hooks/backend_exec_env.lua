--- Sets up environment variables for a tool
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendexecenv
--- @param ctx {install_path: string, tool: string, version: string} Context
--- @return {env_vars: table[]} Table containing list of environment variable definitions
function PLUGIN:BackendExecEnv(ctx)
    local install_path = ctx.install_path

    local file = require("file")

    -- Linux tarballs are extracted with the VSCode-linux-x64/ root flattened,
    -- leaving self-resolving wrappers at install_path/bin (code / code-insiders).
    -- macOS keeps the .app bundle intact; the wrapper lives inside it and
    -- resolves the app from its own location, so its real bin dir must be on
    -- PATH (a symlink shim would break dirname($0) resolution).
    local bin_path = file.join_path(install_path, "bin")
    if RUNTIME.osType == "darwin" then
        local apps = file.glob(file.join_path(install_path, "*.app"))
        if apps and #apps > 0 then
            bin_path = file.join_path(apps[1], "Contents", "Resources", "app", "bin")
        end
    end

    return {
        env_vars = {
            { key = "PATH", value = bin_path },
        },
    }
end
