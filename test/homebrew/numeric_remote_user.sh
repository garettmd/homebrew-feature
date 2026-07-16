#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "numeric remote user resolves to its account name" test "$(stat -c '%U' /home/linuxbrew/.linuxbrew/bin/brew)" = "vscode"
check "numeric remote user can run brew" brew --version
check "numeric remote user can write the prefix" test -w /home/linuxbrew/.linuxbrew

reportResults
