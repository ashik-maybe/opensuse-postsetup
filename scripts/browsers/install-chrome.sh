#!/usr/bin/env bash
#
# setup-chrome.sh — Google Chrome Installer for openSUSE (Idempotent)
# Usage: sudo ./setup-chrome.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Guard
[[ "${EUID}" -eq 0 ]] || error "Run with sudo: sudo $0"

readonly CHROME_GPG_KEY="https://dl.google.com/linux/linux_signing_key.pub"
readonly CHROME_REPO_ADDR="https://dl.google.com/linux/chrome/rpm/stable/x86_64"

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}        Google Chrome Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Repo
log "Setting up Google Chrome repository..."
if ! zypper repos | grep -q "google-chrome"; then
    rpm --import "${CHROME_GPG_KEY}"
    zypper addrepo -f "${CHROME_REPO_ADDR}" google-chrome
    success "Repository added"
else
    warn "Repository already present"
fi

# ── Install
echo ""
log "Installing Google Chrome..."
if ! rpm -q google-chrome-stable &>/dev/null; then
    zypper --non-interactive install google-chrome-stable
    success "Google Chrome installed"
else
    warn "Google Chrome already installed"
fi

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Chrome setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
