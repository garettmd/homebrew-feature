#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
INSTALL_SCRIPT="${REPO_ROOT}/src/homebrew/install.sh"
TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_equal() {
    actual=$1
    expected=$2
    [ "$actual" = "$expected" ] || fail "expected '$expected', got '$actual'"
}

assert_contains() {
    haystack=$1
    needle=$2
    case "$haystack" in
        *"$needle"*) ;;
        *) fail "expected '$haystack' to contain '$needle'" ;;
    esac
}

HOMEBREW_FEATURE_SOURCE_ONLY=1
export HOMEBREW_FEATURE_SOURCE_ONLY
# shellcheck source=/dev/null
. "$INSTALL_SCRIPT"

assert_equal "$(normalize_boolean TRUE)" true
assert_equal "$(normalize_boolean false)" false
if normalize_boolean sometimes >/dev/null 2>&1; then
    fail "normalize_boolean accepted an invalid value"
fi

current_user=$(id -un)
_REMOTE_USER=$current_user
_CONTAINER_USER=root
export _REMOTE_USER _CONTAINER_USER
assert_equal "$(resolve_brew_user)" "$current_user"

_REMOTE_USER=root
_CONTAINER_USER=root
export _REMOTE_USER _CONTAINER_USER
assert_equal "$(resolve_brew_user)" linuxbrew

current_uid=$(id -u)
_REMOTE_USER=$current_uid
_CONTAINER_USER=root
export _REMOTE_USER _CONTAINER_USER
assert_equal "$(resolve_brew_user)" "$current_user"

_REMOTE_USER=0
_CONTAINER_USER=root
export _REMOTE_USER _CONTAINER_USER
assert_equal "$(resolve_brew_user)" linuxbrew

cat > "${TMPDIR_ROOT}/ubuntu-release" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF
OS_RELEASE_FILE="${TMPDIR_ROOT}/ubuntu-release"
export OS_RELEASE_FILE
validate_platform

cat > "${TMPDIR_ROOT}/alpine-release" <<'EOF'
ID=alpine
ID_LIKE=
EOF
OS_RELEASE_FILE="${TMPDIR_ROOT}/alpine-release"
export OS_RELEASE_FILE
if output=$(validate_platform 2>&1); then
    fail "validate_platform accepted Alpine"
fi
case "$output" in
    *"Alpine"*"musl"*) ;;
    *) fail "Alpine error did not explain the musl incompatibility: $output" ;;
esac

test_install_prerequisites_configures_apt_retries() {
    fixture="${TMPDIR_ROOT}/apt-retries"
    mkdir -p "${fixture}/bin"
    cat > "${fixture}/bin/apt-get" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >> "${APT_ARGS_FILE}"
EOF
    cat > "${fixture}/bin/rm" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "${fixture}/bin/apt-get" "${fixture}/bin/rm"

    PATH="${fixture}/bin:${PATH}" APT_ARGS_FILE="${fixture}/args" install_prerequisites

    args=$(tr '\n' ' ' < "${fixture}/args")
    assert_contains "$args" "Acquire::Retries=3"
}

test_restore_prefix_ownership_recursively() {
    fixture="${TMPDIR_ROOT}/prefix-ownership"
    mkdir -p "${fixture}/bin" "${fixture}/prefix"
    cat > "${fixture}/bin/chown" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "${CHOWN_ARGS_FILE}"
EOF
    chmod +x "${fixture}/bin/chown"

    HOMEBREW_PREFIX="${fixture}/prefix" \
        BREW_USER="$(id -un)" \
        PATH="${fixture}/bin:${PATH}" \
        CHOWN_ARGS_FILE="${fixture}/args" \
        ensure_brew_prefix_ownership

    args=$(tr '\n' ' ' < "${fixture}/args")
    assert_contains "$args" "-R"
    assert_contains "$args" "${fixture}/prefix"
}

test_install_prerequisites_configures_apt_retries
test_restore_prefix_ownership_recursively

printf 'install function unit tests passed\n'
