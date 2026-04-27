#!/usr/bin/env bash
#
# install-k8s.sh - Install a single-node Kubernetes cluster on Ubuntu 24.04
#                  using kubeadm + containerd + Flannel.
#
# Usage:  sudo bash install-k8s.sh
#
# Tested on Ubuntu 24.04 LTS (Noble Numbat), x86_64 / arm64.
# See GUIDE.md for plain-language explanations of every step.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
K8S_VERSION="v1.32"
POD_CIDR="10.244.0.0/16"
FLANNEL_MANIFEST="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

run_as_user() {
    # Run a command as the invoking (non-root) user so that files end up
    # owned by them, e.g. ~/.kube/config.
    local target_user="$1"; shift
    sudo -u "$target_user" -H bash -c "$*"
}

# ---------------------------------------------------------------------------
# 1. Preflight checks
# ---------------------------------------------------------------------------
preflight() {
    log "Step 1/9: Preflight checks"

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

    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    case "$arch" in
        amd64|arm64|x86_64|aarch64) : ;;
        *) die "Unsupported architecture: $arch (need amd64 or arm64)" ;;
    esac

    INVOKING_USER="${SUDO_USER:-root}"
    if [[ "$INVOKING_USER" != "root" ]] && ! id -u "$INVOKING_USER" >/dev/null 2>&1; then
        warn "SUDO_USER='$INVOKING_USER' does not exist; falling back to root for kubeconfig."
        INVOKING_USER="root"
    fi
    log "Invoking user for kubeconfig: $INVOKING_USER"
}

# ---------------------------------------------------------------------------
# 2. System prep (packages, swap, kernel modules, sysctl)
# ---------------------------------------------------------------------------
system_prep() {
    log "Step 2/9: System prep (apt, swap, kernel modules, sysctl)"

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gpg \
        software-properties-common

    # --- Disable swap (required by kubelet) ---
    if [[ "$(swapon --show=NAME --noheadings | wc -l)" -gt 0 ]]; then
        log "Disabling active swap"
        swapoff -a
    fi
    # Comment out swap entries so they don't come back after reboot.
    if grep -E '^[^#].*\sswap\s' /etc/fstab >/dev/null 2>&1; then
        log "Commenting swap entries in /etc/fstab"
        sed -i.bak -E 's|^([^#].*\sswap\s.*)$|# \1|' /etc/fstab
    fi
    # Ubuntu 24.04 cloud images often ship with /swap.img.
    if [[ -f /swap.img ]]; then
        log "Removing /swap.img"
        rm -f /swap.img
    fi

    # --- Kernel modules ---
    log "Loading kernel modules: overlay, br_netfilter"
    modprobe overlay
    modprobe br_netfilter
    cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

    # --- sysctl ---
    log "Applying sysctl settings for Kubernetes networking"
    cat >/etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sysctl --system >/dev/null
}

# ---------------------------------------------------------------------------
# 3. Install + configure containerd (from Docker's apt repo)
# ---------------------------------------------------------------------------
install_containerd() {
    log "Step 3/9: Install and configure containerd"

    install -d -m 0755 /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        log "Adding Docker apt GPG key"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    local codename="${VERSION_CODENAME:-noble}"
    local arch
    arch="$(dpkg --print-architecture)"

    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y containerd.io

    log "Writing default containerd config and enabling SystemdCgroup"
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    systemctl restart containerd
    systemctl enable containerd >/dev/null
}

# ---------------------------------------------------------------------------
# 4. Install kubeadm / kubelet / kubectl from pkgs.k8s.io
# ---------------------------------------------------------------------------
install_kube_packages() {
    log "Step 4/9: Install kubeadm, kubelet, kubectl (${K8S_VERSION})"

    install -d -m 0755 /etc/apt/keyrings

    # Re-fetch every time so a re-run picks up rotated keys.
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
        | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
        > /etc/apt/sources.list.d/kubernetes.list

    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl >/dev/null

    systemctl enable --now kubelet >/dev/null
}

# ---------------------------------------------------------------------------
# 5. Bootstrap the control plane with kubeadm init
# ---------------------------------------------------------------------------
kubeadm_init() {
    log "Step 5/9: kubeadm init"

    if [[ -f /etc/kubernetes/admin.conf ]]; then
        warn "/etc/kubernetes/admin.conf already exists; skipping kubeadm init."
        warn "If you want a fresh cluster, run: sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d ~/.kube"
        return 0
    fi

    log "Pre-pulling control-plane images"
    kubeadm config images pull

    log "Initialising the cluster (this can take a few minutes)"
    kubeadm init --pod-network-cidr="${POD_CIDR}"
}

