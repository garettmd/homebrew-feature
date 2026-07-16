#!/bin/sh
set -eu

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

CONFIG_FILE=${HOMEBREW_FEATURE_CONFIG:-/usr/local/share/devcontainer-features/homebrew/config}
HOMEBREW_PREFIX=${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}
BREW_BIN=${HOMEBREW_BREW_BIN:-"${HOMEBREW_PREFIX}/bin/brew"}
RUNTIME_OWNERSHIP_SCRIPT=${HOMEBREW_RUNTIME_OWNERSHIP_SCRIPT:-/usr/local/share/devcontainer-features/homebrew/runtime-ownership.sh}

error() {
    printf 'homebrew feature: ERROR: %s\n' "$*" >&2
}

[ -r "$CONFIG_FILE" ] || {
    error "Feature configuration not found at ${CONFIG_FILE}"
    exit 1
}

INSTALL_BREWFILE=
NO_UPGRADE=
BREW_USER=
BREW_HOME=
while IFS= read -r config_line || [ -n "$config_line" ]; do
    config_key=${config_line%%=*}
    config_value=${config_line#*=}
    [ "$config_key" != "$config_line" ] || {
        error "malformed Feature configuration"
        exit 1
    }
    case "$config_key" in
        INSTALL_BREWFILE) INSTALL_BREWFILE=$config_value ;;
        NO_UPGRADE) NO_UPGRADE=$config_value ;;
        BREW_USER) BREW_USER=$config_value ;;
        BREW_HOME) BREW_HOME=$config_value ;;
        *)
            error "unknown Feature configuration key '${config_key}'"
            exit 1
            ;;
    esac
done < "$CONFIG_FILE"

case "${INSTALL_BREWFILE:-}" in
    false) exit 0 ;;
    true) ;;
    *)
        error "invalid INSTALL_BREWFILE state"
        exit 1
        ;;
esac

case "${NO_UPGRADE:-}" in
    true|false) ;;
    *)
        error "invalid NO_UPGRADE state"
        exit 1
        ;;
esac

if [ -z "${BREW_USER:-}" ] || ! id "$BREW_USER" >/dev/null 2>&1; then
    error "configured Homebrew user '${BREW_USER:-}' does not exist"
    exit 1
fi
[ -n "${BREW_HOME:-}" ] || {
    error "configured Homebrew home directory is empty"
    exit 1
}
[ -x "$BREW_BIN" ] || {
    error "Homebrew executable not found at ${BREW_BIN}"
    exit 1
}

BREWFILE="${PWD}/Brewfile"
[ -f "$BREWFILE" ] || {
    error "Brewfile not found at ${BREWFILE}"
    exit 1
}

run_as_brew_user() {
    current_user=$(id -un)
    if [ "$current_user" = "$BREW_USER" ]; then
        env \
            HOME="$BREW_HOME" \
            USER="$BREW_USER" \
            LOGNAME="$BREW_USER" \
            PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
            HOMEBREW_NO_ANALYTICS=1 \
            "$@"
    elif [ "$(id -u)" -eq 0 ]; then
        runuser -u "$BREW_USER" -- env \
            HOME="$BREW_HOME" \
            USER="$BREW_USER" \
            LOGNAME="$BREW_USER" \
            PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
            HOMEBREW_NO_ANALYTICS=1 \
            "$@"
    else
        error "current user '${current_user}' cannot run Homebrew owned by '${BREW_USER}'"
        return 1
    fi
}

if ! run_as_brew_user test -r "$BREWFILE"; then
    error "Brewfile is not readable by '${BREW_USER}': ${BREWFILE}"
    exit 1
fi

[ -r "$RUNTIME_OWNERSHIP_SCRIPT" ] || {
    error "runtime ownership helper not found at ${RUNTIME_OWNERSHIP_SCRIPT}"
    exit 1
}
# shellcheck source=/dev/null
. "$RUNTIME_OWNERSHIP_SCRIPT"
ensure_brew_prefix_ownership "$HOMEBREW_PREFIX" "$BREW_USER"

set -- bundle install "--file=${BREWFILE}"
if [ "$NO_UPGRADE" = "true" ]; then
    set -- "$@" --no-upgrade
fi

printf 'homebrew feature: applying %s as %s\n' "$BREWFILE" "$BREW_USER"
run_as_brew_user "$BREW_BIN" "$@"
