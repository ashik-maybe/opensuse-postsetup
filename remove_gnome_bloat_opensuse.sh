#!/usr/bin/env bash
# remove_gnome_bloat_opensuse.sh — Remove unnecessary GNOME packages (openSUSE).
# Locks removed packages so they are not reinstalled. Disables Tracker.
#
# Usage:
#   sudo ./remove_gnome_bloat_opensuse.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: missing packages are skipped. Destructive — use --dry-run first.
# Standalone: needs no other script first. Creates its own snapper snapshot.

set -euo pipefail
IFS=$'\n\t'

readonly PACKAGES=(
    baobab cheese dconf-editor evince evolution firefox gimp
    gnome-boxes gnome-calculator gnome-calendar gnome-characters
    gnome-chess gnome-clocks gnome-connections gnome-contacts
    gnome-disk-utility gnome-extensions gnome-font-viewer gnome-logs
    gnome-mahjongg gnome-maps gnome-mines gnome-music gnome-photos
    gnome-software gnome-sudoku gnome-system-monitor gnome-tour
    gnome-tweaks gnome-user-docs gnome-weather gpk-update-viewer
    iagno "libreoffice-*" lightsoff opensuse-welcome quadrapassel
    rhythmbox seahorse shotwell simple-scan snapshot swell-foop
    totem xscreensaver xterm yelp
)

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
    echo "  --dry-run   List packages without removing anything"
    echo "  --yes, -y   Remove without confirmation"
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

confirm() {
    if $ASSUME_YES || $DRY_RUN; then return 0; fi
    local reply
    read -rp "Proceed? (${#PACKAGES[@]} packages will be removed) (y/N): " -n 1 reply || true
    echo ""
    [[ "$reply" =~ ^[Yy]$ ]] || { warn "Cancelled."; exit 2; }
}

user_home() {
    local user="${SUDO_USER:-$(id -un)}"
    getent passwd "$user" | cut -d: -f6
}

step_list() {
    log "Packages to remove (${#PACKAGES[@]}):"
    local pkg
    for pkg in "${PACKAGES[@]}"; do echo "  - $pkg"; done
    echo ""
}

step_snapshot() {
    log "Creating pre-debloat snapshot..."
    if command -v snapper >/dev/null; then
        run snapper create --description "Pre-Debloat" && ok "Snapshot created" || warn "Snapshot failed"
    else
        warn "Snapper not present — skipping"
    fi
}

step_remove() {
    log "Removing packages (missing ones skipped)..."
    run zypper --non-interactive remove --clean-deps "${PACKAGES[@]}"
    ok "Packages removed"
}

step_lock() {
    log "Locking removed packages..."
    local pkg locks
    locks="$(zypper locks 2>/dev/null || true)"
    for pkg in "${PACKAGES[@]}"; do
        if ! echo "$locks" | grep -q -- "$pkg"; then
            run zypper addlock "$pkg"
        fi
    done
    ok "Packages locked"
}

step_tracker() {
    log "Disabling Tracker (file content indexer)..."
    run bash -c "command -v tracker3 >/dev/null && tracker3 daemon -t || true"
    if $DRY_RUN; then run systemctl --user mask tracker-miner-fs-3.service tracker-extract-3.service tracker-writeback-3.service
    else
        local user="${SUDO_USER:-$(id -un)}"
        runuser -u "$user" -- systemctl --user mask tracker-miner-fs-3.service tracker-extract-3.service tracker-writeback-3.service 2>/dev/null || true
    fi
    ok "Tracker disabled"
}

step_cleanup() {
    log "Cleaning up..."
    local home
    home="$(user_home)"
    if [[ -n "$home" && "$home" != "/" ]]; then
        run bash -c "rm -rf '$home/.cache/tracker3' '$home/.local/share/tracker3' '$home/.cache/gnome-software'"
    fi
    run zypper clean --all >/dev/null
    ok "Cleanup complete"
}

main() {
    parse_args "$@"
    require_root
    step_list
    confirm
    step_snapshot
    step_remove
    step_lock
    step_tracker
    step_cleanup
    echo ""
    ok "GNOME debloat complete."
    log "Kept: GNOME Shell, Nautilus, Terminal, Settings."
    warn "Log out or restart to finish."
}

main "$@"
