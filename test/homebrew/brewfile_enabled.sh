#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "Brewfile formula is installed" brew list --formula hello
check "Brewfile command is available" hello --version

reportResults
