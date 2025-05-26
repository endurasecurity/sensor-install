#!/usr/bin/env sh
#
# Intended to be installed via the following command:
# curl -sSf https://endurasecurity.github.io/sensor-install/testing.sh | sudo -E sh

set -eu

CHANNEL=testing
PKG_NAME="endura-sensor"
MISSING_CMDS=""

ASC_URL="https://endurasecurity.github.io/${CHANNEL}/${PKG_NAME}/endura.asc"
DEB_URL="https://endurasecurity.github.io/${CHANNEL}/${PKG_NAME}/deb"
RPM_URL="https://endurasecurity.github.io/${CHANNEL}/${PKG_NAME}/rpm"
TGZ_URL="https://endurasecurity.github.io/${CHANNEL}/${PKG_NAME}/tgz/${PKG_NAME}-latest.tgz"

BOLD="\033[1m"
RESET="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
WHITE="\033[1;37m"
YELLOW="\033[1;33m"

main() {
    if ! has_admin_privileges; then
        fail "must be run as root or have cap_sys_admin capability"
    fi

    if [ "${ENDURA_USE_DEB:-false}" = "true" ]; then
        install_deb_package
    elif [ "${ENDURA_USE_RPM:-false}" = "true" ]; then
        install_rpm_package
    elif [ "${ENDURA_USE_TGZ:-false}" = "true" ]; then
        install_tgz_package
    elif is_deb_distro; then
        install_deb_package
    elif is_rhel_distro; then
        install_rhel_package
    else
        install_tgz_package
    fi

    return 0
}

has_admin_privileges() {
    [ "$(id -u)" -eq 0 ] && return 0
    
    if command -v capsh >/dev/null 2>&1; then
        if capsh --print 2>/dev/null | grep -q 'Current:.*cap_sys_admin'; then
            return 0
        fi
    fi
    
    return 1
}

install_deb_package() {
    info "installing deb dependencies"
    apt-get update
    apt-get install -y coreutils curl gnupg

    info "installing deb repository: ${DEB_URL}"
    echo "deb [signed-by=/usr/share/keyrings/endura-keyring.gpg] ${DEB_URL} /" | tee /etc/apt/sources.list.d/${PKG_NAME}.list
    curl -sL "${ASC_URL}" | gpg --dearmor --batch --yes -o /usr/share/keyrings/endura-keyring.gpg

    info "installing ${PKG_NAME} package"
    apt-get update
    apt-get install -y ${PKG_NAME}

    info "successfully installed endura $(endura version)"
}

install_rhel_package() {
    info "installing rhel dependencies"
    dnf makecache
    dnf install -y coreutils curl gnupg

    info "installing rhel repository: ${RPM_URL}"
    cat <<EOF | tee /etc/yum.repos.d/${PKG_NAME}.repo
[endura-sensor]
name=Endura Security - Sensor
baseurl=${RPM_URL}
enabled=1
gpgcheck=1
gpgkey=${ASC_URL}
EOF

    info "installing ${PKG_NAME} package"
    dnf makecache
    dnf install -y ${PKG_NAME}

    info "successfully installed endura $(endura version)"
}

install_tgz_package() {
    needs_cmd cat
    needs_cmd curl
    needs_cmd gpg
    needs_cmd grep
    needs_cmd printf
    needs_cmd rm
    needs_cmd tar
    needs_cmd tee

    if [ -n "$MISSING_CMDS" ]; then
        fail "please install the following missing command(s) and try again: $MISSING_CMDS"
    fi

    info "downloading tgz package: ${TGZ_URL}"
    curl -sL "$TGZ_URL" -o /tmp/${PKG_NAME}.tgz
    curl -sL "$TGZ_URL.sig" -o /tmp/${PKG_NAME}.tgz.sig

    if ! curl -fsSL "$ASC_URL" | gpg --import; then
        fail "failed to import GPG public key from $ASC_URL"
    fi

    if ! gpg --verify /tmp/${PKG_NAME}.tgz.sig /tmp/${PKG_NAME}.tgz; then
        fail "tgz package signature verification failed"
    fi

    info "installing tgz package"
    tar -C / -xzf /tmp/${PKG_NAME}.tgz
    rm -f /tmp/${PKG_NAME}.tgz /tmp/${PKG_NAME}.tgz.sig

    info "successfully installed endura $(endura version)"
}

is_deb_distro() {
    grep -qiE "debian|ubuntu" /etc/os-release 2>/dev/null
}

is_rhel_distro() {
    grep -qiE "almalinux|amazon linux|centos|fedora|oracle|rocky" /etc/os-release 2>/dev/null
}

info() {
    printf "${GREEN}[info]${RESET} ${BOLD}${WHITE}[endura]${RESET} %s\n" "$1" >&2
}

warn() {
    printf "${YELLOW}[warn]${RESET} ${BOLD}${WHITE}[endura]${RESET} %s\n" "$1" >&2
}

fail() {
    printf "${RED}[fatal]${RESET} ${BOLD}${WHITE}[endura]${RESET} %s\n" "$1" >&2
    exit 1
}

needs_cmd() {
    if ! check_cmd "$1"; then
        warn "needs '$1' (command not found)"
        MISSING_CMDS="$1 $MISSING_CMDS"
    fi
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

assert_nz() {
    if [ -z "$1" ]; then fail "assert_nz $2"; fi
}

ensure() {
    if ! "$@"; then fail "command failed: $*"; fi
}

ignore() {
    "$@"
}

main "$@" || exit 1
