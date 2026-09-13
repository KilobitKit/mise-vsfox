# mise-vsfox

A [mise](https://mise.jdx.dev) backend plugin for installing and managing
[Visual Studio Code](https://code.visualstudio.com) as runtime tools.

Exposes two tools:

| Tool | Channel | Description |
| --- | --- | --- |
| `vsfox:vscode` | `stable` | Visual Studio Code (Stable) |
| `vsfox:vscode-insiders` | `insider` | Visual Studio Code Insiders (daily build) |

## Install

```sh
mise plugin install backend:github:KilobitKit/mise-vsfox
mise use vsfox:vscode@latest
mise run code
```

While developing locally:

```sh
mise plugin link --force vsfox .
```

## Usage

```sh
# Install the latest stable VS Code for the current project
mise use vsfox:vscode@latest

# Pin an exact version
mise install vsfox:vscode@1.136.1

# Insiders (uses the rolling -insider versions)
mise use vsfox:vscode-insiders@latest

# Run the code CLI from the managed install
mise exec vsfox:vscode@latest -- code --version

# List available versions
mise ls-remote vsfox:vscode
mise ls-remote vsfox:vscode-insiders
```

The `code` (and `code-insiders` on Linux) binaries resolve to the platform
correct executable:

- **Linux** — the archive's own self-resolving `bin/code` / `bin/code-insiders`
  wrapper is placed on `PATH` (tarball root `VSCode-linux-x64/` flattened).
- **macOS** — the native `bin/code` wrapper inside the `.app` bundle is placed
  on `PATH`, so it resolves the app it lives in correctly.

## Supported platforms

| OS | Architectures |
| --- | --- |
| Linux | `x64`, `arm64` |
| macOS | `x64`, `arm64` |

Windows is not yet supported (rooted filesystem quirks); installing there fails
with a clear error.

## How it works

Versions come from `https://update.code.visualstudio.com/api/releases/{quality}`
(newest-first, returned oldest-first per the backend contract). Each install
resolves the pinned version through
`https://update.code.visualstudio.com/api/versions/{version}/{platform}/{quality}`
to obtain the exact CDN URL and `sha256hash`, downloads it, verifies the SHA-256
checksum (mise requires backend plugins to verify since `http.download_file`
does not), and extracts it into the mise-managed install path.

### Insider versions

`vsfox:vscode-insiders` versions are listed **without** the `-insider` suffix
(e.g. `1.138.0`). Microsoft's release identifiers are `X.Y.Z-insider`, but mise
flags versions matching prerelease patterns (which includes `-insider`) and
filters them — along with `@latest` resolution — unless the user opts in.
Suffixing only at download time keeps the tool usable out of the box. You can
still pass a literal suffixed version (`vsfox:vscode-insiders@1.138.0-insider`);
both forms work.

See `docs/superpowers/specs/2026-09-13-vsfox-backend-design.md` for the full
design.

## Development

```sh
mise install            # installs dev tools (lua, stylua, hk, ...)
mise run format         # format hooks + metadata with stylua
mise run lint           # hk check
mise run lint-fix       # hk fix
mise run ci             # lint + test (CI runs this on ubuntu + macos)
mise run test           # link + ls-remote for both tools (light); optional install
```

## License

MIT