#!/usr/bin/env bash
#
# setup-gcloud-path.sh - Permanently add Google Cloud SDK to your shell profile.
#
# Adds two lines to your shell rc files (bash and/or zsh) so that 'gcloud',
# 'gsutil', 'bq', etc. are on PATH in every new shell, and tab-completion works:
#
#   source ".../google-cloud-sdk/path.bash.inc"        (or path.zsh.inc)
#   source ".../google-cloud-sdk/completion.bash.inc"  (or completion.zsh.inc)
#
# It auto-detects:
#   - the SDK root (nested:  $HOME/google-cloud-sdk/google-cloud-sdk
#                   or flat: $HOME/google-cloud-sdk)
#   - which shell rc files to update (~/.bashrc, ~/.bash_profile, ~/.zshrc)
#
# Re-running is safe: lines are added only if they are not already there.
# A timestamped backup of each edited file is kept.
#
# Usage:
#   bash setup-gcloud-path.sh                # interactive (asks to confirm)
#   bash setup-gcloud-path.sh --yes          # no prompt
#   bash setup-gcloud-path.sh --sdk /path    # use a custom SDK directory
#   bash setup-gcloud-path.sh --help

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,24p' "$0"; }

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
ASSUME_YES=0
SDK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --sdk)
      [[ $# -ge 2 ]] || die "--sdk requires a path"
      SDK_DIR="$2"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Detect SDK root
# ---------------------------------------------------------------------------
detect_sdk_dir() {
  if [[ -n "$SDK_DIR" ]]; then
    [[ -d "$SDK_DIR" ]] || die "Provided --sdk path does not exist: $SDK_DIR"
    return
  fi

  local nested="${HOME}/google-cloud-sdk/google-cloud-sdk"
  local flat="${HOME}/google-cloud-sdk"

  if [[ -f "${nested}/path.bash.inc" || -x "${nested}/bin/gcloud" ]]; then
    SDK_DIR="$nested"
  elif [[ -f "${flat}/path.bash.inc" || -x "${flat}/bin/gcloud" ]]; then
    SDK_DIR="$flat"
  else
    die "Could not find google-cloud-sdk under $HOME. Pass --sdk /full/path or run install-gcloud.sh first."
  fi
}

# ---------------------------------------------------------------------------
# Append a single line to a file if it is not already present
# ---------------------------------------------------------------------------
ensure_line() {
  local file="$1" line="$2"
  if grep -Fqx -- "$line" "$file" 2>/dev/null; then
    return 1
  fi
  printf '%s\n' "$line" >> "$file"
  return 0
}

backup_once() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local marker="${file}.bak.gcloud-setup.${RUN_TS}"
  [[ -f "$marker" ]] && return 0
  cp "$file" "$marker"
  log "Backed up $file -> $marker"
}

# ---------------------------------------------------------------------------
# Update a profile file with the right source lines for a given shell flavor
#   $1: file to edit (created if missing)
#   $2: 'bash' or 'zsh'
# ---------------------------------------------------------------------------
update_profile() {
  local file="$1" flavor="$2"
  local path_inc completion_inc
  path_inc="${SDK_DIR}/path.${flavor}.inc"
  completion_inc="${SDK_DIR}/completion.${flavor}.inc"

  # Fall back to bash includes if zsh ones are missing.
  if [[ "$flavor" == "zsh" && ! -f "$path_inc" ]]; then
    path_inc="${SDK_DIR}/path.bash.inc"
  fi
  if [[ "$flavor" == "zsh" && ! -f "$completion_inc" ]]; then
    completion_inc="${SDK_DIR}/completion.bash.inc"
  fi

  [[ -f "$path_inc" ]] || { warn "Missing $path_inc; skipping $file"; return 0; }
  [[ -f "$completion_inc" ]] || warn "Missing $completion_inc; completion will be skipped for $file"

  if [[ ! -e "$file" ]]; then
    : > "$file"
    log "Created $file"
  fi

  backup_once "$file"

  local header='# Google Cloud SDK (added by setup-gcloud-path.sh)'
  local line_path="source \"${path_inc}\""
  local line_comp="source \"${completion_inc}\""

  local changed=0
  ensure_line "$file" "$header"     && changed=1 || true
  ensure_line "$file" "$line_path"  && changed=1 || true
  if [[ -f "$completion_inc" ]]; then
    ensure_line "$file" "$line_comp" && changed=1 || true
  fi

  if (( changed )); then
    log "Updated $file"
  else
    log "$file already configured"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  [[ -n "${HOME:-}" && -d "${HOME}" ]] || die "HOME is unset or not a directory."

  detect_sdk_dir
  RUN_TS="$(date +%Y%m%d%H%M%S)"

  log "Configuring shell profiles for: $(id -un)"
  log "  HOME    : ${HOME}"
  log "  SDK dir : ${SDK_DIR}"

  if (( ASSUME_YES == 0 )); then
    printf '\nProceed? [y/N] '
    local reply=""
    read -r reply || true
    case "${reply}" in
      y|Y|yes|YES) ;;
      *) die "Aborted by user." ;;
    esac
  fi

  # Bash: prefer ~/.bashrc on Linux; also touch ~/.bash_profile so it works for
  # macOS-style login shells when present.
  update_profile "${HOME}/.bashrc" bash
  if [[ -f "${HOME}/.bash_profile" ]]; then
    update_profile "${HOME}/.bash_profile" bash
  fi

  # Zsh: only if the user uses zsh (rc file present, or login shell is zsh).
  if [[ -f "${HOME}/.zshrc" ]] || [[ "${SHELL:-}" == */zsh ]]; then
    update_profile "${HOME}/.zshrc" zsh
  fi

  log "Done. Activate it now in this shell with:"
  printf '  source "%s/path.%s.inc"\n' "$SDK_DIR" "bash"
  log "Or open a new terminal."

  if command -v gcloud >/dev/null 2>&1; then
    log "gcloud is currently on PATH: $(command -v gcloud)"
  else
    warn "gcloud not on PATH yet in this shell. Run the source command above (or open a new terminal)."
  fi
}

main "$@"
