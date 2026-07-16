#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
SCRIPT="${REPO_ROOT}/src/homebrew/run-bundle.sh"
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

make_fixture() {
    name=$1
    fixture="${TMPDIR_ROOT}/${name}"
    mkdir -p "${fixture}/workspace" "${fixture}/bin"
    printf '%s\n' "$fixture"
}

write_config() {
    fixture=$1
    enabled=$2
    no_upgrade=$3
    cat > "${fixture}/config" <<EOF
INSTALL_BREWFILE=${enabled}
NO_UPGRADE=${no_upgrade}
BREW_USER=$(id -un)
BREW_HOME=${HOME}
EOF
}

write_fake_brew() {
    fixture=$1
    cat > "${fixture}/bin/brew" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "${BREW_TEST_ARGS_FILE}"
EOF
    chmod +x "${fixture}/bin/brew"
}

run_helper() {
    fixture=$1
    shift
    (
        cd "${fixture}/workspace"
        HOMEBREW_FEATURE_CONFIG="${fixture}/config" \
        HOMEBREW_PREFIX="${fixture}" \
        HOMEBREW_BREW_BIN="${fixture}/bin/brew" \
        HOMEBREW_RUNTIME_OWNERSHIP_SCRIPT="${REPO_ROOT}/src/homebrew/runtime-ownership.sh" \
        BREW_TEST_ARGS_FILE="${fixture}/args" \
        sh "$SCRIPT" "$@"
    )
}

test_disabled_is_noop() {
    fixture=$(make_fixture disabled)
    write_config "$fixture" false true
    write_fake_brew "$fixture"

    run_helper "$fixture"

    [ ! -e "${fixture}/args" ] || fail "disabled helper invoked brew"
}

test_enabled_requires_brewfile() {
    fixture=$(make_fixture missing)
    write_config "$fixture" true true
    write_fake_brew "$fixture"

    if output=$(run_helper "$fixture" 2>&1); then
        fail "enabled helper succeeded without a Brewfile"
    fi
    assert_contains "$output" "Brewfile"
    assert_contains "$output" "not found"
}

test_enabled_uses_workspace_brewfile_and_no_upgrade() {
    fixture=$(make_fixture no-upgrade)
    write_config "$fixture" true true
    write_fake_brew "$fixture"
    printf 'brew "hello"\n' > "${fixture}/workspace/Brewfile"

    run_helper "$fixture"

    args=$(tr '\n' ' ' < "${fixture}/args")
    assert_contains "$args" "bundle install"
    assert_contains "$args" "--file=${fixture}/workspace/Brewfile"
    assert_contains "$args" "--no-upgrade"
}

test_upgrade_mode_omits_no_upgrade() {
    fixture=$(make_fixture upgrade)
    write_config "$fixture" true false
    write_fake_brew "$fixture"
    printf 'brew "hello"\n' > "${fixture}/workspace/Brewfile"

    run_helper "$fixture"

    args=$(tr '\n' ' ' < "${fixture}/args")
    assert_contains "$args" "bundle install"
    case "$args" in
        *"--no-upgrade"*) fail "upgrade mode passed --no-upgrade" ;;
    esac
}

test_config_values_are_not_executed() {
    fixture=$(make_fixture config-data)
    marker="${fixture}/config-was-executed"
    cat > "${fixture}/config" <<EOF
INSTALL_BREWFILE=false
NO_UPGRADE=true
BREW_USER=$(id -un)
BREW_HOME=\$(touch "${marker}")
EOF
    write_fake_brew "$fixture"

    run_helper "$fixture"

    [ ! -e "$marker" ] || fail "Feature configuration was evaluated as shell code"
}

test_administrative_commands_ignore_homebrew_path() {
    fixture=$(make_fixture trusted-path)
    marker="${fixture}/owner-command-ran"
    write_config "$fixture" true true
    write_fake_brew "$fixture"
    printf 'brew "hello"\n' > "${fixture}/workspace/Brewfile"
    printf '#!/bin/sh\ntouch "%s"\nexec /usr/bin/id "$@"\n' "$marker" > "${fixture}/bin/id"
    chmod +x "${fixture}/bin/id"

    PATH="${fixture}/bin:${PATH}" run_helper "$fixture"

    [ ! -e "$marker" ] || fail "helper resolved an administrative command through the Homebrew-owned PATH"
}

test_disabled_is_noop
test_enabled_requires_brewfile
test_enabled_uses_workspace_brewfile_and_no_upgrade
test_upgrade_mode_omits_no_upgrade
test_config_values_are_not_executed
test_administrative_commands_ignore_homebrew_path
printf 'run-bundle unit tests passed\n'
