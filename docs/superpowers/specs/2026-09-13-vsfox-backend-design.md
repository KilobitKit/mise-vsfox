# vsfox: mise backend plugin for Visual Studio Code

Date: 2026-09-13
Author: KilobitKit
Status: Approved

## Goal

A mise [backend plugin](https://mise.jdx.dev/backend-plugin-development.html)
registered as `vsfox` that manages two tools:

- `vscode` — Visual Studio Code (Stable)
- `vscode-insiders` — Visual Studio Code Insiders (daily rolling build)

Usage examples:

```bash
mise use vsfox:vscode@latest
mise install vsfox:vscode-insiders@1.138.0-insider
mise exec vsfox:vscode@1.136.1 -- code --version
```

## Supported platforms (v1)

- Linux `x64` and `arm64`
- macOS (`darwin`) `x64` and `arm64`

Windows archives exist but are out of scope for v1. The plugin errors with a
clear "not yet supported" message for unknown OS/arch combinations.

## Microsoft update API (verified live, 2026-09-13)

- Version list: `GET https://update.code.visualstudio.com/api/releases/{quality}`
  where `quality` is `stable` or `insider`. Returns a JSON array, newest first.
  Insider entries carry the `-insider` suffix (e.g. `1.138.0-insider`).
- Pinned artifact metadata:
  `GET https://update.code.visualstudio.com/api/versions/{version}/{platform}/{quality}`
  Returns JSON with `url`, `sha256hash`, `productVersion`. A version that does
  not exist returns HTTP 404. This endpoint is used for every install so that
  any user-pinned version can be resolved to an exact CDN artifact plus its
  checksum.
- Platforms exercised: `linux-x64`, `linux-arm64`, `darwin-x64`, `darwin-arm64`.
- Note: the `/latest/{platform}/{quality}` redirect and the legacy
  `/api/versions/linux-x64/stable` endpoints are intentionally NOT used — the
  former cannot pin versions and the latter 404s.

## Version listing

`hooks/backend_list_versions.lua`

- Tool → quality map: `vscode` → `stable`, `vscode-insiders` → `insider`.
  Unknown tool → error.
- Fetch `api/releases/{quality}`, require HTTP 200, decode JSON.
- The API returns newest-first, but BackendListVersions must return versions
  oldest→newest, so the array is reversed before returning.
- The `-insider` suffix is the literal version string (matches the download API).

## Installation

`hooks/backend_install.lua`

1. Validate `tool`; map `RUNTIME.osType`/`RUNTIME.archType` to a Microsoft
   platform string. `amd64` → `x64`. Anything else (e.g. `windows`) →
   "not yet supported" error.
2. Resolve artifact metadata:
   `GET api/versions/{version}/{platform}/{quality}`. HTTP 404 → clear
   "unknown version" error. A defensive `latest` fallback resolves the newest
   release from `api/releases/{quality}` first.
3. Download to `ctx.download_path` (fall back to `install_path` if absent),
   reusing a pre-existing file (mise download cache) instead of re-downloading.
4. Verify SHA-256 with `sha256sum` against the API-provided `sha256hash`.
   Mise requires backend plugins that download to verify explicitly.
5. Extract with `archiver.decompress`:
   - Linux: `strip_components = 1` (flattens the synthetic `VSCode-linux-x64/`
     archive root; verified for both stable and insiders tarballs).
   - macOS: no strip. The `.app` bundle must stay intact.
6. Cleanup: the archive lives in the mise-managed download path, which is kept
   for caching; nothing is left in `install_path`.

## Verified archive layouts (evidence)

| tool            | linux archive root         | shell wrapper (self-resolving)                |
|-----------------|----------------------------|-----------------------------------------------|
| vscode          | `VSCode-linux-x64/`        | `bin/code` (after strip: `install_path/bin/code`) |
| vscode-insiders | `VSCode-linux-x64/`        | `bin/code-insiders` (after strip: `install_path/bin/code-insiders`) |

| tool            | macOS archive top-level    | shell wrapper                                 |
|-----------------|----------------------------|-----------------------------------------------|
| vscode          | `Visual Studio Code.app`   | `Visual Studio Code.app/Contents/Resources/app/bin/code` |
| vscode-insiders | `Visual Studio Code - Insiders.app` | `Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code` |

All wrappers resolve their own location via `dirname "$0"` and exec their real
binary relative to it (`../code` / `<app>/Contents/MacOS/Electron`), so the real
bin directories can be placed on `PATH` directly. No symlink shims are needed.

## Environment

`hooks/backend_exec_env.lua`

- Linux: add `install_path/bin` to `PATH`.
- macOS: add `<install_path>/<app>.app/Contents/Resources/app/bin` to `PATH`,
  locating the bundle via `file.glob("*.app")`.

Returns `{ env_vars = { { key = "PATH", value = <bin dir> } } }`.

## Tool catalog

`hooks/backend_list_tools.lua` (new) implements the optional
`BackendListTools` hook — a finite catalog so `mise search` and tab-completion
work:

```lua
{ { name = "vscode",        description = "Visual Studio Code (Stable)" },
  { name = "vscode-insiders", description = "Visual Studio Code Insiders (daily)" } }
```

## Error handling

- Validate tool and platform up front with clear messages.
- Check HTTP `status_code` before parsing bodies.
- `cmd.exec` raises on nonzero exit including stderr — rely on that.
- On macOS, if no `*.app` is found after extraction, error with a layout-drift
  message rather than silently returning a broken PATH.

## Testing

`mise-tasks/test` (links the repo as `vsfox`, hard-asserts `ls-remote` for both
tools) plus the CI matrix (ubuntu-latest, macos-latest via `.github/workflows/ci.yml`)
and the local install/exec flow:

```bash
mise plugin link --force vsfox .
mise ls-remote vsfox:vscode
mise ls-remote vsfox:vscode-insiders
mise install vsfox:vscode@latest
mise exec vsfox:vscode@latest -- code --version
```

CI intentionally runs the light test only (`ls-remote` asserted; the ~120 MB
real install is verified locally by the maintainer) to keep pushes fast.

## Non-goals

- Windows support (explicit error, documented)
- Managing the `code-tunnel` / `code-tunnel-insiders` CLIs
- curl-based installers or the `/sha/download` redirect endpoint