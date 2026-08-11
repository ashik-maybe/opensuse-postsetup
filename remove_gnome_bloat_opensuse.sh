#!/usr/bin/env bash
#
# remove_gnome_bloat_opensuse.sh — GNOME Bloat Removal for openSUSE
# Usage: sudo ./remove_gnome_bloat_opensuse.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Guard
[[ "${EUID}" -eq 0 ]] || error "Run with sudo: sudo $0"

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}     openSUSE GNOME Bloat Removal Tool${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Packages to remove
PACKAGES=(
    baobab
    cheese
    dconf-editor
    evince
    evolution
    firefox
    gimp
    gnome-boxes
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-chess
    gnome-clocks
    gnome-connections
    gnome-contacts
    gnome-disk-utility
    gnome-extensions
    gnome-font-viewer
    gnome-logs
    gnome-mahjongg
    gnome-maps
    gnome-mines
    gnome-music
    gnome-photos
    gnome-software
    gnome-sudoku
    gnome-system-monitor
    gnome-tour
    gnome-tweaks
    gnome-user-docs
    gnome-weather
    gpk-update-viewer
    iagno
    libreoffice-*
    lightsoff
    opensuse-welcome
    quadrapassel
    rhythmbox
    seahorse
    shotwell
    simple-scan
    snapshot
    swell-foop
    totem
    xscreensaver
    xterm
    yelp
)

# ── Display
log "Packages to remove:"
echo ""
for pkg in "${PACKAGES[@]}"; do
    echo "  • $pkg"
done
echo ""

read -p "Proceed? (y/N): " -n 1 -r
echo ""
[[ $REPLY =~ ^[Yy]$ ]] || { warn "Cancelled."; exit 0; }
echo ""

# ── Snapper snapshot
if command -v snapper &>/dev/null; then
    log "Creating pre-debloat snapshot..."
    snapper create --description "Pre-Debloat" && success "Snapshot created" || warn "Snapshot failed"
    echo ""
fi

# ── 1. Remove packages
log "Removing packages..."
zypper --non-interactive remove --clean-deps "${PACKAGES[@]}" || warn "Some packages not installed — continuing"
success "Packages removed"

# ── 2. Lock packages
echo ""
log "Locking removed packages..."
current_locks=$(zypper locks)
for pkg in "${PACKAGES[@]}"; do
    if ! echo "$current_locks" | grep -q "$pkg"; then
        zypper addlock "$pkg" 2>/dev/null || true
    fi
done
success "Packages locked"

# ── 3. Disable Tracker (file content indexer — not needed for app search)
echo ""
log "Disabling Tracker..."
if command -v tracker3 &>/dev/null; then
    tracker3 daemon -t 2>/dev/null || true
fi
systemctl --user mask tracker-miner-fs-3.service 2>/dev/null || true
systemctl --user mask tracker-extract-3.service 2>/dev/null || true
systemctl --user mask tracker-writeback-3.service 2>/dev/null || true
success "Tracker disabled"

# ── 4. Cleanup
echo ""
log "Cleaning up..."
rm -rf ~/.cache/tracker3 ~/.local/share/tracker3 ~/.cache/gnome-software 2>/dev/null || true
zypper clean --all &>/dev/null
success "Cleanup complete"

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ GNOME debloat complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
echo -e "${BLUE}What was removed:${NC}"
echo "  • Unnecessary GNOME apps + games"
echo "  • GNOME Software + PackageKit"
echo "  • Tracker (file content indexer)"
echo ""
echo -e "${BLUE}Kept:${NC}"
echo "  • GNOME Shell, Nautilus, Terminal, Settings"
echo "  • Bluetooth, printing, online accounts (if you use them)"
echo ""
echo -e "${YELLOW}→ Log out or restart to finish${NC}"
echo ""
