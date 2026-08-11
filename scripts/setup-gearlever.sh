#!/usr/bin/env bash
#
# setup-gearlever.sh — Gear Lever AppImage Manager for openSUSE/Fedora
# Usage: sudo ./setup-gearlever.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Guard
[[ "${EUID}" -eq 0 ]] || error "Run with sudo: sudo $0"

readonly APP_ID="it.mijorus.gearlever"

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}        Gear Lever Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ──────────────────────────────────────────────────────────────
install_fuse() {
    log "Checking FUSE..."

    # Detect package manager
    if command -v dnf &>/dev/null; then
        if ! rpm -q fuse-libs &>/dev/null; then
            dnf install -y fuse-libs
            success "FUSE installed (dnf)"
        else
            warn "FUSE already installed"
        fi
    elif command -v zypper &>/dev/null; then
        if ! rpm -q libfuse2 &>/dev/null; then
            zypper --non-interactive install --no-recommends libfuse2
            success "FUSE installed (zypper)"
        else
            warn "FUSE already installed"
        fi
    else
        warn "Unknown package manager — install fuse manually if AppImages fail to mount"
    fi
}

# ──────────────────────────────────────────────────────────────
install_gearlever() {
    echo ""
    log "Installing Gear Lever..."

    if ! command -v flatpak &>/dev/null || ! flatpak remotes | grep -q "flathub"; then
        error "Flatpak/Flathub not found. Run Flatpak setup script first."
    fi

    if ! flatpak list --app | grep -q "$APP_ID"; then
        flatpak install -y flathub "$APP_ID"
        success "Gear Lever installed"
    else
        warn "Gear Lever already installed"
    fi
}

# ──────────────────────────────────────────────────────────────
install_fuse
install_gearlever

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Gear Lever setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
echo -e "${BLUE}Installed:${NC} FUSE, Gear Lever (Flathub)"
echo ""
