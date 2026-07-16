#!/bin/sh
set -eu

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
HOMEBREW_INSTALLER_REVISION="184a7bce1569b711ecb5451f5e9a3d30cb444242"
HOMEBREW_INSTALLER_SHA256="99287f194a8b3c9e6b0203a11a5fa54518be57209343e6bb954dec4635796d9d"
FEATURE_STATE_DIR="/usr/local/share/devcontainer-features/homebrew"
FEATURE_CONFIG="${FEATURE_STATE_DIR}/config"

log() {
    printf 'homebrew feature: %s\n' "$*"
}

error() {
    printf 'homebrew feature: ERROR: %s\n' "$*" >&2
}

normalize_boolean() {
    value=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$value" in
        true|1|yes) printf 'true\n' ;;
        false|0|no) printf 'false\n' ;;
        *)
            error "invalid boolean value '$1'"
            return 1
            ;;
    esac
}

validate_platform() {
    os_release_file=${OS_RELEASE_FILE:-/etc/os-release}
    if [ "$(uname -s)" != "Linux" ]; then
        error "only Linux containers are supported"
        return 1
    fi
    if [ ! -r "$os_release_file" ]; then
        error "cannot read ${os_release_file}"
        return 1
    fi

    ID=
    ID_LIKE=
    # /etc/os-release is the standard OS-provided metadata file.
    # shellcheck disable=SC1090
    . "$os_release_file"

    if [ "${ID:-}" = "alpine" ]; then
        error "Alpine Linux is unsupported because Homebrew requires glibc, not musl"
        return 1
    fi
    case " ${ID:-} ${ID_LIKE:-} " in
        *" debian "*|*" ubuntu "*) ;;
        *)
            error "unsupported Linux distribution '${ID:-unknown}'; use Debian or Ubuntu"
            return 1
            ;;
    esac

    if ! getconf GNU_LIBC_VERSION 2>/dev/null | grep -q '^glibc '; then
        error "Homebrew requires glibc; musl and other C libraries are unsupported"
        return 1
    fi

    case "$(uname -m)" in
        x86_64|amd64|aarch64|arm64) ;;
        *)
            error "unsupported architecture '$(uname -m)'; use amd64 or arm64"
            return 1
            ;;
    esac
}

resolve_brew_user() {
    for candidate in "${_REMOTE_USER:-}" "${_CONTAINER_USER:-}"; do
        case "$candidate" in
            ""|root|auto|automatic|none) continue ;;
        esac
        if id "$candidate" >/dev/null 2>&1; then
            candidate_uid=$(id -u "$candidate")
            [ "$candidate_uid" -ne 0 ] || continue
            id -un "$candidate_uid"
            return 0
        fi
    done

    printf 'linuxbrew\n'
}

ensure_brew_user() {
    brew_user=$1
    if id "$brew_user" >/dev/null 2>&1; then
        [ "$(id -u "$brew_user")" -ne 0 ] || {
            error "Homebrew cannot be installed or run as root"
            return 1
        }
        return 0
    fi

    [ "$brew_user" = "linuxbrew" ] || {
        error "user '$brew_user' does not exist"
        return 1
    }
    log "creating non-root fallback user 'linuxbrew'"
    useradd --create-home --shell /bin/bash linuxbrew
}

user_home() {
    getent passwd "$1" | cut -d: -f6
}

run_as_brew_user() {
    runuser -u "$BREW_USER" -- env \
        HOME="$BREW_HOME" \
        USER="$BREW_USER" \
        LOGNAME="$BREW_USER" \
        PATH="${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        HOMEBREW_NO_ANALYTICS=1 \
        "$@"
}

install_prerequisites() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get -o Acquire::Retries=3 update
    apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        file \
        git \
        procps \
        util-linux
    rm -rf /var/lib/apt/lists/*
}

prepare_prefix() {
    mkdir -p "$HOMEBREW_PREFIX"
    existing_owner=$(stat -c '%U' "$HOMEBREW_PREFIX")
    if [ "$existing_owner" != "$BREW_USER" ]; then
        if [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then
            error "${HOMEBREW_PREFIX} is owned by '${existing_owner}', not '${BREW_USER}'"
            return 1
        fi
        chown -R "${BREW_USER}:$(id -gn "$BREW_USER")" /home/linuxbrew
    fi
}

install_homebrew() {
    brew_bin="${HOMEBREW_PREFIX}/bin/brew"
    if [ -x "$brew_bin" ]; then
        log "Homebrew is already installed"
        return 0
    fi

    installer=$(mktemp)
    trap 'rm -f "$installer"' EXIT HUP INT TERM
    installer_url="https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALLER_REVISION}/install.sh"
    log "downloading Homebrew installer at ${HOMEBREW_INSTALLER_REVISION}"
    curl --fail --silent --show-error --location "$installer_url" --output "$installer"
    printf '%s  %s\n' "$HOMEBREW_INSTALLER_SHA256" "$installer" | sha256sum --check --status || {
        error "Homebrew installer checksum verification failed"
        return 1
    }
    chmod 0644 "$installer"

    run_as_brew_user env NONINTERACTIVE=1 CI=1 /bin/bash "$installer"
    rm -f "$installer"
    trap - EXIT HUP INT TERM

    [ -x "$brew_bin" ] || {
        error "Homebrew installation did not create ${brew_bin}"
        return 1
    }
}

ensure_brew_prefix_ownership() {
    chown -R "${BREW_USER}:$(id -gn "$BREW_USER")" "$HOMEBREW_PREFIX"
}

persist_feature_state() {
    install_brewfile=$1
    no_upgrade=$2
    script_dir=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)

    install -d -m 0755 "$FEATURE_STATE_DIR"
    install -m 0755 "${script_dir}/run-bundle.sh" "${FEATURE_STATE_DIR}/run-bundle.sh"
    install -m 0755 "${script_dir}/runtime-ownership.sh" "${FEATURE_STATE_DIR}/runtime-ownership.sh"
    cat > "$FEATURE_CONFIG" <<EOF
INSTALL_BREWFILE=${install_brewfile}
NO_UPGRADE=${no_upgrade}
BREW_USER=${BREW_USER}
BREW_HOME=${BREW_HOME}
EOF
    chmod 0644 "$FEATURE_CONFIG"
}

main() {
    [ "$(id -u)" -eq 0 ] || {
        error "Feature installation must run as root"
        exit 1
    }

    validate_platform
    install_brewfile=$(normalize_boolean "${INSTALLBREWFILE:-false}")
    no_upgrade=$(normalize_boolean "${NOUPGRADE:-true}")

    install_prerequisites

    BREW_USER=$(resolve_brew_user)
    export BREW_USER
    ensure_brew_user "$BREW_USER"
    BREW_HOME=$(user_home "$BREW_USER")
    export BREW_HOME
    [ -n "$BREW_HOME" ] || {
        error "could not determine the home directory for '${BREW_USER}'"
        exit 1
    }

    prepare_prefix
    install_homebrew
    ensure_brew_prefix_ownership
    persist_feature_state "$install_brewfile" "$no_upgrade"

    run_as_brew_user "${HOMEBREW_PREFIX}/bin/brew" --version
    log "installation complete for user '${BREW_USER}'"
}

if [ "${HOMEBREW_FEATURE_SOURCE_ONLY:-0}" != "1" ]; then
    main "$@"
fi
