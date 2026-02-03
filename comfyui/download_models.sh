#!/usr/bin/env bash
# ============================================================================
# MODEL DOWNLOAD SCRIPT
# PH's Archviz x AI ComfyUI Workflow v0.37
# Version: 1.0.0
# ============================================================================
#
# PURPOSE
# -------
# Downloads all models required for the PH's Archviz workflow from verified
# HuggingFace repositories. This script is the SINGLE SOURCE OF TRUTH for
# model acquisition, ensuring full replicability across installations.
#
# USAGE
# -----
#   ./download_models.sh
#
# MODELS DOWNLOADED
# -----------------
#   Location 1: /models/ (14 models, ~42 GB)
#     Mapped to ComfyUI via extra_model_paths.yaml
#
#   Location 2: ComfyUI/models/ (2 models, ~1.8 GB)
#     Required by custom nodes that use hardcoded paths
#     (DownloadAndLoadSAM2Model, DownloadAndLoadFlorence2Model)
#
#   Total: 16 models, ~44 GB
#
# DEPENDENCIES
# ------------
#   - huggingface-cli (pip install huggingface-hub) - preferred
#   - wget - fallback for single file downloads
#   - ~50 GB free disk space
#
# SECURITY CONSIDERATIONS
# -----------------------
# All models are sourced from verified HuggingFace repositories with
# preference for safe file formats:
#
#   .safetensors  - SAFE: Cannot execute arbitrary code during load
#   .gguf         - CAUTION: Binary format, potential parsing vulnerabilities
#   .pth          - CAUTION: Uses Python pickle, can execute code on load
#
# For .gguf and .pth files, we only download from:
#   - Original paper authors (LiheYoung, Kim2091)
#   - Trusted community quantizers (city96 - 50K+ downloads)
#
# ============================================================================
# MODEL MANIFEST
# ============================================================================
#
# Each model entry includes:
#   - Source URL for verification
#   - Author attribution
#   - File size
#   - Purpose in the workflow
#   - Whether the file is renamed after download
#
# -----------------------------------------------------------------------------
# CHECKPOINTS (SDXL Base Models) -> /models/checkpoints/
# -----------------------------------------------------------------------------
#
# Model: RealVisXL_V4.0.safetensors
# Source: https://huggingface.co/SG161222/RealVisXL_V4.0
# Author: SG161222 (original creator, 1M+ downloads)
# Size: 6.5 GB
# Purpose: Primary SDXL checkpoint for Stage 1 generation
# Renamed: No
# SHA256: 912c9dc74f5855175c31a7993f863a043ac8dcc31732b324cd05d75cd7e16844
#
# Model: realvisxlV50_v50LightningBakedvae.safetensors
# Source: https://huggingface.co/SG161222/RealVisXL_V5.0_Lightning
# Author: SG161222 (original creator)
# Size: 6.5 GB
# Purpose: Fast SDXL checkpoint (4-step Lightning distillation)
# Renamed: YES - from "RealVisXL_V5.0_Lightning_fp16.safetensors"
# Reason: Workflow JSON expects Civitai naming convention
# SHA256: fabcadd9330dcc4f9702063428d40b9d4d07168d8acefc819b8d1d9db466b3ec
#
# -----------------------------------------------------------------------------
# FLUX MODELS (Main Diffusion) -> /models/unet/
# -----------------------------------------------------------------------------
#
# Model: flux1-dev-Q8_0.gguf
# Source: https://huggingface.co/city96/FLUX.1-dev-gguf
# Author: city96 (trusted quantizer, 50K+ downloads on this repo)
# Size: 12 GB
# Purpose: Flux.1-dev diffusion model with Q8_0 quantization
# Renamed: No
# Note: Q8 provides best quality. Do NOT substitute with Q5/Q4 variants.
# SHA256: 129032f32224bf7138f16e18673d8008ba5f84c1ec74063bf4511a8bb4cf553d
#
# -----------------------------------------------------------------------------
# TEXT ENCODERS (CLIP) -> /models/clip/
# -----------------------------------------------------------------------------
#
# Model: t5-v1_1-xxl-encoder-Q8_0.gguf
# Source: https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf
# Author: city96 (same trusted quantizer)
# Size: 4.7 GB
# Purpose: T5-XXL text encoder for Flux text conditioning
# Renamed: No
# SHA256: 9ec60f6028534b7fe5af439fcb535d75a68592a9ca3fcdeb175ef89e3ee99825
#
# Model: clip_l.safetensors
# Source: https://huggingface.co/comfyanonymous/flux_text_encoders
# Author: comfyanonymous (ComfyUI creator/maintainer)
# Size: 235 MB
# Purpose: CLIP-L text encoder for Flux
# Renamed: No
# SHA256: 660c6f5b1abae9dc498ac2d21e1347d2abdb0cf6c0c0c8576cd796491d9a6cdd
#
# -----------------------------------------------------------------------------
# VISION ENCODERS -> /models/clip_vision/
# -----------------------------------------------------------------------------
#
# Model: CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors
# Source: https://huggingface.co/fofr/comfyui
# Author: fofr (verified ComfyUI contributor, 222 followers)
# Size: 2.4 GB
# Purpose: CLIP Vision encoder required by IP-Adapter for image conditioning
# Renamed: No
# SHA256: 6ca9667da1ca9e0b0f75e46bb030f7e011f44f86cbfb8d5a36590fcd7507b030
#
# -----------------------------------------------------------------------------
# VAE -> /models/vae/
# -----------------------------------------------------------------------------
#
# Model: ae.safetensors
# Source: https://huggingface.co/black-forest-labs/FLUX.1-schnell
# Author: Black Forest Labs (official Flux creators)
# Size: 320 MB
# Purpose: VAE encoder/decoder for Flux latent space
# Renamed: No
# SHA256: afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38
#
# -----------------------------------------------------------------------------
# CONTROLNETS -> /models/controlnet/
# -----------------------------------------------------------------------------
#
# Model: diffusers_xl_canny_full.safetensors
# Source: https://huggingface.co/lllyasviel/sd_control_collection
# Author: lllyasviel (ControlNet paper author, original researcher)
# Size: 2.3 GB
# Purpose: Edge detection ControlNet for architectural line guidance
# Renamed: No
# SHA256: 80664d80e3f233371cb6921110d0a6b7a40c01571905463f9dde5637e7894ed3
#
# Model: diffusers_xl_depth_full.safetensors
# Source: https://huggingface.co/lllyasviel/sd_control_collection
# Author: lllyasviel (ControlNet paper author)
# Size: 2.3 GB
# Purpose: Depth-based ControlNet for spatial structure guidance
# Renamed: No
# SHA256: 8ba4dfaa1958f1f68e5dc7f9839f9ef4e153aef0d330291e5cf966c925f97477
#
# Model: thibaud_xl_openpose.safetensors
# Source: https://huggingface.co/lllyasviel/sd_control_collection
# Author: Thibaud (via lllyasviel's curated collection)
# Size: 2.3 GB
# Purpose: OpenPose skeleton ControlNet for human figure guidance
# Renamed: No
# SHA256: 9e070426568a3c60c128ffb98c66cdc7a0ea21d0d8abb86f73564aaf2e0c6f42
#
# -----------------------------------------------------------------------------
# IP-ADAPTER -> /models/ipadapter/
# -----------------------------------------------------------------------------
#
# Model: ip-adapter-plus_sdxl_vit-h.safetensors
# Source: https://huggingface.co/h94/IP-Adapter
# Author: h94 (Tencent research-based implementation)
# Size: 808 MB
# Purpose: Image prompt adapter for style/reference image conditioning
# Renamed: No
# SHA256: 3f5062b8400c94b7159665b21ba5c62acdcd7682262743d7f2aefedef00e6581
#
# -----------------------------------------------------------------------------
# DEPTH ESTIMATION -> /models/depth/
# -----------------------------------------------------------------------------
#
# Model: depth_anything_v2_vitl.pth
# Source: https://huggingface.co/depth-anything/Depth-Anything-V2-Large
# Author: LiheYoung (CVPR/NeurIPS researcher, paper author)
# Size: 1.2 GB
# Purpose: Monocular depth estimation (V2 - improved accuracy)
# Renamed: No
# Security: .pth format - verified original author repository
# SHA256: a7ea19fa0ed99244e67b624c72b8580b7e9553043245905be58796a608eb9345
#
# Model: depth_anything_vitl14.pth
# Source: https://huggingface.co/spaces/LiheYoung/Depth-Anything
# Author: LiheYoung (same researcher)
# Size: 1.2 GB
# Purpose: Monocular depth estimation (V1 - workflow uses both versions)
# Renamed: No
# Security: .pth format - verified original author repository
# SHA256: 6c6a383e33e51c5fdfbf31e7ebcda943973a9e6a1cbef1564afe58d7f2e8fe63
#
# -----------------------------------------------------------------------------
# UPSCALERS -> /models/upscale_models/
# -----------------------------------------------------------------------------
#
# Model: 4x-UltraSharp.pth
# Source: https://huggingface.co/uwg/upscaler
# Author: Kim2091/uwg (ESRGAN model developer)
# Size: 64 MB
# Purpose: 4x ESRGAN upscaling for final image enhancement
# Renamed: No
# Security: .pth format - from verified ESRGAN model collection
# SHA256: a5812231fc936b42af08a5edba784195495d303d5b3248c24489ef0c4021fe01
#
# ============================================================================
# CUSTOM NODE MODELS (ComfyUI/models/)
# ============================================================================
#
# These models MUST be placed in ComfyUI/models/ because the custom nodes
# check hardcoded paths and ignore extra_model_paths.yaml configuration.
#
# Source code verification:
#   - SAM2: ComfyUI-segment-anything-2/nodes.py line 74
#   - Florence2: ComfyUI-Florence2/nodes.py line 181
#
# -----------------------------------------------------------------------------
# SEGMENTATION -> ComfyUI/models/sam2/
# -----------------------------------------------------------------------------
#
# Model: sam2.1_hiera_base_plus.safetensors
# Source: https://huggingface.co/Kijai/sam2-safetensors
# Author: Kijai (trusted ComfyUI node developer, 10K+ downloads)
# Size: 308 MB
# Purpose: Segment Anything 2 for object detection and masking
# Location: ComfyUI/models/sam2/ (NOT /models/sam2/)
# Reason: DownloadAndLoadSAM2Model checks folder_paths.models_dir/sam2/
# SHA256: eb4b5f725c8b68205aa05bbe6b27efc628b18b4b9c7b9bb8218991b86b9a4932
#
# -----------------------------------------------------------------------------
# VISION-LANGUAGE MODEL -> ComfyUI/models/LLM/
# -----------------------------------------------------------------------------
#
# Model: Florence-2-large (HuggingFace repository - multiple files)
# Source: https://huggingface.co/microsoft/Florence-2-large
# Author: Microsoft (official release)
# Size: 1.5 GB (model.safetensors + config.json + tokenizer files)
# Purpose: Vision-language model for object detection, captioning, grounding
# Location: ComfyUI/models/LLM/Florence-2-large/
# Reason: DownloadAndLoadFlorence2Model checks folder_paths.models_dir/LLM/
# Note: pytorch_model.bin is removed after download (redundant with safetensors)
# SHA256: 4f38ce741c6b71188fe2b3419a55e11917a8a7b321ae2e63c61da0191b0ebad7 (model.safetensors)
#
# ============================================================================
# SOURCE VERIFICATION TIERS
# ============================================================================
#
# TIER 1 - Official Organizations (HIGHEST TRUST)
#   - black-forest-labs (Flux creators)
#   - microsoft (Florence-2)
#   - comfyanonymous (ComfyUI maintainer)
#
# TIER 2 - Original Paper Authors (HIGH TRUST)
#   - lllyasviel (ControlNet paper author)
#   - LiheYoung (Depth Anything paper author)
#
# TIER 3 - Trusted Community (VERIFIED)
#   - city96 (GGUF quantizations, 50K+ downloads)
#   - h94 (IP-Adapter, Tencent research-based)
#   - SG161222 (RealVisXL creator, 1M+ downloads)
#   - Kijai (ComfyUI node developer, 10K+ downloads)
#   - fofr (ComfyUI contributor)
#   - Kim2091/uwg (ESRGAN developer)
#
# ============================================================================

