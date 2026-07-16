#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "brew is installed" brew --version
check "disabled Brewfile is not applied" bash -c '! brew list --formula hello >/dev/null 2>&1'

reportResults
