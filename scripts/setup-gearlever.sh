#!/usr/bin/env bash
# setup-gearlever.sh — Install Gear Lever (AppImage manager) via Flathub (openSUSE).
# Installs FUSE support and Flatpak/Flathub when missing.
#
# Usage:
#   sudo ./setup-gearlever.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: safe to re-run. Must run as root (except --dry-run).
# Standalone: installs Flatpak, Flathub, and FUSE itself.

set -euo pipefail
IFS=$'\n\t'

readonly APP_ID="it.mijorus.gearlever"

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
}

step_fuse() {
    log "Checking FUSE..."
    if rpm -q libfuse2 &>/dev/null; then
        warn "FUSE already installed"
    else
        run zypper --non-interactive install --no-recommends libfuse2
        ok "FUSE installed (zypper)"
    fi
}

step_flatpak() {
    log "Setting up Flatpak and Flathub..."
    if ! command -v flatpak >/dev/null; then
        run zypper --non-interactive install --no-recommends flatpak
    fi
    run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ok "Flathub repository enabled"
}

step_gearlever() {
    log "Installing Gear Lever..."
    if ! command -v flatpak >/dev/null && ! $DRY_RUN; then
        die "Flatpak install failed — run Flatpak setup manually."
    fi
    if $DRY_RUN; then run flatpak install -y flathub "$APP_ID"
    elif ! flatpak list --app 2>/dev/null | grep -q "$APP_ID"; then
        run flatpak install -y flathub "$APP_ID"
        ok "Gear Lever installed"
    else
        warn "Gear Lever already installed"
    fi
}

main() {
    parse_args "$@"
    require_root
    run zypper --non-interactive --gpg-auto-import-keys refresh
    step_fuse
    step_flatpak
    step_gearlever
    ok "Gear Lever setup complete."
}

main "$@"
