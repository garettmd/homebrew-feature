#!/bin/sh

ensure_brew_prefix_ownership() {
    homebrew_prefix=$1
    brew_user=$2

    expected_uid=$(id -u "$brew_user") || return 1
    actual_uid=$(stat -c '%u' "$homebrew_prefix") || return 1
    [ "$actual_uid" = "$expected_uid" ] && return 0

    brew_group=$(id -gn "$brew_user") || return 1
    if [ "$(id -u)" -eq 0 ]; then
        chown -R "${brew_user}:${brew_group}" "$homebrew_prefix"
        return
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -n true; then
        sudo -n chown -R "${brew_user}:${brew_group}" "$homebrew_prefix"
        return
    fi

    printf 'homebrew feature: ERROR: Homebrew prefix ownership must be repaired after the remote user UID changes; passwordless sudo is required\n' >&2
    return 1
}
