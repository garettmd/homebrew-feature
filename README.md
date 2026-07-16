# Homebrew Dev Container Feature

A Dev Container Feature that installs Homebrew on supported Linux containers and can optionally apply a project `Brewfile` after the workspace is mounted.

The Feature source and usage documentation live in [`src/homebrew`](src/homebrew).

## Development

Open this repository in its dev container, then run:

```sh
devcontainer features test .
```

Feature metadata is validated and tests are run by the workflows in `.github/workflows`.

## License

Licensed under the Apache License, Version 2.0.
