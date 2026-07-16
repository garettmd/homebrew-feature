#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "brew survives duplicate installation" brew --version
check "duplicate installation preserves non-root ownership" test "$(stat -c '%U' /home/linuxbrew/.linuxbrew/bin/brew)" != "root"
check "duplicate installation preserves Feature state" test -r /usr/local/share/devcontainer-features/homebrew/config
check "duplicate installation preserves lifecycle helper" test -x /usr/local/share/devcontainer-features/homebrew/run-bundle.sh

reportResults
