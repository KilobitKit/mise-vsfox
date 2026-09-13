--- Lists available versions for a tool in this backend
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions
--- @param ctx {tool: string} Context (tool = the tool name requested)
--- @return {versions: string[]} Table containing list of available versions
function PLUGIN:BackendListVersions(ctx)
    local tool = ctx.tool

    local qualities = {
        vscode = "stable",
        ["vscode-insiders"] = "insider",
    }
    local quality = qualities[tool]
    if not quality then
        error("vsfox: unsupported tool '" .. tool .. "' (expected vscode or vscode-insiders)")
    end

    local http = require("http")
    local json = require("json")

    local api_url = "https://update.code.visualstudio.com/api/releases/" .. quality
    local resp, err = http.get({
        url = api_url,
        headers = { ["User-Agent"] = "mise-vsfox" },
    })
    if err then
        error("vsfox: failed to fetch versions for " .. tool .. ": " .. err)
    end
    if resp.status_code ~= 200 then
        error("vsfox: API returned status " .. resp.status_code .. " for " .. tool)
    end

    -- The update API returns releases newest-first, but BackendListVersions
    -- must return versions oldest-to-newest, so reverse the array.
    --
    -- Insider versions are surfaced WITHOUT the "-insider" suffix: mise flags
    -- prerelease-looking versions (VERSION_REGEX includes "-insider") for vfox
    -- backends and filters them out by default, which would also break
    -- install/use of @latest. The suffix is reapplied at download time.
    local is_insider = quality == "insider"
    local data = json.decode(resp.body)
    local versions = {}
    for i = #data, 1, -1 do
        local raw = data[i]
        local version = raw
        if is_insider then
            version = raw:gsub("%-insider$", "")
        end
        table.insert(versions, version)
    end

    if #versions == 0 then
        error("vsfox: no versions found for " .. tool)
    end

    return { versions = versions }
end
