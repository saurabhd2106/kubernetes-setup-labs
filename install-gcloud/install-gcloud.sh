#!/usr/bin/env bash
#
# install-gcloud.sh - Install the Google Cloud CLI (gcloud) for local use with Terraform / gcloud.
#
# Usage:  cd install-gcloud && bash install-gcloud.sh
#     or: bash install-gcloud/install-gcloud.sh   (from repo root)
#
# macOS: uses Homebrew when available; otherwise Google's official curl installer.
# Linux: uses Google's official curl installer (user install under $HOME/google-cloud-sdk).
#
# Does not require root for the curl installer path. Homebrew may prompt for your password.
#
# See GUIDE.md in this directory for a plain-language walkthrough.

set -euo pipefail

readonly GCLOUD_HOME="${HOME}/google-cloud-sdk"

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

  if [[ "${BASH_VERSINFO[0]:-0}" -lt 3 ]]; then
    die "This script requires bash 3 or newer."
  fi

  if ! command -v curl >/dev/null 2>&1; then
    die "curl is required but not found. Install curl and re-run."
  fi

  if command -v gcloud >/dev/null 2>&1; then
    log "gcloud is already on PATH:"
    gcloud --version | head -5
    log "Nothing to install. To upgrade: gcloud components update"
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Install (macOS + Homebrew)
# ---------------------------------------------------------------------------
install_macos_brew() {
  log "Installing Google Cloud SDK via Homebrew (google-cloud-sdk cask)"
  brew install --cask google-cloud-sdk
}

# ---------------------------------------------------------------------------
# Install (official curl installer — macOS without brew, Linux, etc.)
# ---------------------------------------------------------------------------
install_via_google_installer() {
  log "Installing Google Cloud SDK via official installer (install dir: ${GCLOUD_HOME})"

  export CLOUDSDK_CORE_DISABLE_PROMPTS=1
  export CLOUDSDK_INSTALL_DIR="${GCLOUD_HOME}"

  # Pipe official script; --disable-prompts keeps the run non-interactive.
  if ! curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts; then
    die "Google Cloud SDK installer failed. See https://cloud.google.com/sdk/docs/install"
  fi

  if [[ -d "${GCLOUD_HOME}/bin" ]]; then
    export PATH="${GCLOUD_HOME}/bin:${PATH}"
  fi

  if [[ -f "${GCLOUD_HOME}/path.bash.inc" ]]; then
    # shellcheck disable=SC1091
    source "${GCLOUD_HOME}/path.bash.inc"
  fi
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify() {
  log "Verifying installation"

  if ! command -v gcloud >/dev/null 2>&1; then
    die "gcloud not found on PATH after install. Add this to your shell profile and open a new terminal:\n  source \"${GCLOUD_HOME}/path.bash.inc\"   # bash\n  source \"${GCLOUD_HOME}/path.zsh.inc\"   # zsh (if present)"
  fi

  gcloud --version | head -5
  log "gcloud is installed."
  warn "If 'gcloud' is not found in a new terminal, add the SDK to your PATH (see GUIDE.md)."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  preflight

  local os
  os="$(uname -s)"

  case "${os}" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        install_macos_brew
      else
        warn "Homebrew not found; using Google's curl installer instead."
        warn "Consider installing Homebrew from https://brew.sh for easier updates."
        install_via_google_installer
      fi
      ;;
    Linux)
      install_via_google_installer
      ;;
    *)
      warn "Unsupported OS: ${os}. Trying Google's curl installer anyway."
      install_via_google_installer
      ;;
  esac

  verify
}

main "$@"