set -e
set -o pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="/Users/admin/code/luma/models"
COMFYUI_MODELS="$SCRIPT_DIR/ComfyUI/models"
LOG_FILE="$SCRIPT_DIR/download_log.txt"

# ============================================================================
# TERMINAL COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

log_section() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

# ============================================================================
# HASH VERIFICATION
# ============================================================================
# Verifies SHA256 hash of downloaded file against expected value.
# Returns 0 if hash matches or no hash provided, 1 on mismatch.

verify_hash() {
    local file="$1"
    local expected_hash="$2"

    if [ -z "$expected_hash" ]; then
        return 0
    fi

    local actual_hash
    actual_hash=$(shasum -a 256 "$file" | cut -d' ' -f1)

    if [ "$actual_hash" == "$expected_hash" ]; then
        log_info "Hash verified: $(basename "$file")"
        return 0
    else
        log_error "Hash mismatch for $file!"
        log_error "  Expected: $expected_hash"
        log_error "  Got:      $actual_hash"
        return 1
    fi
}

# ============================================================================
# HUGGINGFACE DOWNLOAD - SINGLE FILE
# ============================================================================
# Downloads a single file from a HuggingFace repository.
#
# Arguments:
#   $1 - HuggingFace repo (e.g., "black-forest-labs/FLUX.1-schnell")
#   $2 - File path within repo (e.g., "ae.safetensors")
#   $3 - Local destination directory
#   $4 - Optional: Expected SHA256 hash for verification
#
# Behavior:
#   - Skips download if file already exists
#   - Uses huggingface-cli if available, falls back to wget
#   - Verifies hash if provided

