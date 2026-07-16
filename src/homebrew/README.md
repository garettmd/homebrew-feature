# Homebrew

Installs [Homebrew](https://brew.sh/) into its supported Linux prefix, `/home/linuxbrew/.linuxbrew`.

The Feature can optionally apply a `Brewfile` from the root of the mounted workspace. This makes project-level developer tools declarative without requiring a separate Dev Container Feature for every formula.

## Usage

Install Homebrew only:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/example/devcontainer-features/homebrew:1": {}
  }
}
```

Install Homebrew and apply the project `Brewfile`:

```jsonc
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/example/devcontainer-features/homebrew:1": {
      "installBrewfile": true
    }
  }
}
```

With `installBrewfile` enabled, this file must exist at `Brewfile` in the workspace root:

```ruby
brew "jq"
brew "shellcheck"
```

Replace the example Feature namespace with the GHCR namespace where this collection is published.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `installBrewfile` | boolean | `false` | Run `brew bundle install` against `Brewfile` in the workspace root after source is mounted. |
| `noUpgrade` | boolean | `true` | Pass `--no-upgrade` to `brew bundle install`. |

`noUpgrade` prevents Bundle from proactively upgrading already installed formulae. It does not pin versions and does not prevent dependency upgrades required by a new installation.

## Ownership

Homebrew is designed as a single-user installation:

- If the container has a non-root remote user, that user owns and operates Homebrew.
- If the effective user is root or missing, the Feature creates a non-root `linuxbrew` user as a fallback because Homebrew does not run as root.

When the fallback user is used, prefer taps and formulae. User-scoped Brewfile entries such as `vscode`, `cargo`, `go`, or `uv` target the fallback account rather than the root remote user.

## Supported containers

- Debian and Ubuntu containers using glibc
- amd64 and arm64 architectures

Alpine is not supported because it uses musl libc. Homebrew requires glibc. macOS-only Brewfile entries such as `mas`, GUI casks, and some services are not suitable for Linux dev containers.

## Lifecycle and trust

The Feature itself is installed while the container image is built. A project file is not available at that stage, so the optional Bundle step runs through `updateContentCommand` after the workspace is mounted.

Consequences:

- Container creation requires network access when Bundle needs to install dependencies.
- Brewfile dependencies are not stored in the image layer created by Feature installation.
- Re-running the lifecycle command is safe; `brew bundle install` is declarative and idempotent.
- A Brewfile is executable Ruby. Enabling this option means trusting the checked-out repository to execute code as the Homebrew owner.

Homebrew is a rolling-release package manager. Brewfiles do not have lockfiles and cannot generally select arbitrary historical versions. Use versioned formulae where Homebrew provides them, or maintain a tap if stronger version control is required.
