--- Map the current runtime to a Microsoft update-server platform string.
--- @return string
local function vsfox_platform()
    local os_map = { linux = "linux", darwin = "darwin" }
    local arch_map = { amd64 = "x64", x86_64 = "x64", arm64 = "arm64", aarch64 = "arm64" }
    local os = os_map[RUNTIME.osType]
    local arch = arch_map[RUNTIME.archType]
    if not os then
        error(
            "vsfox: unsupported OS '"
                .. tostring(RUNTIME.osType)
                .. "' (supported: linux, darwin; windows not yet supported)"
        )
    end
    if not arch then
        error(
            "vsfox: unsupported architecture '"
                .. tostring(RUNTIME.archType)
                .. "' (supported: amd64/x86_64, arm64/aarch64)"
        )
    end
    return os .. "-" .. arch
end

--- Fetch the newest release for a quality from the releases endpoint.
--- @param quality string "stable" or "insider"
--- @return string
local function vsfox_newest_version(quality)
    local http = require("http")
    local json = require("json")
    local resp, err = http.get({
        url = "https://update.code.visualstudio.com/api/releases/" .. quality,
        headers = { ["User-Agent"] = "mise-vsfox" },
    })
    if err then
        error("vsfox: failed to fetch newest " .. quality .. " release: " .. err)
    end
    if resp.status_code ~= 200 then
        error("vsfox: releases API returned status " .. resp.status_code)
    end
    local data = json.decode(resp.body)
    if #data == 0 then
        error("vsfox: no " .. quality .. " releases available")
    end
    return data[1]
end

--- Quote a path for safe use in a shell command.
--- @param path string
--- @return string
local function vsfox_quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

--- Ensure the expected layout (and therefore the PATH binary) exists.
--- @param tool string
--- @param install_path string
local function vsfox_expect_layout(tool, install_path)
    local file = require("file")
    if RUNTIME.osType == "darwin" then
        local apps = file.glob(file.join_path(install_path, "*.app"))
        if not apps or #apps == 0 then
            error("vsfox: no .app bundle found after extracting " .. tool)
        end
        return
    end
    local bin_name = "code"
    if tool == "vscode-insiders" then
        bin_name = "code-insiders"
    end
    local wrapper = file.join_path(install_path, "bin", bin_name)
    if not file.exists(wrapper) then
        error("vsfox: unexpected archive layout for " .. tool .. ": missing " .. wrapper)
    end
end

--- Installs a specific version of a tool
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall
--- @param ctx {tool: string, version: string, install_path: string, download_path?: string} Context
--- @return table Empty table on success
function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    if not tool or tool == "" then
        error("vsfox: tool name cannot be empty")
    end
    if not version or version == "" then
        error("vsfox: version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("vsfox: install path cannot be empty")
    end

    local file = require("file")
    local http = require("http")
    local json = require("json")
    local cmd = require("cmd")
    local archiver = require("archiver")

    local qualities = {
        vscode = "stable",
        ["vscode-insiders"] = "insider",
    }
    local quality = qualities[tool]
    if not quality then
        error("vsfox: unsupported tool '" .. tool .. "' (expected vscode or vscode-insiders)")
    end

    local platform = vsfox_platform()
    local archive_ext = ".tar.gz"
    if RUNTIME.osType == "darwin" then
        archive_ext = ".zip"
    end

    local version_to_install = version
    if version == "latest" then
        version_to_install = vsfox_newest_version(quality)
    end

    -- Insider versions are listed and resolved without the "-insider" suffix
    -- (see backend_list_versions.lua) and are restored here for the download API.
    if quality == "insider" and not version_to_install:match("%-insider$") then
        version_to_install = version_to_install .. "-insider"
    end

    -- Resolve the exact CDN artifact and checksum for the pinned version.
    local meta_url = "https://update.code.visualstudio.com/api/versions/"
        .. version_to_install
        .. "/"
        .. platform
        .. "/"
        .. quality
    local meta_resp, meta_err = http.get({
        url = meta_url,
        headers = { ["User-Agent"] = "mise-vsfox" },
    })
    if meta_err then
        error("vsfox: failed to resolve " .. tool .. "@" .. version_to_install .. ": " .. meta_err)
    end
    if meta_resp.status_code == 404 then
        error("vsfox: unknown version " .. version_to_install .. " for " .. tool)
    end
    if meta_resp.status_code ~= 200 then
        error("vsfox: API returned status " .. meta_resp.status_code .. " for " .. tool .. "@" .. version_to_install)
    end

    local meta = json.decode(meta_resp.body)
    if not meta.url or not meta.sha256hash then
        error("vsfox: API response for " .. tool .. "@" .. version_to_install .. " is missing url/sha256hash")
    end

    -- Download (mise may cache the file at ctx.download_path).
    local download_dir = ctx.download_path
    if not download_dir or download_dir == "" then
        download_dir = install_path
    end
    cmd.exec("mkdir -p " .. vsfox_quote(download_dir))
    local archive_path = file.join_path(download_dir, tool .. "-" .. version_to_install .. archive_ext)

    if not file.exists(archive_path) then
        http.download_file({ url = meta.url }, archive_path)
    end

    -- Verify the SHA-256 checksum; mise backend downloads must be verified.
    local checksum = cmd.exec("sha256sum " .. vsfox_quote(archive_path))
    local actual = checksum:match("^%s*([%x]+)")
    if not actual or actual:lower() ~= meta.sha256hash:lower() then
        error(
            "vsfox: sha256 checksum mismatch for "
                .. tool
                .. "@"
                .. version_to_install
                .. " (expected "
                .. meta.sha256hash
                .. ", got "
                .. tostring(actual)
                .. ")"
        )
    end

    -- Extract. Linux tarballs have a synthetic VSCode-linux-x64/ root that is
    -- flattened; macOS zips must keep the .app bundle intact (no strip).
    local strip = 0
    if RUNTIME.osType == "linux" then
        strip = 1
    end
    archiver.decompress(archive_path, install_path, { strip_components = strip })

    -- Validate the expected layout exists before reporting success.
    vsfox_expect_layout(tool, install_path)

    return {}
end
