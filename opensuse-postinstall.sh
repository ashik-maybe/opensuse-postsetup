#!/usr/bin/env bash
#
# opensuse-postinstall.sh — openSUSE Universal Post-Install Setup
# Usage: sudo ./opensuse-postinstall.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Guard
[[ "${EUID}" -eq 0 ]] || error "Run with sudo: sudo $0"

# ── Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="${NAME:-Unknown}"
    OS_VERSION="${VERSION_ID:-Unknown}"
else
    error "Cannot detect openSUSE version"
fi

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}     openSUSE Universal Post-Install Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
log "Detected: ${OS_NAME} ${OS_VERSION}"
echo ""

# ── Snapper snapshot
if command -v snapper &>/dev/null && ! snapper list 2>/dev/null | grep -q "Pre-Setup"; then
    log "Creating pre-setup snapshot..."
    snapper create --description "Pre-Setup" && success "Snapshot created" || warn "Snapshot failed"
    echo ""
fi

# ══════════════════════════════════════════════════════════════
# 1. Packman Repository + Multimedia Codecs
# ══════════════════════════════════════════════════════════════
log "Setting up Packman and multimedia codecs..."
echo ""

# Pick URL based on version
if [[ "${NAME:-}" =~ (Tumbleweed|Slowroll) ]]; then
    PACKMAN_URL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/"
else
    PACKMAN_URL="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${VERSION_ID}/Essentials/"
fi

if ! zypper repos | grep -q "packman-essentials"; then
    zypper addrepo --refresh --priority 90 --name "Packman Essentials" "${PACKMAN_URL}" packman-essentials
    success "Packman repo added"
else
    warn "Packman repo already present"
fi

zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive dist-upgrade --from packman-essentials --allow-vendor-change --no-recommends

# Just the essentials
zypper --non-interactive install --no-recommends \
    ffmpeg \
    lame \
    gstreamer-plugins-bad \
    gstreamer-plugins-ugly \
    gstreamer-plugins-libav \
    2>/dev/null || true

success "Codecs installed"

# ══════════════════════════════════════════════════════════════
# 2. Optimize Zypper
# ══════════════════════════════════════════════════════════════
echo ""
log "Optimizing Zypper..."

ZYPP_CONF="/etc/zypp/zypp.conf"

if grep -q "download.max_concurrent_connections = 10" "$ZYPP_CONF" 2>/dev/null; then
    warn "Zypper already optimized — skipping"
else
    cat > "${ZYPP_CONF}" <<'EOF'
[main]
gpgcheck = true
solver.onlyRequires = true
deltarpm = false
repo.refresh.minimal-age = 3600
download.max_concurrent_connections = 10
download.min_download_speed = 1024
EOF
    zypper clean --all &>/dev/null
    success "Zypper optimized"
fi

# ══════════════════════════════════════════════════════════════
# 3. System Tuning
# ══════════════════════════════════════════════════════════════
echo ""
log "Tuning system..."

# fstrim for SSD
systemctl enable --now fstrim.timer 2>/dev/null && success "fstrim enabled" || warn "fstrim skipped"

# Mask PackageKit
systemctl mask packagekit.service 2>/dev/null && success "PackageKit masked" || warn "PackageKit skipped"

# zRAM
if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
    zypper --non-interactive install zram-generator &>/dev/null || true
    cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
    systemctl daemon-reload
    systemctl start /dev/zram0 2>/dev/null || true
    success "zRAM configured"
else
    warn "zRAM already configured"
fi

# ══════════════════════════════════════════════════════════════
# 4. Full Update
# ══════════════════════════════════════════════════════════════
echo ""
log "Running full system update..."
zypper --non-interactive update --no-recommends
success "System updated"

# ── Cleanup
echo ""
log "Cleaning up..."
zypper clean --all &>/dev/null
success "Cleanup complete"

# ── Done
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
echo -e "${BLUE}What was done:${NC}"
echo "  • Packman repo + ffmpeg/gstreamer codecs"
echo "  • Zypper optimized for parallel downloads"
echo "  • fstrim + zRAM + PackageKit masked"
echo "  • System fully updated"
echo ""
echo -e "${YELLOW}→ Reboot recommended${NC}"
echo ""
