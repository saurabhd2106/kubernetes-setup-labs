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
# Official installer often uses $HOME/google-cloud-sdk as the *parent* dir and
# extracts the SDK into $HOME/google-cloud-sdk/google-cloud-sdk/ (nested).
readonly GCLOUD_SDK_NESTED="${GCLOUD_HOME}/google-cloud-sdk"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# Add gcloud to PATH for this shell (flat or nested install layout).
activate_gcloud_path() {
  if command -v gcloud >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x "${GCLOUD_SDK_NESTED}/bin/gcloud" ]]; then
    export PATH="${GCLOUD_SDK_NESTED}/bin:${PATH}"
    if [[ -f "${GCLOUD_SDK_NESTED}/path.bash.inc" ]]; then
      # shellcheck disable=SC1091
      source "${GCLOUD_SDK_NESTED}/path.bash.inc"
    fi
    return 0
  fi

  if [[ -x "${GCLOUD_HOME}/bin/gcloud" ]]; then
    export PATH="${GCLOUD_HOME}/bin:${PATH}"
    if [[ -f "${GCLOUD_HOME}/path.bash.inc" ]]; then
      # shellcheck disable=SC1091
      source "${GCLOUD_HOME}/path.bash.inc"
    fi
    return 0
  fi

  return 1
}

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

  # SDK may be on disk (nested layout) but not on PATH yet — fix for this shell
  # so a re-run after a partial install still verifies cleanly.
  if ! command -v gcloud >/dev/null 2>&1; then
    activate_gcloud_path || true
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

  activate_gcloud_path || true
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify() {
  log "Verifying installation"

  activate_gcloud_path || true

  if ! command -v gcloud >/dev/null 2>&1; then
    die "gcloud not found on PATH after install. The installer may use a nested folder. Add one of these to your shell profile (use the path that exists on your machine), then open a new terminal:\n  # Nested layout (common on Linux):\n  source \"${GCLOUD_SDK_NESTED}/path.bash.inc\"\n  # Flat layout:\n  source \"${GCLOUD_HOME}/path.bash.inc\"\n  # zsh: try path.zsh.inc under the same directory as path.bash.inc"
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
