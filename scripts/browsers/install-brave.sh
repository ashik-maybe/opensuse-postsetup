#!/usr/bin/env bash
#
# setup-brave.sh — Brave Browser Installer for openSUSE
# Usage: sudo ./setup-brave.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Guard
[[ "${EUID}" -eq 0 ]] || error "Run with sudo: sudo $0"

readonly BRAVE_REPO_URL="https://brave-browser-rpm-release.s3.brave.com/\$basearch"
readonly BRAVE_KEY="https://brave-browser-rpm-release.s3.brave.com/brave-core.asc"
readonly REPO_ALIAS="brave-browser"

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}        Brave Browser Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Repo
log "Setting up Brave repository..."
if ! zypper repos | grep -q "${REPO_ALIAS}"; then
    rpm --import "${BRAVE_KEY}"
    zypper addrepo -f "${BRAVE_REPO_URL}" "${REPO_ALIAS}"
    success "Repository added"
else
    warn "Repository already present"
fi

# ── Install
echo ""
log "Installing Brave Browser..."
if ! rpm -q brave-browser &>/dev/null; then
    env ZYPP_CURL2=1 zypper --non-interactive install brave-browser
    success "Brave Browser installed"
else
    warn "Brave Browser already installed"
fi

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Brave setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
