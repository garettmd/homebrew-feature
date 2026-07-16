#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
SCRIPT="${REPO_ROOT}/src/homebrew/runtime-ownership.sh"
TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    haystack=$1
    needle=$2
    case "$haystack" in
        *"$needle"*) ;;
        *) fail "expected '$haystack' to contain '$needle'" ;;
    esac
}

fixture="${TMPDIR_ROOT}/runtime-repair"
mkdir -p "${fixture}/bin" "${fixture}/prefix"

cat > "${fixture}/bin/id" <<'EOF'
#!/bin/sh
case "${1:-}" in
    "") printf '1001\n' ;;
    -u) printf '1001\n' ;;
    -gn) printf 'brewgroup\n' ;;
    *) exit 1 ;;
esac
EOF
cat > "${fixture}/bin/stat" <<'EOF'
#!/bin/sh
printf '1000\n'
EOF
cat > "${fixture}/bin/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "${SUDO_ARGS_FILE}"
EOF
chmod +x "${fixture}/bin/id" "${fixture}/bin/stat" "${fixture}/bin/sudo"

PATH="${fixture}/bin:${PATH}"
export PATH
# shellcheck source=/dev/null
. "$SCRIPT"

SUDO_ARGS_FILE="${fixture}/sudo-args"
export SUDO_ARGS_FILE
ensure_brew_prefix_ownership "${fixture}/prefix" brewer

args=$(tr '\n' ' ' < "${fixture}/sudo-args")
assert_contains "$args" "-n chown -R brewer:brewgroup ${fixture}/prefix"

printf 'runtime ownership unit tests passed\n'
