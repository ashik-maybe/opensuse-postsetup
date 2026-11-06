#!/usr/bin/env bash
# remove_kde_bloat_opensuse.sh — Disable KDE background services (openSUSE).
# Stops RAM-heavy services. Does not remove packages.
#
# Usage:
#   sudo ./remove_kde_bloat_opensuse.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: missing services are skipped. Use --dry-run first.
# Standalone: needs no other script first.

set -euo pipefail
IFS=$'\n\t'

readonly SERVICES=(
    akonadi-server akonadi-control akonadi-indexing-agent
    akonadi-followupreminder-agent akonadi-maildir-resource
    akonadi-migration-agent akonadi-newmailnotifier-agent
    akonadi-sendlater-agent baloo_file baloo-file
    telepathy-mission-control telepathy-logger
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

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    echo ""
    echo "Options:"
    echo "  --dry-run   List services without changing anything"
    echo "  --yes, -y   Disable without confirmation"
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
}

confirm() {
    if $ASSUME_YES || $DRY_RUN; then return 0; fi
    local reply
    read -rp "Proceed? Disables ${#SERVICES[@]} user services + PackageKit (y/N): " -n 1 reply || true
    echo ""
    [[ "$reply" =~ ^[Yy]$ ]] || { warn "Cancelled."; exit 2; }
}

user_home() {
    local user="${SUDO_USER:-$(id -un)}"
    getent passwd "$user" | cut -d: -f6
}

run_user() {
    if $DRY_RUN; then run "$@"; return 0; fi
    runuser -u "${SUDO_USER:-$(id -un)}" -- "$@"
}

step_snapshot() {
    log "Creating pre-debloat snapshot..."
    if command -v snapper >/dev/null; then
        run snapper create --description "Pre-Debloat" && ok "Snapshot created" || warn "Snapshot failed"
    else
        warn "Snapper not present — skipping"
    fi
}

step_baloo() {
    log "Disabling Baloo file indexer..."
    if command -v balooctl6 >/dev/null; then
        run_user balooctl6 suspend
        run_user balooctl6 disable
        ok "Baloo disabled (balooctl6)"
    elif command -v balooctl >/dev/null; then
        run_user balooctl suspend
        run_user balooctl disable
        ok "Baloo disabled"
    else
        warn "Baloo not found"
    fi
}

step_akonadi() {
    log "Stopping Akonadi..."
    if command -v akonadictl >/dev/null; then
        run_user akonadictl stop
        ok "Akonadi stopped"
    else
        warn "akonadictl not found"
    fi
}

step_user_services() {
    log "Disabling background services..."
    local svc
    for svc in "${SERVICES[@]}"; do
        if $DRY_RUN; then run run_user systemctl --user disable --now "$svc"
        elif runuser -u "${SUDO_USER:-$(id -un)}" -- systemctl --user is-enabled "$svc" &>/dev/null 2>&1; then
            run_user systemctl --user disable --now "$svc"
            echo "   ✓ Disabled $svc"
        fi
    done
    ok "User services disabled"
}

step_packagekit() {
    log "Disabling PackageKit..."
    if systemctl is-active packagekit.service &>/dev/null 2>&1 || $DRY_RUN; then
        run systemctl disable --now packagekit.service
        ok "PackageKit disabled"
    else
        warn "PackageKit not running"
    fi
}

step_cleanup() {
    log "Cleaning caches..."
    local home
    home="$(user_home)"
    if [[ -n "$home" && "$home" != "/" ]]; then
        run bash -c "rm -rf '$home/.local/share/akonadi' '$home/.config/akonadi' '$home/.local/share/baloo' '$home/.cache/packagekit'"
    fi
    ok "Caches cleaned"
}

main() {
    parse_args "$@"
    require_root
    confirm
    step_snapshot
    step_baloo
    step_akonadi
    step_user_services
    step_packagekit
    step_cleanup
    echo ""
    ok "Services disabled."
    echo "Disabled: Baloo (~200-300MB), Akonadi (~200-400MB), Telepathy, PackageKit."
    warn "Log out or restart to finish."
}

main "$@"
