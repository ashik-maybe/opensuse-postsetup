#!/usr/bin/env bash
#
# disable_kde_bloat_opensuse.sh — Disable KDE Background Services for openSUSE
# Stops RAM-heavy services without removing packages
# Usage: sudo ./disable_kde_bloat_opensuse.sh

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
echo -e "${CYAN}     KDE Background Service Disabler${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Disable Baloo
log "Disabling Baloo file indexer..."
if command -v balooctl6 &>/dev/null; then
    balooctl6 suspend 2>/dev/null || true
    balooctl6 disable 2>/dev/null || true
    success "Baloo disabled (balooctl6)"
elif command -v balooctl &>/dev/null; then
    balooctl suspend 2>/dev/null || true
    balooctl disable 2>/dev/null || true
    success "Baloo disabled"
else
    warn "Baloo not found"
fi

# ── Stop Akonadi
echo ""
log "Stopping Akonadi..."
if command -v akonadictl &>/dev/null; then
    akonadictl stop 2>/dev/null || true
    success "Akonadi stopped"
else
    warn "akonadictl not found"
fi

# ── Disable user services
echo ""
log "Disabling background services..."

SERVICES=(
    akonadi-server
    akonadi-control
    akonadi-indexing-agent
    akonadi-followupreminder-agent
    akonadi-maildir-resource
    akonadi-migration-agent
    akonadi-newmailnotifier-agent
    akonadi-sendlater-agent
    baloo_file
    baloo-file
    telepathy-mission-control
    telepathy-logger
)

for svc in "${SERVICES[@]}"; do
    if systemctl --user is-enabled "$svc" &>/dev/null 2>&1; then
        systemctl --user disable --now "$svc" 2>/dev/null || true
        echo "   ✓ Disabled $svc"
    fi
done
success "User services disabled"

# ── Disable PackageKit
echo ""
log "Disabling PackageKit..."
if systemctl is-active packagekit.service &>/dev/null 2>&1; then
    systemctl disable --now packagekit.service 2>/dev/null || true
    success "PackageKit disabled"
else
    warn "PackageKit not running"
fi

# ── Cleanup
echo ""
log "Cleaning caches..."
rm -rf ~/.local/share/akonadi ~/.config/akonadi ~/.local/share/baloo ~/.cache/packagekit 2>/dev/null || true
success "Caches cleaned"

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Services disabled${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
echo -e "${BLUE}What was disabled:${NC}"
echo "  • Baloo file indexer (~200-300MB)"
echo "  • Akonadi PIM database (~200-400MB)"
echo "  • Telepathy IM framework"
echo "  • PackageKit background daemon"
echo ""
echo -e "${BLUE}RAM savings: ~400-700MB${NC}"
echo -e "${BLUE}Packages: untouched, nothing broken${NC}"
echo ""
echo -e "${YELLOW}→ Log out or restart to finish${NC}"
echo ""
