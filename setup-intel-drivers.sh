#!/usr/bin/env bash
#
# setup-intel.sh — Intel Hardware Acceleration & Drivers for openSUSE
# Usage: sudo ./setup-intel.sh

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
echo -e "${CYAN}     Intel Hardware Acceleration Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Check for Intel GPU
if ! lspci | grep -iE "vga|3d|display" | grep -qi "intel"; then
    warn "No Intel GPU detected — continuing anyway"
fi

# ══════════════════════════════════════════════════════════════
# 1. VA-API Drivers
# ══════════════════════════════════════════════════════════════
log "Installing VA-API drivers..."
echo ""

zypper --non-interactive install --no-recommends \
    intel-media-driver \
    libva \
    libva-utils \
    libva-vdpau-driver \
    2>/dev/null || true

success "VA-API drivers installed"

# ══════════════════════════════════════════════════════════════
# 2. Vulkan
# ══════════════════════════════════════════════════════════════
echo ""
log "Installing Vulkan drivers..."
echo ""

zypper --non-interactive install --no-recommends \
    vulkan-tools \
    Mesa-vulkan-device-select \
    Mesa-vulkan-overlay \
    2>/dev/null || true

success "Vulkan drivers installed"

# ══════════════════════════════════════════════════════════════
# 3. Intel Compute (OpenCL)
# ══════════════════════════════════════════════════════════════
echo ""
log "Installing Intel compute runtime..."
echo ""

zypper --non-interactive install --no-recommends \
    intel-compute-runtime \
    intel-graphics-compute-runtime \
    clinfo \
    2>/dev/null || true

success "Compute runtime installed"

# ══════════════════════════════════════════════════════════════
# 4. Intel GPU Tools
# ══════════════════════════════════════════════════════════════
echo ""
log "Installing Intel GPU monitoring tools..."
echo ""

zypper --non-interactive install --no-recommends \
    intel-gpu-tools \
    2>/dev/null || true

success "GPU tools installed"

# ══════════════════════════════════════════════════════════════
# 5. Environment Variables
# ══════════════════════════════════════════════════════════════
echo ""
log "Setting environment variables..."

ENV_FILE="/etc/environment"

if ! grep -q "LIBVA_DRIVER_NAME" "$ENV_FILE" 2>/dev/null; then
    echo "LIBVA_DRIVER_NAME=iHD" >> "$ENV_FILE"
    success "Set LIBVA_DRIVER_NAME=iHD"
else
    warn "LIBVA_DRIVER_NAME already set"
fi

# Also add profile.d for better DM compatibility
PROFILE_FILE="/etc/profile.d/intel-media.sh"
if [ ! -f "$PROFILE_FILE" ]; then
    cat > "$PROFILE_FILE" <<'EOF'
# Intel Media Driver Configuration
export LIBVA_DRIVER_NAME=iHD
EOF
    chmod 644 "$PROFILE_FILE"
    success "Created $PROFILE_FILE"
else
    warn "Profile file already exists"
fi

# ══════════════════════════════════════════════════════════════
# 6. Verify
# ══════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Intel setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
echo -e "${BLUE}Verify with:${NC}"
echo "  • vainfo                     (VA-API codecs)"
echo "  • vulkaninfo --summary       (Vulkan driver)"
echo "  • clinfo                     (OpenCL platforms)"
echo "  • sudo intel_gpu_top         (Real-time GPU monitor)"
echo ""
echo -e "${YELLOW}→ Log out or restart to apply environment changes${NC}"
echo ""
