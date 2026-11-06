#!/usr/bin/env bash
# install-chrome.sh — Install Google Chrome from the official repo (openSUSE).
#
# Usage:
#   sudo ./install-chrome.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: safe to re-run. Must run as root (except --dry-run).
# Standalone: adds its own repo, needs no other script first.
# === MODULES: config / helpers / guards / steps / main (all in this file) ===

set -euo pipefail
IFS=$'\n\t'

readonly REPO_URL="https://dl.google.com/linux/chrome/rpm/stable/x86_64"
readonly REPO_KEY="https://dl.google.com/linux/linux_signing_key.pub"
readonly REPO_ALIAS="google-chrome"
readonly PKG="google-chrome-stable"

DRY_RUN=false
ASSUME_YES=false

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
die()  { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

run() {
    local IFS=' '
    log "→ $*"
    if $DRY_RUN; then return 0; fi
    "$@"
}

zypper() {
    local IFS=' '
    env ZYPP_CURL2=1 run zypper "$@"
}

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    echo ""
    echo "Options:"
    echo "  --dry-run   Print steps without changing the system"
    echo "  --yes, -y   Skip confirmation prompts"
    echo "  --help, -h  Show this help"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=true ;;
            --yes|-y)  ASSUME_YES=true ;;
            --help|-h) usage ;;
            *) die "Unknown argument: $1 (try --help)" ;;
        esac
        shift
    done
}

require_root() {
    if $DRY_RUN; then warn "Dry-run: skip root check"; return 0; fi
    [[ $EUID -eq 0 ]] || die "Please run with sudo: sudo $0"
    command -v zypper >/dev/null || die "zypper not found (openSUSE required)"
    command -v rpm >/dev/null || die "rpm not found (openSUSE required)"
}

# === MODULE: step_repo v1 ===
step_repo() {
    log "Setting up Google Chrome repository..."
    if zypper repos 2>/dev/null | grep -q "$REPO_ALIAS"; then
        warn "Repository already present"
    else
        run rpm --import "$REPO_KEY"
        run zypper addrepo -f "$REPO_URL" "$REPO_ALIAS"
        ok "Repository added"
    fi
    run zypper --non-interactive --gpg-auto-import-keys refresh --from "$REPO_ALIAS"
}
# === END MODULE: step_repo ===

# === MODULE: step_install v1 ===
step_install() {
    log "Installing Google Chrome..."
    if $DRY_RUN || ! rpm -q "$PKG" &>/dev/null; then
        run zypper --non-interactive install --no-recommends "$PKG"
        ok "Google Chrome install requested"
    else
        warn "Google Chrome already installed"
    fi
}
# === END MODULE: step_install ===

main() {
    parse_args "$@"
    require_root
    step_repo
    step_install
    ok "Chrome setup complete."
}

main "$@"
