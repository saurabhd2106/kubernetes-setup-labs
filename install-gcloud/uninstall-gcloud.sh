#!/usr/bin/env bash
#
# uninstall-gcloud.sh - Remove the Google Cloud SDK installed by install-gcloud.sh.
#
# Scope: per-user. Operates on $HOME of whoever runs the script.
#   - As root:    affects /root
#   - As student: affects /home/student
#
# Usage:
#   bash uninstall-gcloud.sh                # interactive (asks to confirm)
#   bash uninstall-gcloud.sh --yes          # skip confirmation
#   bash uninstall-gcloud.sh --keep-config  # keep ~/.config/gcloud (auth/configs)
#   bash uninstall-gcloud.sh --help
#
# What it removes (for the running user only):
#   - $HOME/google-cloud-sdk (covers flat and nested layouts)
#   - Homebrew cask google-cloud-sdk (macOS, if installed via brew)
#   - 'source ".../google-cloud-sdk/(path|completion).(bash|zsh).inc"' lines from
#     ~/.bashrc, ~/.bash_profile, ~/.profile, ~/.zshrc, ~/.zprofile (with backups)
#   - $HOME/.config/gcloud   (unless --keep-config is passed)
#   - macOS user caches/logs for google-cloud-sdk (best-effort)
#
# Out of scope:
#   - apt-installed package (use: sudo apt-get remove --purge google-cloud-cli)
#   - system-wide installs / other users' $HOME
#   - Windows

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  sed -n '2,28p' "$0"
}

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
ASSUME_YES=0
KEEP_CONFIG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --keep-config) KEEP_CONFIG=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
preflight() {
  if [[ -z "${HOME:-}" || ! -d "${HOME}" ]]; then
    die "HOME is unset or not a directory; refusing to proceed."
  fi

  log "Preflight checks"
  log "  user : $(id -un)"
  log "  home : ${HOME}"
  if (( KEEP_CONFIG )); then
    log "  mode : remove SDK + profile lines (keep ~/.config/gcloud)"
  else
    log "  mode : remove SDK + profile lines + ~/.config/gcloud"
  fi

  if (( ASSUME_YES == 0 )); then
    printf '\nProceed with uninstall? [y/N] '
    local reply=""
    read -r reply || true
    case "${reply}" in
      y|Y|yes|YES) ;;
      *) die "Aborted by user." ;;
    esac
  fi
}

# ---------------------------------------------------------------------------
# Stop running gcloud processes (best effort)
# ---------------------------------------------------------------------------
stop_processes() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -u "$(id -un)" -f "google-cloud-sdk" >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# Remove SDK install
# ---------------------------------------------------------------------------
remove_sdk_dir() {
  local gcloud_home="${HOME}/google-cloud-sdk"
  if [[ -d "${gcloud_home}" ]]; then
    log "Removing ${gcloud_home}"
    rm -rf "${gcloud_home}"
  else
    log "No SDK directory at ${gcloud_home}"
  fi
}

remove_brew_cask() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    return 0
  fi
  if ! command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if brew list --cask 2>/dev/null | grep -qx google-cloud-sdk; then
    log "Removing Homebrew cask google-cloud-sdk"
    brew uninstall --cask google-cloud-sdk || warn "brew uninstall failed; continuing."
  fi
}

# ---------------------------------------------------------------------------
# Strip profile lines (with backups)
# ---------------------------------------------------------------------------
strip_profile_lines() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  if ! grep -E 'google-cloud-sdk/(path|completion)\.(bash|zsh)\.inc' "$f" >/dev/null 2>&1; then
    return 0
  fi

  local ts backup tmp
  ts="$(date +%Y%m%d%H%M%S)"
  backup="${f}.bak.gcloud-uninstall.${ts}"
  cp "$f" "$backup"

  tmp="$(mktemp)"
  grep -Ev 'google-cloud-sdk/(path|completion)\.(bash|zsh)\.inc' "$f" > "$tmp" || true
  mv "$tmp" "$f"

  log "Cleaned $f (backup at $backup)"
}

clean_profiles() {
  local f
  for f in \
    "${HOME}/.bashrc" \
    "${HOME}/.bash_profile" \
    "${HOME}/.profile" \
    "${HOME}/.zshrc" \
    "${HOME}/.zprofile"
  do
    strip_profile_lines "$f"
  done
}

# ---------------------------------------------------------------------------
# Remove config / credentials
# ---------------------------------------------------------------------------
remove_config() {
  if (( KEEP_CONFIG )); then
    warn "Keeping ${HOME}/.config/gcloud (--keep-config)"
    return 0
  fi

  if [[ -d "${HOME}/.config/gcloud" ]]; then
    log "Removing ${HOME}/.config/gcloud (auth, ADC, configurations)"
    rm -rf "${HOME}/.config/gcloud"
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    rm -rf "${HOME}/Library/Caches/google-cloud-sdk" 2>/dev/null || true
    rm -rf "${HOME}/Library/Logs/google-cloud-sdk" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify() {
  log "Verifying"

  hash -r 2>/dev/null || true

  if command -v gcloud >/dev/null 2>&1; then
    warn "Another 'gcloud' is still on PATH. It was not installed by this uninstaller and was left alone:"
    if command -v which >/dev/null 2>&1; then
      which -a gcloud >&2 || true
    else
      command -v gcloud >&2 || true
    fi
    warn "If it came from apt: sudo apt-get remove --purge google-cloud-cli"
    warn "If it came from another user's home, run this script as that user."
  else
    log "Google Cloud SDK uninstalled for $(id -un)."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  preflight
  stop_processes
  remove_sdk_dir
  remove_brew_cask
  clean_profiles
  remove_config
  verify
}

main "$@"
