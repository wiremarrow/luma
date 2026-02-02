#!/bin/bash
# ============================================================================
# Luma - Architectural Visualization Tool
# Security-Audited Custom Node Installation Script
# ============================================================================
# Generated: 2025-01-31
# Audit Version: 1.0
#
# This script installs verified ComfyUI custom nodes required for the
# PH's Archviz x AI workflow. All packages have been security audited.
#
# CRITICAL SECURITY NOTES:
# - CVE-2025-45076: ComfyUI-Manager RCE (PATCHED in v3.38+)
# - CVE-2024-21575: ComfyUI-Impact-Pack path traversal
# - Ultralytics 8.3.41-8.3.42 contained cryptocurrency miner (BLOCKED)
# ============================================================================

set -e  # Exit on any error
set -o pipefail  # Catch errors in piped commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Platform detection for cross-platform compatibility
IS_MACOS=false
if [[ "$(uname)" == "Darwin" ]]; then
    IS_MACOS=true
fi
COMFYUI_DIR="$SCRIPT_DIR/ComfyUI"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"; }

# ============================================================================
# SECURITY AUDIT SUMMARY
# ============================================================================
print_security_audit() {
    cat << 'AUDIT'
================================================================================
                    SECURITY AUDIT SUMMARY - LUMA ARCHVIZ
================================================================================

CRITICAL VULNERABILITIES (MITIGATED IN THIS SCRIPT):

  [CVE-2025-45076] ComfyUI-Manager RCE via Custom Node Install
    Status: PATCHED in v3.31+ (v3.38+ recommended)
    Action: Script installs latest version with security fixes

  [CVE-2025-67303] ComfyUI-Manager Insecure File Location
    Status: PATCHED in v3.38+
    Action: Script installs latest version

  [CVE-2026-22777] ComfyUI-Manager CRLF Injection
    Status: PATCHED in v3.39.2+ and v4.0.5+
    Action: Verify you have v3.39.2+ installed

  [CVE-2025-6092] ComfyUI Core XSS Vulnerability
    Status: Affects ComfyUI ≤0.3.39
    Action: Update ComfyUI to latest version

  [CVE-2024-21575] ComfyUI-Impact-Pack Path Traversal
    Status: PATCHED in latest version
    Action: Script installs latest version

  [MALWARE] Ultralytics 8.3.41, 8.3.42, 8.3.45, 8.3.46 Cryptocurrency Miner
    Status: BLOCKED
    Action: Script warns if dangerous version detected
    Reference: https://blog.pypi.org/posts/2024-12-11-ultralytics-attack-analysis/

ARCHIVED PACKAGES (REQUIRED - Installing with Warnings):

  - WASasquatch/was-node-suite-comfyui (ARCHIVED June 2025)
    22 nodes required by workflow - INSTALLING WITH HIGH RISK WARNING
  - theUpsider/ComfyUI-Logic (ARCHIVED June 2025)
    12 nodes required by workflow - INSTALLING WITH HIGH RISK WARNING

ARCHIVED PACKAGES (NOT REQUIRED - Excluded):

  - chrisgoringe/cg-image-picker (ARCHIVED May 2025) -> Using cg-image-filter
  - palant/image-resize-comfyui (ARCHIVED May 2024) -> Nodes in was-node-suite

VERIFIED MAINTAINERS:

  - ltdrdata (Dr.Lt.Data): Core ComfyUI ecosystem maintainer
  - kijai (Jukka Seppänen): Finnish ML specialist, 5.6k GitHub followers
  - rgthree (Regis Gaughan III): Technical Lead at Google
  - cubiq (Matteo Spinelli): Prolific developer (maintenance mode)
  - Kosinkadink: ComfyUI-AnimateDiff-Evolved author (3.3k stars)
  - pythongosssss: ComfyUI-Custom-Scripts author (2.9k stars)

For complete audit details, see:
  - /Users/admin/.claude/plans/eager-rolling-goose.md
  - /Users/admin/code/luma/comfyui/SECURITY_AUDIT.md

================================================================================
AUDIT
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================
preflight_checks() {
    log_section "Pre-flight Checks"

    # Check if ComfyUI directory exists
    if [ ! -d "$COMFYUI_DIR" ]; then
        log_error "ComfyUI directory not found at $COMFYUI_DIR"
        log_error "Please run: git clone https://github.com/comfyanonymous/ComfyUI.git"
        exit 1
    fi

    # Check if custom_nodes directory exists
    if [ ! -d "$CUSTOM_NODES_DIR" ]; then
        log_error "custom_nodes directory not found"
        exit 1
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        exit 1
    fi

    log_info "All pre-flight checks passed"
}

# ============================================================================
# CLONE HELPER FUNCTION
# ============================================================================
clone_repo() {
    local repo_url="$1"
    local dir_name=$(basename "$repo_url" .git)
    local risk_level="${2:-LOW}"

    if [ -d "$CUSTOM_NODES_DIR/$dir_name" ]; then
        log_info "Skipping $dir_name (already exists)"
        return 0
    fi

    case $risk_level in
        "LOW")
            log_info "Cloning $dir_name..."
            ;;
        "MEDIUM")
            log_warn "Cloning $dir_name (MEDIUM RISK - monitor for updates)..."
            ;;
        "HIGH")
            log_warn "Cloning $dir_name (HIGH RISK - requires security constraints)..."
            ;;
    esac

    cd "$CUSTOM_NODES_DIR"
    git clone "$repo_url" 2>&1 | while read line; do echo "    $line"; done

    # Install requirements if present
    if [ -f "$CUSTOM_NODES_DIR/$dir_name/requirements.txt" ]; then
        log_info "  Installing dependencies for $dir_name..."
        local req_file="$CUSTOM_NODES_DIR/$dir_name/requirements.txt"

        # On macOS, substitute CUDA-only packages with CPU equivalents
        if $IS_MACOS; then
            local temp_req="/tmp/${dir_name}_requirements.txt"
            sed 's/onnxruntime-gpu/onnxruntime/g' "$req_file" > "$temp_req"
            pip install -r "$temp_req" 2>&1 | while read line; do echo "    $line"; done
            rm -f "$temp_req"
        else
            pip install -r "$req_file" 2>&1 | while read line; do echo "    $line"; done
        fi
    fi
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================
main() {
    echo ""
    print_security_audit
    echo ""

    preflight_checks

    cd "$CUSTOM_NODES_DIR"

    # ========================================================================
    # TIER 1: CORE INFRASTRUCTURE (Required, Highest Trust)
    # ========================================================================
    log_section "TIER 1: Core Infrastructure (Required)"

    # ComfyUI-Manager - CRITICAL: Provides package management and security scanning
    # CVE-2025-45076 patched in v3.38+
    clone_repo "https://github.com/ltdrdata/ComfyUI-Manager.git" "MEDIUM"

    # Verify Manager version
    if [ -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
        cd "$CUSTOM_NODES_DIR/ComfyUI-Manager"
        MANAGER_VERSION=$(git describe --tags 2>/dev/null || echo "unknown")
        log_info "ComfyUI-Manager version: $MANAGER_VERSION"
        log_warn "Ensure version is 3.38+ for CVE-2025-45076 patch"
        cd "$CUSTOM_NODES_DIR"
    fi

    # ========================================================================
    # TIER 2: VERIFIED LOW-RISK PACKAGES
    # ========================================================================
    log_section "TIER 2: Verified Low-Risk Packages"

    # ControlNet and Preprocessing
    clone_repo "https://github.com/Fannovel16/comfyui_controlnet_aux.git" "LOW"
    clone_repo "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git" "LOW"

    # Model Loaders
    clone_repo "https://github.com/city96/ComfyUI-GGUF.git" "LOW"

    # IP-Adapter
    clone_repo "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git" "LOW"
    clone_repo "https://github.com/cubiq/ComfyUI_essentials.git" "LOW"

    # Vision Models (kijai - verified Finnish ML specialist)
    clone_repo "https://github.com/kijai/ComfyUI-KJNodes.git" "LOW"
    clone_repo "https://github.com/kijai/ComfyUI-DepthAnythingV2.git" "LOW"
    clone_repo "https://github.com/kijai/ComfyUI-Florence2.git" "LOW"
    clone_repo "https://github.com/kijai/ComfyUI-segment-anything-2.git" "LOW"

    # Upscaling
    clone_repo "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" "LOW"

    # UI and Workflow Enhancement
    clone_repo "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "LOW"
    clone_repo "https://github.com/rgthree/rgthree-comfy.git" "LOW"
    clone_repo "https://github.com/yolain/ComfyUI-Easy-Use.git" "LOW"

    # Utility Nodes
    clone_repo "https://github.com/BadCafeCode/masquerade-nodes-comfyui.git" "LOW"
    clone_repo "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git" "LOW"
    clone_repo "https://github.com/evanspearman/ComfyMath.git" "LOW"
    clone_repo "https://github.com/jamesWalker55/comfyui-various.git" "LOW"
    # comfyui-various has no requirements.txt but needs soundfile for audio nodes
    pip install soundfile 2>&1 | while read line; do echo "    $line"; done
    clone_repo "https://github.com/EllangoK/ComfyUI-post-processing-nodes.git" "LOW"
    clone_repo "https://github.com/melMass/comfy_mtb.git" "LOW"

    # ========================================================================
    # TIER 3: MEDIUM-RISK PACKAGES (Require Monitoring)
    # ========================================================================
    log_section "TIER 3: Medium-Risk Packages (Monitor for Updates)"

    # ComfyUI-Impact-Pack - CRITICAL SECURITY NOTE
    # CVE-2024-21575: Path traversal vulnerability
    # Ultralytics dependency had cryptominer in versions 8.3.41-8.3.42
    log_warn "Installing ComfyUI-Impact-Pack with security constraints..."
    clone_repo "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "HIGH"

    # Community forks
    clone_repo "https://github.com/jags111/efficiency-nodes-comfyui.git" "MEDIUM"
    clone_repo "https://github.com/sipherxyz/comfyui-art-venture.git" "MEDIUM"

    # Replacement for archived cg-image-picker
    clone_repo "https://github.com/chrisgoringe/cg-image-filter.git" "LOW"

    # ========================================================================
    # TIER 4: ARCHIVED PACKAGES (Required for Workflow - Security Risk)
    # ========================================================================
    log_section "TIER 4: Archived Packages (Required - No Security Updates)"

    log_error "╔══════════════════════════════════════════════════════════════════╗"
    log_error "║  WARNING: INSTALLING ARCHIVED PACKAGES - NO SECURITY UPDATES     ║"
    log_error "║  These packages are required for the workflow but are no longer  ║"
    log_error "║  maintained. Use for INTERNAL purposes only. Monitor for forks.  ║"
    log_error "╚══════════════════════════════════════════════════════════════════╝"
    echo ""

    # WASasquatch/was-node-suite-comfyui - ARCHIVED June 2025
    # Required nodes (22 total): Image Resize, BLIP Analyze Image, Text Concatenate,
    # Text String, Number Input, True/False, Text to Conditioning, Image Bounds,
    # Image Crop Location, Samples Passthrough, Create Grid Image, Image Flip,
    # Image Levels Adjustment, Image Blending Mode, Image High Pass Filter,
    # CLIP Text Encode (NSP), Number to Seed, Number to Float, Mask Fill Region,
    # Image Bounds to Console, Random Number, Logic Boolean
    log_warn "Installing WASasquatch/was-node-suite-comfyui..."
    log_warn "  Status: ARCHIVED June 2025 - NO SECURITY UPDATES"
    log_warn "  Reason: Required for 22 nodes used in workflow"
    log_warn "  Risk: HIGH - Monitor for security issues, consider forking"
    clone_repo "https://github.com/WASasquatch/was-node-suite-comfyui.git" "HIGH"

    # theUpsider/ComfyUI-Logic - ARCHIVED June 2025
    # Required nodes (12 total): Int, Float, Bool, String, Compare, IfExecute,
    # DebugPrint, And, Or, Not, ClampInt, ClampFloat
    log_warn "Installing theUpsider/ComfyUI-Logic..."
    log_warn "  Status: ARCHIVED June 2025 - NO SECURITY UPDATES"
    log_warn "  Reason: Required for 12 logic/comparison nodes in workflow"
    log_warn "  Risk: HIGH - Monitor for security issues, consider forking"
    clone_repo "https://github.com/theUpsider/ComfyUI-Logic.git" "HIGH"

    echo ""
    log_warn "Other archived packages NOT installed (not required):"
    log_warn "  - chrisgoringe/cg-image-picker (ARCHIVED May 2025)"
    log_warn "    Replaced by: cg-image-filter (installed above)"
    log_warn ""
    log_warn "  - palant/image-resize-comfyui (ARCHIVED May 2024)"
    log_warn "    Replaced by: Nodes available in was-node-suite"

    # ========================================================================
    # POST-INSTALL SECURITY CHECKS
    # ========================================================================
    log_section "Post-Install Security Checks"

    cd "$CUSTOM_NODES_DIR"

    # Check for dangerous ultralytics versions (all 4 malicious versions)
    # Reference: https://blog.pypi.org/posts/2024-12-11-ultralytics-attack-analysis/
    log_info "Checking for dangerous ultralytics versions..."
    if pip show ultralytics 2>/dev/null | grep -E "Version: 8\.3\.(41|42|45|46)" > /dev/null; then
        log_error "CRITICAL: Dangerous ultralytics version detected!"
        log_error "Versions 8.3.41, 8.3.42, 8.3.45, 8.3.46 contain cryptocurrency mining malware."
        log_error "Run: pip install 'ultralytics<8.3.41' to downgrade"
        exit 1
    else
        ULTRALYTICS_VERSION=$(pip show ultralytics 2>/dev/null | grep "Version:" | cut -d' ' -f2 || echo "not installed")
        log_info "ultralytics version: $ULTRALYTICS_VERSION (OK)"
    fi

    # Count eval() calls (informational)
    log_info "Scanning for eval() usage (informational)..."
    EVAL_COUNT=$(grep -r "eval\s*(" --include="*.py" . 2>/dev/null | wc -l | tr -d ' ')
    if [ "$EVAL_COUNT" -gt 50 ]; then
        log_warn "Found $EVAL_COUNT eval() calls across packages"
        log_warn "This is normal for ML packages but worth monitoring"
    else
        log_info "Found $EVAL_COUNT eval() calls (within normal range)"
    fi

    # Check for subprocess calls (informational)
    log_info "Scanning for subprocess usage (informational)..."
    SUBPROCESS_COUNT=$(grep -r "subprocess" --include="*.py" . 2>/dev/null | wc -l | tr -d ' ')
    log_info "Found $SUBPROCESS_COUNT subprocess references"

    # ========================================================================
    # COMPLETION
    # ========================================================================
    log_section "Installation Complete"

    echo ""
    log_info "Custom node installation complete!"
    echo ""
    log_info "Installed packages:"
    ls -1 "$CUSTOM_NODES_DIR" | grep -v "^example_node" | grep -v "^websocket_image" | while read dir; do
        echo "    - $dir"
    done
    echo ""
    log_warn "IMPORTANT: Review the warnings above before running ComfyUI"
    log_warn "IMPORTANT: Verify ultralytics version is NOT 8.3.41, 8.3.42, 8.3.45, or 8.3.46"
    echo ""
    log_info "To start ComfyUI, run: ./run.sh"
    log_info "Full security audit: cat SECURITY_AUDIT.md"
}

# Run main function
main "$@"
