#!/usr/bin/env bash
# setup-intel-drivers.sh — Intel VA-API, OpenCL, Vulkan, GPU tools (openSUSE).
# Use for Intel HD 520 and newer.
#
# Usage:
#   sudo ./setup-intel-drivers.sh [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: safe to re-run. Must run as root (except --dry-run).
# Standalone: installs its own dependencies, needs no other script first.

set -euo pipefail
IFS=$'\n\t'

readonly VAAPI_PKGS=(intel-media-driver libva libva-utils libva-vdpau-driver)
readonly VULKAN_PKGS=(vulkan-tools Mesa-vulkan-device-select Mesa-vulkan-overlay)
readonly COMPUTE_PKGS=(intel-compute-runtime intel-graphics-compute-runtime clinfo)
readonly TOOLS_PKGS=(intel-gpu-tools)
readonly ENV_FILE="/etc/environment"
readonly PROFILE_FILE="/etc/profile.d/intel-media.sh"
readonly VAAPI_EXPORT="LIBVA_DRIVER_NAME=iHD"

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

check_intel_gpu() {
    if lspci 2>/dev/null | grep -iE "vga|3d|display" | grep -qi "intel"; then
        ok "Intel GPU detected"
    else
        warn "No Intel GPU detected — some packages may be unnecessary."
    fi
}

install_pkgs() {
    local label="$1"; shift
    log "$label"
    run zypper --non-interactive install --no-recommends "$@"
    ok "$label — done"
}

step_env() {
    log "Setting environment variables..."
    if grep -q "LIBVA_DRIVER_NAME" "$ENV_FILE" 2>/dev/null; then
        warn "LIBVA_DRIVER_NAME already set"
    else
        run bash -c "printf '%s\n' '$VAAPI_EXPORT' >> '$ENV_FILE'"
        ok "Set $VAAPI_EXPORT"
    fi
    if [[ ! -f "$PROFILE_FILE" ]]; then
        run bash -c "cat > '$PROFILE_FILE' <<'EOF'
# Intel Media Driver Configuration
export LIBVA_DRIVER_NAME=iHD
EOF"
        run chmod 644 "$PROFILE_FILE"
        ok "Created $PROFILE_FILE"
    else
        warn "Profile file already exists"
    fi
}

main() {
    parse_args "$@"
    require_root
    check_intel_gpu
    run zypper --non-interactive --gpg-auto-import-keys refresh
    install_pkgs "Installing VA-API drivers..." "${VAAPI_PKGS[@]}"
    install_pkgs "Installing Vulkan drivers..." "${VULKAN_PKGS[@]}"
    install_pkgs "Installing Intel compute runtime..." "${COMPUTE_PKGS[@]}"
    install_pkgs "Installing Intel GPU monitoring tools..." "${TOOLS_PKGS[@]}"
    step_env
    echo ""
    ok "Intel setup complete."
    echo "Verify with: vainfo · vulkaninfo --summary · clinfo · sudo intel_gpu_top"
    warn "Log out or restart to apply environment changes."
}

main "$@"
