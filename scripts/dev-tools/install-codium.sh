#!/usr/bin/env bash
#
# install-codium.sh — VSCodium Installer for openSUSE
# Usage: sudo ./install-codium.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Guard
[[ "${EUID}" -eq 0 ]] || error "Run with sudo: sudo $0"

readonly REPO_FILE="/etc/zypp/repos.d/vscodium.repo"
readonly REPO_NAME="gitlab.com_paulcarroty_vscodium_repo"

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}        VSCodium Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Repo
log "Setting up VSCodium repository..."
if [ ! -f "$REPO_FILE" ]; then
    tee "$REPO_FILE" <<'EOF'
[gitlab.com_paulcarroty_vscodium_repo]
name=gitlab.com_paulcarroty_vscodium_repo
baseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF
    success "Repository added"
else
    warn "Repository already present"
fi

# ── Refresh
log "Refreshing repositories..."
zypper --non-interactive refresh "${REPO_NAME}" 2>/dev/null || zypper --non-interactive refresh
success "Repositories refreshed"

# ── Install
echo ""
log "Installing VSCodium..."
if ! rpm -q codium &>/dev/null; then
    zypper --non-interactive install codium
    success "VSCodium installed"
else
    warn "VSCodium already installed"
fi

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ VSCodium setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