hf_download() {
    local repo="$1"
    local file="$2"
    local dest_dir="$3"
    local expected_hash="${4:-}"
    local dest_file="$dest_dir/$(basename "$file")"

    if [ -f "$dest_file" ]; then
        log_info "Exists: $(basename "$file")"
        return 0
    fi

    log_info "Downloading: $file from $repo"

    if command -v huggingface-cli &> /dev/null; then
        huggingface-cli download "$repo" "$file" \
            --local-dir "$dest_dir" \
            --local-dir-use-symlinks False
    else
        local url="https://huggingface.co/$repo/resolve/main/$file"
        wget -q --show-progress -O "$dest_file" "$url"
    fi

    if [ -n "$expected_hash" ]; then
        verify_hash "$dest_file" "$expected_hash"
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloaded: $repo/$file -> $dest_file" >> "$LOG_FILE"
}

# ============================================================================
# HUGGINGFACE DOWNLOAD - FULL REPOSITORY
# ============================================================================
# Downloads an entire HuggingFace repository (all files).
# Used for models like Florence-2 that require multiple files.
#
# Arguments:
#   $1 - HuggingFace repo (e.g., "microsoft/Florence-2-large")
#   $2 - Local destination directory
#
# Behavior:
#   - Skips download if directory exists with model.safetensors
#   - Requires huggingface-cli (no wget fallback for repos)

