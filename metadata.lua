-- metadata.lua
-- Backend plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin name (will be the backend name users reference)
    name = "vsfox",

    -- Required: Plugin version (not the tool versions)
    version = "0.1.0",

    -- Required: Brief description of the backend and tools it manages
    description = "Visual Studio Code (Stable + Insiders) backend for mise",

    -- Required: Plugin author/maintainer
    author = "KilobitKit",

    -- Optional: Plugin homepage/repository URL
    homepage = "https://github.com/KilobitKit/mise-vsfox",

    -- Optional: Plugin license
    license = "MIT",

    -- Optional: Important notes for users
    notes = {
        "Managed tools: vsfox:vscode (Stable), vsfox:vscode-insiders (Insiders)",
        "Supported platforms: Linux x64/arm64 and macOS x64/arm64; Windows not yet supported",
    },
}
