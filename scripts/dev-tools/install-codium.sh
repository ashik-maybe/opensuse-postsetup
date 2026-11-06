#!/usr/bin/env bash
# install-codium.sh — Install VSCodium from the paulcarroty repo (openSUSE).
#
# Usage:
#   sudo ./install-codium.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: safe to re-run. Must run as root (except --dry-run).
# Standalone: writes its own repo file, needs no other script first.

set -euo pipefail
IFS=$'\n\t'

readonly REPO_FILE="/etc/zypp/repos.d/vscodium.repo"
readonly REPO_NAME="gitlab.com_paulcarroty_vscodium_repo"
readonly PKG="codium"

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

step_repo() {
    log "Setting up VSCodium repository..."
    if [[ -f "$REPO_FILE" ]]; then
        warn "Repository already present"
    else
        run bash -c "tee '$REPO_FILE' > /dev/null <<'EOF'
[$REPO_NAME]
name=$REPO_NAME
baseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF"
        ok "Repository added"
    fi
    run zypper --non-interactive --gpg-auto-import-keys refresh --from "$REPO_NAME"
}

step_install() {
    log "Installing VSCodium..."
    if $DRY_RUN || ! rpm -q "$PKG" &>/dev/null; then
        run zypper --non-interactive install --no-recommends "$PKG"
        ok "VSCodium install requested"
    else
        warn "VSCodium already installed"
    fi
}

main() {
    parse_args "$@"
    require_root
    step_repo
    step_install
    ok "VSCodium setup complete."
}

main "$@"