hf_download_repo() {
    local repo="$1"
    local dest_dir="$2"

    if [ -d "$dest_dir" ] && [ -f "$dest_dir/model.safetensors" ]; then
        log_info "Exists: $(basename "$dest_dir")/"
        return 0
    fi

    log_info "Downloading: $repo (full repository)"
    mkdir -p "$dest_dir"

    if command -v huggingface-cli &> /dev/null; then
        huggingface-cli download "$repo" \
            --local-dir "$dest_dir" \
            --local-dir-use-symlinks False
    else
        log_error "huggingface-cli required for repository download"
        log_error "Install with: pip install huggingface-hub"
        return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloaded repo: $repo -> $dest_dir" >> "$LOG_FILE"
}

# ============================================================================
# SECURITY AUDIT SUMMARY
# ============================================================================
# Prints a summary of source verification for user awareness.

print_security_summary() {
    cat << 'EOF'
================================================================================
                    MODEL DOWNLOAD - SECURITY AUDIT SUMMARY
================================================================================

SOURCE VERIFICATION STATUS:

  TIER 1 - Official Organizations (HIGHEST TRUST):
    ✓ black-forest-labs/FLUX.1-schnell    (VAE)
    ✓ microsoft/Florence-2-large          (Vision-Language Model)
    ✓ comfyanonymous/flux_text_encoders   (CLIP-L)

  TIER 2 - Original Paper Authors (HIGH TRUST):
    ✓ lllyasviel/sd_control_collection    (ControlNet author)
    ✓ depth-anything/Depth-Anything-V2    (CVPR/NeurIPS researcher)

  TIER 3 - Trusted Community (VERIFIED):
    ✓ city96                              (GGUF quantizations)
    ✓ h94                                 (IP-Adapter)
    ✓ SG161222                            (RealVisXL creator)
    ✓ Kijai                               (SAM2 safetensors)

FILE FORMAT SECURITY:
    ✓ .safetensors  - SAFE (cannot execute code)
    ⚠ .gguf         - CAUTION (binary format, from trusted source)
    ⚠ .pth          - CAUTION (pickle format, from original authors only)

================================================================================
EOF
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    echo ""
    print_security_summary
    echo ""

    # Initialize log file
    echo "=== Download started: $(date) ===" >> "$LOG_FILE"

    # ========================================================================
    # CREATE DIRECTORY STRUCTURE
    # ========================================================================

    log_section "Creating Directory Structure"

    mkdir -p "$MODELS_DIR"/{checkpoints,clip,clip_vision,controlnet,ipadapter,upscale_models,vae,unet,depth}
    mkdir -p "$COMFYUI_MODELS"/{sam2,LLM}

    log_info "External models directory: $MODELS_DIR"
    log_info "Custom node models directory: $COMFYUI_MODELS"

    # ========================================================================
    # TIER 1: OFFICIAL ORGANIZATION SOURCES
    # ========================================================================

    log_section "Downloading TIER 1: Official Organization Sources"

    # VAE from Black Forest Labs (Flux creators)
    log_info "VAE from Black Forest Labs..."
    hf_download "black-forest-labs/FLUX.1-schnell" "ae.safetensors" "$MODELS_DIR/vae" \
        "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38"

    # CLIP-L from ComfyUI maintainer
    log_info "CLIP-L from ComfyUI maintainer..."
    hf_download "comfyanonymous/flux_text_encoders" "clip_l.safetensors" "$MODELS_DIR/clip" \
        "660c6f5b1abae9dc498ac2d21e1347d2abdb0cf6c0c0c8576cd796491d9a6cdd"

    # Florence-2 from Microsoft (full repository)
    log_info "Florence-2-large from Microsoft..."
    hf_download_repo "microsoft/Florence-2-large" "$COMFYUI_MODELS/LLM/Florence-2-large"

    # Remove redundant pytorch_model.bin (model.safetensors is preferred)
    if [ -f "$COMFYUI_MODELS/LLM/Florence-2-large/pytorch_model.bin" ]; then
        rm -f "$COMFYUI_MODELS/LLM/Florence-2-large/pytorch_model.bin"
        log_info "Removed redundant pytorch_model.bin (using model.safetensors)"
    fi

    # Verify Florence-2 model.safetensors
    local florence_model="$COMFYUI_MODELS/LLM/Florence-2-large/model.safetensors"
    local florence_hash="4f38ce741c6b71188fe2b3419a55e11917a8a7b321ae2e63c61da0191b0ebad7"
    if [ -f "$florence_model" ]; then
        verify_hash "$florence_model" "$florence_hash"
    fi

    # ========================================================================
    # TIER 2: ORIGINAL PAPER AUTHORS
    # ========================================================================

    log_section "Downloading TIER 2: Original Paper Authors"

    # ControlNet models from lllyasviel (ControlNet paper author)
    log_info "ControlNet models from lllyasviel (paper author)..."
    hf_download "lllyasviel/sd_control_collection" "diffusers_xl_canny_full.safetensors" "$MODELS_DIR/controlnet" \
        "80664d80e3f233371cb6921110d0a6b7a40c01571905463f9dde5637e7894ed3"
    hf_download "lllyasviel/sd_control_collection" "diffusers_xl_depth_full.safetensors" "$MODELS_DIR/controlnet" \
        "8ba4dfaa1958f1f68e5dc7f9839f9ef4e153aef0d330291e5cf966c925f97477"
    hf_download "lllyasviel/sd_control_collection" "thibaud_xl_openpose.safetensors" "$MODELS_DIR/controlnet" \
        "9e070426568a3c60c128ffb98c66cdc7a0ea21d0d8abb86f73564aaf2e0c6f42"

    # Depth Anything from LiheYoung (paper author)
    log_warn "Depth Anything models (.pth format - from original paper author)..."
    hf_download "depth-anything/Depth-Anything-V2-Large" "depth_anything_v2_vitl.pth" "$MODELS_DIR/depth" \
        "a7ea19fa0ed99244e67b624c72b8580b7e9553043245905be58796a608eb9345"

    # Depth Anything V1 (different download path)
    local depth_v1_file="$MODELS_DIR/depth/depth_anything_vitl14.pth"
    local depth_v1_hash="6c6a383e33e51c5fdfbf31e7ebcda943973a9e6a1cbef1564afe58d7f2e8fe63"
    if [ ! -f "$depth_v1_file" ]; then
        log_info "Downloading: depth_anything_vitl14.pth"
        wget -q --show-progress -O "$depth_v1_file" \
            "https://huggingface.co/spaces/LiheYoung/Depth-Anything/resolve/main/checkpoints/depth_anything_vitl14.pth"
        verify_hash "$depth_v1_file" "$depth_v1_hash"
    else
        log_info "Exists: depth_anything_vitl14.pth"
    fi

    # ========================================================================
    # TIER 3: TRUSTED COMMUNITY SOURCES
    # ========================================================================

    log_section "Downloading TIER 3: Trusted Community Sources"

    # GGUF models from city96 (trusted quantizer)
    log_warn "GGUF models from city96 (trusted community quantizer)..."
    hf_download "city96/FLUX.1-dev-gguf" "flux1-dev-Q8_0.gguf" "$MODELS_DIR/unet" \
        "129032f32224bf7138f16e18673d8008ba5f84c1ec74063bf4511a8bb4cf553d"
    hf_download "city96/t5-v1_1-xxl-encoder-gguf" "t5-v1_1-xxl-encoder-Q8_0.gguf" "$MODELS_DIR/clip" \
        "9ec60f6028534b7fe5af439fcb535d75a68592a9ca3fcdeb175ef89e3ee99825"

    # IP-Adapter from h94 (Tencent research-based)
    log_info "IP-Adapter from h94..."
    hf_download "h94/IP-Adapter" "sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" "$MODELS_DIR/ipadapter" \
        "3f5062b8400c94b7159665b21ba5c62acdcd7682262743d7f2aefedef00e6581"

    # CLIP Vision from fofr (ComfyUI contributor)
    log_info "CLIP Vision encoder from fofr..."
    local clip_vision_dest="$MODELS_DIR/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
    local clip_vision_hash="6ca9667da1ca9e0b0f75e46bb030f7e011f44f86cbfb8d5a36590fcd7507b030"
    if [ ! -f "$clip_vision_dest" ]; then
        hf_download "fofr/comfyui" "clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" "$MODELS_DIR"
        # Handle nested directory structure from HuggingFace download
        if [ -f "$MODELS_DIR/clip_vision/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" ]; then
            mv "$MODELS_DIR/clip_vision/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" "$clip_vision_dest"
            rm -rf "$MODELS_DIR/clip_vision/clip_vision" "$MODELS_DIR/clip_vision/.cache" 2>/dev/null
            log_info "Moved to correct location"
        fi
        verify_hash "$clip_vision_dest" "$clip_vision_hash"
    else
        log_info "Exists: CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
    fi

    # RealVisXL checkpoints from SG161222
    log_info "RealVisXL checkpoints from SG161222..."
    hf_download "SG161222/RealVisXL_V4.0" "RealVisXL_V4.0.safetensors" "$MODELS_DIR/checkpoints" \
        "912c9dc74f5855175c31a7993f863a043ac8dcc31732b324cd05d75cd7e16844"

    # RealVisXL V5.0 Lightning (requires rename for workflow compatibility)
    local realvis_dest="$MODELS_DIR/checkpoints/realvisxlV50_v50LightningBakedvae.safetensors"
    local realvis_hash="fabcadd9330dcc4f9702063428d40b9d4d07168d8acefc819b8d1d9db466b3ec"
    if [ ! -f "$realvis_dest" ]; then
        hf_download "SG161222/RealVisXL_V5.0_Lightning" "RealVisXL_V5.0_Lightning_fp16.safetensors" "$MODELS_DIR/checkpoints"
        if [ -f "$MODELS_DIR/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors" ]; then
            mv "$MODELS_DIR/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors" "$realvis_dest"
            log_info "Renamed to: realvisxlV50_v50LightningBakedvae.safetensors (workflow compatibility)"
            verify_hash "$realvis_dest" "$realvis_hash"
        fi
    else
        log_info "Exists: realvisxlV50_v50LightningBakedvae.safetensors"
    fi

    # UltraSharp upscaler from uwg/Kim2091
    log_warn "4x-UltraSharp upscaler (.pth format - from verified ESRGAN developer)..."
    local upscale_dest="$MODELS_DIR/upscale_models/4x-UltraSharp.pth"
    local upscale_hash="a5812231fc936b42af08a5edba784195495d303d5b3248c24489ef0c4021fe01"
    if [ ! -f "$upscale_dest" ]; then
        hf_download "uwg/upscaler" "ESRGAN/4x-UltraSharp.pth" "$MODELS_DIR/upscale_models"
        # Handle nested directory structure from HuggingFace download
        if [ -f "$MODELS_DIR/upscale_models/ESRGAN/4x-UltraSharp.pth" ]; then
            mv "$MODELS_DIR/upscale_models/ESRGAN/4x-UltraSharp.pth" "$upscale_dest"
            rm -rf "$MODELS_DIR/upscale_models/ESRGAN" "$MODELS_DIR/upscale_models/.cache" 2>/dev/null
            log_info "Flattened ESRGAN/ subdirectory"
        fi
        verify_hash "$upscale_dest" "$upscale_hash"
    else
        log_info "Exists: 4x-UltraSharp.pth"
    fi

    # ========================================================================
    # CUSTOM NODE MODELS (ComfyUI/models/)
    # ========================================================================

    log_section "Downloading Custom Node Models (ComfyUI/models/)"

    log_info "These models use hardcoded paths in their custom nodes."
    log_info "They must be placed in ComfyUI/models/, not /models/."
    echo ""

    # SAM2 from Kijai (ComfyUI node developer)
    log_info "SAM2 from Kijai (for DownloadAndLoadSAM2Model node)..."
    hf_download "Kijai/sam2-safetensors" "sam2.1_hiera_base_plus.safetensors" "$COMFYUI_MODELS/sam2" \
        "eb4b5f725c8b68205aa05bbe6b27efc628b18b4b9c7b9bb8218991b86b9a4932"

    # ========================================================================
    # POST-DOWNLOAD VERIFICATION
    # ========================================================================

    log_section "Post-Download Verification"

    # Count files by format
    local safetensor_count gguf_count pth_count
    safetensor_count=$(find "$MODELS_DIR" "$COMFYUI_MODELS" -name "*.safetensors" 2>/dev/null | wc -l | tr -d ' ')
    gguf_count=$(find "$MODELS_DIR" -name "*.gguf" 2>/dev/null | wc -l | tr -d ' ')
    pth_count=$(find "$MODELS_DIR" -name "*.pth" 2>/dev/null | wc -l | tr -d ' ')

    log_info "Downloaded files by format:"
    log_info "  .safetensors (SAFE):    $safetensor_count files"
    log_warn "  .gguf (from city96):    $gguf_count files"
    log_warn "  .pth (from authors):    $pth_count files"
    echo ""

    # List all downloaded files with sizes
    log_info "All model files:"
    find "$MODELS_DIR" -type f \( -name "*.safetensors" -o -name "*.gguf" -o -name "*.pth" \) -exec sh -c 'echo "    $(basename "$1") ($(du -h "$1" | cut -f1))"' _ {} \;
    echo ""
    log_info "Custom node models:"
    echo "    Florence-2-large/ ($(du -sh "$COMFYUI_MODELS/LLM/Florence-2-large" 2>/dev/null | cut -f1))"
    echo "    sam2.1_hiera_base_plus.safetensors ($(du -h "$COMFYUI_MODELS/sam2/sam2.1_hiera_base_plus.safetensors" 2>/dev/null | cut -f1))"

    # ========================================================================
    # COMPLETION
    # ========================================================================

    log_section "Download Complete"

    echo ""
    log_info "All 16 models downloaded successfully!"
    echo ""
    log_info "Locations:"
    log_info "  External models:     $MODELS_DIR"
    log_info "  Custom node models:  $COMFYUI_MODELS"
    log_info "  Download log:        $LOG_FILE"
    echo ""
    log_info "Next step: ./run.sh"
    echo ""

    echo "=== Download completed: $(date) ===" >> "$LOG_FILE"
}

# ============================================================================
# ENTRY POINT
# ============================================================================

main "$@"
