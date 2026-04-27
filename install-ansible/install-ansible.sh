#!/usr/bin/env bash
#
# install-ansible.sh - Install Ansible on Ubuntu using apt (ansible meta-package).
#
# Usage:  cd install-ansible && sudo bash install-ansible.sh
#     or: sudo bash install-ansible/install-ansible.sh   (from repo root)
#
# Tested on Ubuntu 24.04 LTS (Noble Numbat). Other Ubuntu releases should work;
# the ansible package lives in the Universe component—enable it if apt cannot
# find the package: sudo add-apt-repository universe && sudo apt-get update
#
# See GUIDE.md in this directory for a plain-language walkthrough.

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
preflight() {
    log "Preflight checks"

    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root. Try: sudo bash $0"
    fi

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" != "ubuntu" ]]; then
            warn "Detected OS '${ID:-unknown}', this script is designed for Ubuntu."
        elif [[ "${VERSION_ID:-}" != "24.04" ]]; then
            warn "Detected Ubuntu ${VERSION_ID:-unknown}; this script targets 24.04. Continuing anyway."
        fi
    else
        warn "/etc/os-release not found; cannot verify Ubuntu version."
    fi
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
install_ansible() {
    log "Installing Ansible via apt"

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y

    if ! apt-get install -y ansible; then
        die "apt install failed. If 'ansible' was not found, enable Universe: sudo add-apt-repository universe && sudo apt-get update, then re-run this script."
    fi
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify() {
    log "Verifying installation"
    ansible --version
    log "Ansible is installed."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    preflight
    install_ansible
    verify
}

main "$@"
