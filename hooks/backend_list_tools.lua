--- Lists the finite catalog of tools managed by this backend
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlisttools
--- @return {tools: {name: string, description: string}[]} Table containing available tools
function PLUGIN:BackendListTools()
    return {
        tools = {
            { name = "vscode", description = "Visual Studio Code (Stable)" },
            { name = "vscode-insiders", description = "Visual Studio Code Insiders (daily build)" },
        },
    }
end
