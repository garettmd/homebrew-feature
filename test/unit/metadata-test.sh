#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
METADATA="${REPO_ROOT}/src/homebrew/devcontainer-feature.json"

python3 - "$METADATA" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
with path.open(encoding="utf-8") as stream:
    metadata = json.load(stream)

assert metadata["id"] == "homebrew"
assert metadata["version"] == "1.0.0"
assert metadata["options"]["installBrewfile"] == {
    "type": "boolean",
    "default": False,
    "description": "Install dependencies from Brewfile in the workspace root after the workspace is mounted.",
}
assert metadata["options"]["noUpgrade"] == {
    "type": "boolean",
    "default": True,
    "description": "Pass --no-upgrade to brew bundle install.",
}
assert metadata["containerEnv"]["PATH"].startswith(
    "/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:"
)
assert metadata["containerEnv"]["HOMEBREW_NO_ANALYTICS"] == "1"
command = metadata["updateContentCommand"]["homebrew-bundle"]
assert command == "/usr/local/share/devcontainer-features/homebrew/run-bundle.sh"
PY

printf 'metadata unit tests passed\n'