# ---------------------------------------------------------------------------
# 6. Set up kubeconfig for root and the invoking user
# ---------------------------------------------------------------------------
setup_kubeconfig() {
    log "Step 6/9: Set up kubeconfig"

    if [[ ! -f /etc/kubernetes/admin.conf ]]; then
        die "/etc/kubernetes/admin.conf is missing - kubeadm init must have failed."
    fi

    # Root
    install -d -m 0700 /root/.kube
    install -m 0600 /etc/kubernetes/admin.conf /root/.kube/config

    # Invoking user (if not root)
    if [[ "$INVOKING_USER" != "root" ]]; then
        local user_home
        user_home="$(getent passwd "$INVOKING_USER" | cut -d: -f6)"
        if [[ -z "$user_home" || ! -d "$user_home" ]]; then
            warn "Could not find home for $INVOKING_USER; skipping user kubeconfig."
            return 0
        fi
        install -d -m 0700 -o "$INVOKING_USER" -g "$INVOKING_USER" "$user_home/.kube"
        install -m 0600 -o "$INVOKING_USER" -g "$INVOKING_USER" \
            /etc/kubernetes/admin.conf "$user_home/.kube/config"
        log "kubeconfig installed at $user_home/.kube/config"
    fi
}

# ---------------------------------------------------------------------------
# 7. Install the Flannel CNI plugin
# ---------------------------------------------------------------------------
install_cni() {
    log "Step 7/9: Install Flannel CNI"

    local kubectl_cmd=(kubectl --kubeconfig /etc/kubernetes/admin.conf)

    if "${kubectl_cmd[@]}" get ns kube-flannel >/dev/null 2>&1; then
        warn "Namespace 'kube-flannel' already exists; re-applying manifest to ensure it's up to date."
    fi

    "${kubectl_cmd[@]}" apply -f "$FLANNEL_MANIFEST"
}

# ---------------------------------------------------------------------------
# 8. Single-node tweak: untaint the control-plane node so pods can schedule
# ---------------------------------------------------------------------------
untaint_node() {
    log "Step 8/9: Removing control-plane taint (single-node cluster)"

    kubectl --kubeconfig /etc/kubernetes/admin.conf \
        taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null \
        || warn "Taint already removed or no matching taint found."
}

# ---------------------------------------------------------------------------
# 9. Verify: wait for the node to become Ready and print status
# ---------------------------------------------------------------------------
verify() {
    log "Step 9/9: Waiting for the node to become Ready"

    local kubectl_cmd=(kubectl --kubeconfig /etc/kubernetes/admin.conf)
    local deadline=$(( $(date +%s) + 180 ))

    while (( $(date +%s) < deadline )); do
        if "${kubectl_cmd[@]}" get nodes --no-headers 2>/dev/null \
            | awk '{print $2}' | grep -qx 'Ready'; then
            log "Node is Ready."
            break
        fi
        sleep 5
    done

    if ! "${kubectl_cmd[@]}" get nodes --no-headers 2>/dev/null \
        | awk '{print $2}' | grep -qx 'Ready'; then
        warn "Node did not reach Ready within 3 minutes. Check 'kubectl get pods -A' below."
    fi

    echo
    log "Nodes:"
    "${kubectl_cmd[@]}" get nodes -o wide || true
    echo
    log "Pods (all namespaces):"
    "${kubectl_cmd[@]}" get pods -A || true
    echo

    cat <<EOF

==========================================================================
  Single-node Kubernetes ${K8S_VERSION} cluster is ready.

  Try it out as ${INVOKING_USER}:
      kubectl get nodes
      kubectl run hello --image=nginx --port=80
      kubectl get pods

  kubeconfig locations:
      /root/.kube/config
$( [[ "$INVOKING_USER" != "root" ]] && echo "      $(getent passwd "$INVOKING_USER" | cut -d: -f6)/.kube/config" )

  See GUIDE.md for what each step does and why.
==========================================================================
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    preflight
    system_prep
    install_containerd
    install_kube_packages
    kubeadm_init
    setup_kubeconfig
    install_cni
    untaint_node
    verify
}

main "$@"
