#!/usr/bin/env bash
# opensuse-postinstall.sh — openSUSE universal post-install setup.
# Adds Packman, multimedia codecs, zypper speed tuning, zRAM, fstrim.
#
# Usage:
#   sudo ./opensuse-postinstall.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: safe to re-run. Must run as root (except --dry-run).
# Standalone: does not depend on any other script in this repo.

set -euo pipefail
IFS=$'\n\t'

# 0. Config
readonly ZYPP_CONF="/etc/zypp/zypp.conf"
readonly ZYPP_KEYS=(
    "solver.onlyRequires=true"
    "deltarpm=false"
    "repo.refresh.minimal-age=3600"
    "download.max_concurrent_connections=10"
    "download.min_download_speed=1024"
)
readonly CODECS=(
    ffmpeg lame gstreamer-plugins-bad gstreamer-plugins-ugly
    gstreamer-plugins-libav
)

DRY_RUN=false
ASSUME_YES=false

# 1. Helpers
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

# 2. Pre-flight guards
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
    read -rp "Proceed? dist-upgrade switches back to Packman codecs (y/N): " -n 1 reply || true
    echo ""
    [[ "$reply" =~ ^[Yy]$ ]] || { warn "Cancelled."; exit 2; }
}

detect_os() {
    [[ -f /etc/os-release ]] || die "Cannot detect openSUSE version"
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="${NAME:-Unknown}"
    OS_VERSION="${VERSION_ID:-Unknown}"
    log "Detected: $OS_NAME $OS_VERSION"
}

# 3. Steps
step_snapshot() {
    log "Creating pre-setup snapshot..."
    if command -v snapper >/dev/null && ! snapper list 2>/dev/null | grep -q "Pre-Setup"; then
        run snapper create --description "Pre-Setup" && ok "Snapshot created" || warn "Snapshot failed"
    else
        warn "Snapper not present or snapshot exists — skipping"
    fi
}

step_packman() {
    log "Enabling Packman Essentials and multimedia codecs..."
    local packman_url
    if [[ "${NAME:-}" =~ (Tumbleweed|Slowroll) ]]; then
        packman_url="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/"
    else
        packman_url="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${VERSION_ID:-Unknown}/Essentials/"
    fi
    if zypper repos 2>/dev/null | grep -q "packman-essentials"; then
        warn "Packman repo already present"
    else
        run zypper addrepo --refresh --priority 90 --name "Packman Essentials" "$packman_url" packman-essentials
        ok "Packman repo added"
    fi
    run zypper --non-interactive --gpg-auto-import-keys refresh
    confirm
    run zypper --non-interactive dist-upgrade --from packman-essentials --allow-vendor-change --no-recommends
    run zypper --non-interactive install --no-recommends "${CODECS[@]}"
    ok "Codecs installed"
}

step_optimise_zypper() {
    log "Optimising zypper for speed..."
    if $DRY_RUN; then
        run bash -c "printf '%s\n' 'append missing keys to $ZYPP_CONF'"
        return 0
    fi
    [[ -f "$ZYPP_CONF" ]] || die "$ZYPP_CONF not found"
    cp "$ZYPP_CONF" "${ZYPP_CONF}.bak" || true
    local kv key
    for kv in "${ZYPP_KEYS[@]}"; do
        key="${kv%%=*}"
        if grep -q "^${key}[[:space:]]*=" "$ZYPP_CONF"; then
            log "$key already configured"
        else
            printf '%s=%s\n' "$key" "${kv#*=}" >> "$ZYPP_CONF"
            ok "Added $kv"
        fi
    done
    run zypper clean --all >/dev/null
    ok "Zypper optimised (backup: ${ZYPP_CONF}.bak)"
}

step_system_tuning() {
    log "Tuning system (fstrim, PackageKit mask, zRAM)..."
    run systemctl enable --now fstrim.timer
    run systemctl mask packagekit.service
    if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
        run zypper --non-interactive install --no-recommends zram-generator
        run bash -c "cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF"
        run systemctl daemon-reload
        run systemctl start /dev/zram0
        ok "zRAM configured"
    else
        warn "zRAM already configured"
    fi
}

step_system_update() {
    log "Running full system update..."
    run zypper --non-interactive update --no-recommends
    ok "System updated"
}

step_cleanup() {
    log "Cleaning up..."
    run zypper clean --all >/dev/null
    ok "Cleanup complete"
}

# 4. Main
main() {
    parse_args "$@"
    require_root
    detect_os
    step_snapshot
    step_packman
    step_optimise_zypper
    step_system_tuning
    step_system_update
    step_cleanup
    echo ""
    ok "Setup complete."
    echo "Packman, codecs, zypper speed tuning, fstrim, zRAM: done."
    warn "Reboot recommended."
}

main "$@"
