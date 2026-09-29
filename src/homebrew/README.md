
# Homebrew (homebrew)

Installs Homebrew on Linux and optionally applies a workspace-root Brewfile.

## Example Usage

```json
"features": {
    "ghcr.io/garettmd/homebrew-feature/homebrew:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| installBrewfile | Install dependencies from Brewfile in the workspace root after the workspace is mounted. | boolean | false |
| noUpgrade | Pass --no-upgrade to brew bundle install. | boolean | true |

# Brewfile behavior

When `installBrewfile` is enabled, `Brewfile` must exist in the workspace root. The Feature applies it with `updateContentCommand` after source is mounted because project files are unavailable while Features are installed into the image.

This means container creation needs network access when dependencies are missing, and Brewfile dependencies are not part of the image layer produced by Feature installation. A Brewfile is executable Ruby; enable this option only for repositories you trust.

`noUpgrade` prevents Bundle from proactively upgrading already installed formulae. It does not pin versions or prevent dependency upgrades required by a new installation. Homebrew is a rolling-release package manager and Brewfiles do not have lockfiles.

# Ownership

Homebrew is designed as a single-user installation. The container's non-root remote user owns Homebrew. If the effective user is root or absent, the Feature creates a non-root `linuxbrew` fallback because Homebrew cannot run as root.

With the fallback user, prefer taps and formulae. User-scoped entries such as `vscode`, `cargo`, `go`, or `uv` target the fallback account rather than the root remote user.

# Compatibility

This Feature supports Debian and Ubuntu containers using glibc on amd64 and arm64. Alpine uses musl and is not supported. macOS-only Brewfile entries such as `mas`, GUI casks, and some services are not suitable for Linux dev containers.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/garettmd/homebrew-feature/blob/main/src/homebrew/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
