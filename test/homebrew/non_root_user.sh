#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "brew is available to remote user" brew --version
check "remote user owns Homebrew" test "$(stat -c '%U' /home/linuxbrew/.linuxbrew/bin/brew)" = "brewer"
check "remote user can write the prefix" test -w /home/linuxbrew/.linuxbrew

reportResults
