#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

BREW_BIN=/home/linuxbrew/.linuxbrew/bin/brew

check "brew is on PATH" command -v brew
check "brew uses the supported Linux prefix" test "$(brew --prefix)" = "/home/linuxbrew/.linuxbrew"
check "brew binary exists" test -x "$BREW_BIN"
check "Homebrew is not owned by root" test "$(stat -c '%U' "$BREW_BIN")" != "root"
check "analytics are disabled" test "${HOMEBREW_NO_ANALYTICS:-}" = "1"

reportResults
