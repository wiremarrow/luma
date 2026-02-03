#!/bin/bash
# ============================================================================
# MODEL DOWNLOAD SCRIPT - RUNPOD EDITION
# PH's Archviz x AI ComfyUI Workflow v0.37
# ============================================================================
#
# PURPOSE
# -------
# Downloads all 16 models required for the PH's Archviz workflow directly to
# a RunPod network volume. Uses huggingface-cli with post-download flattening
# to handle nested directory structures.
#
# USAGE
# -----
#   1. Create a temporary Pod with the network volume attached
#   2. Copy this script: scp download_models_runpod.sh root@<pod-ip>:/root/
#   3. Run: bash /root/download_models_runpod.sh
#   4. Wait ~30-60 minutes
#   5. Terminate Pod (models persist on volume)
#
# SECURITY
# --------
# All downloads include SHA256 hash verification matching the local macOS
# script (comfyui/download_models.sh). Hashes are verified after download
# to ensure integrity.
#
# ============================================================================

set -e
set -o pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

VOLUME_PATH="/workspace"
MODELS_PATH="$VOLUME_PATH/models"
LOG_FILE="$VOLUME_PATH/download_log.txt"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# LOGGING
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

verify_hash() {
    local file="$1"
    local expected_hash="$2"

    if [ -z "$expected_hash" ]; then
        return 0
    fi

    local actual_hash
    actual_hash=$(sha256sum "$file" | cut -d' ' -f1)

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
# DOWNLOAD FUNCTIONS
# ============================================================================

# Download single file with optional hash verification
# Usage: hf_download <repo> <file> <dest_dir> [expected_hash]
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

    huggingface-cli download "$repo" "$file" \
        --local-dir "$dest_dir" \
        --local-dir-use-symlinks False

    if [ -n "$expected_hash" ]; then
        verify_hash "$dest_file" "$expected_hash"
    fi
}

# Download full repository
# Usage: hf_download_repo <repo> <dest_dir>
hf_download_repo() {
    local repo="$1"
    local dest_dir="$2"

    if [ -d "$dest_dir" ] && [ -f "$dest_dir/model.safetensors" ]; then
        log_info "Exists: $(basename "$dest_dir")/"
        return 0
    fi

    log_info "Downloading: $repo (full repository)"
    mkdir -p "$dest_dir"

    huggingface-cli download "$repo" \
        --local-dir "$dest_dir" \
        --local-dir-use-symlinks False
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "============================================================================"
    echo "  RUNPOD MODEL DOWNLOAD - PH's Archviz ComfyUI Workflow"
    echo "============================================================================"
    echo ""

    # Check if already downloaded
    if [ -f "$VOLUME_PATH/.models_downloaded" ]; then
        log_warn "Models already downloaded. Delete .models_downloaded to re-download."
        log_warn "  rm $VOLUME_PATH/.models_downloaded"
        exit 0
    fi

    # Initialize log
    echo "=== Download started: $(date) ===" >> "$LOG_FILE"

    # Install huggingface-cli if needed
    if ! command -v huggingface-cli &> /dev/null; then
        log_info "Installing huggingface-hub..."
        pip install -q huggingface-hub
    fi

    # ========================================================================
    # CREATE DIRECTORY STRUCTURE
    # ========================================================================

    log_section "Creating Directory Structure"

    mkdir -p "$MODELS_PATH"/{checkpoints,clip,clip_vision,controlnet,ipadapter,unet,vae,upscale_models,depth,sam2}
    mkdir -p "$VOLUME_PATH/LLM"
    mkdir -p "$VOLUME_PATH/input"

    log_info "Models directory: $MODELS_PATH"
    log_info "LLM directory: $VOLUME_PATH/LLM"
    log_info "Input directory: $VOLUME_PATH/input"

    # ========================================================================
    # TIER 1: OFFICIAL ORGANIZATION SOURCES
    # ========================================================================

    log_section "Downloading TIER 1: Official Organization Sources"

    # VAE from Black Forest Labs (Flux creators)
    log_info "VAE from Black Forest Labs..."
    hf_download "black-forest-labs/FLUX.1-schnell" "ae.safetensors" "$MODELS_PATH/vae" \
        "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38"

    # CLIP-L from ComfyUI maintainer
    log_info "CLIP-L from ComfyUI maintainer..."
    hf_download "comfyanonymous/flux_text_encoders" "clip_l.safetensors" "$MODELS_PATH/clip" \
        "660c6f5b1abae9dc498ac2d21e1347d2abdb0cf6c0c0c8576cd796491d9a6cdd"

    # Florence-2 from Microsoft (full repository)
    log_info "Florence-2-large from Microsoft..."
    hf_download_repo "microsoft/Florence-2-large" "$VOLUME_PATH/LLM/Florence-2-large"

    # Remove redundant pytorch_model.bin
    if [ -f "$VOLUME_PATH/LLM/Florence-2-large/pytorch_model.bin" ]; then
        rm -f "$VOLUME_PATH/LLM/Florence-2-large/pytorch_model.bin"
        log_info "Removed redundant pytorch_model.bin"
    fi

    # Verify Florence-2
    local florence_model="$VOLUME_PATH/LLM/Florence-2-large/model.safetensors"
    if [ -f "$florence_model" ]; then
        verify_hash "$florence_model" "4f38ce741c6b71188fe2b3419a55e11917a8a7b321ae2e63c61da0191b0ebad7"
    fi

    # ========================================================================
    # TIER 2: ORIGINAL PAPER AUTHORS
    # ========================================================================

    log_section "Downloading TIER 2: Original Paper Authors"

    # ControlNet models from lllyasviel (paper author)
    log_info "ControlNet models from lllyasviel..."
    hf_download "lllyasviel/sd_control_collection" "diffusers_xl_canny_full.safetensors" "$MODELS_PATH/controlnet" \
        "80664d80e3f233371cb6921110d0a6b7a40c01571905463f9dde5637e7894ed3"
    hf_download "lllyasviel/sd_control_collection" "diffusers_xl_depth_full.safetensors" "$MODELS_PATH/controlnet" \
        "8ba4dfaa1958f1f68e5dc7f9839f9ef4e153aef0d330291e5cf966c925f97477"
    hf_download "lllyasviel/sd_control_collection" "thibaud_xl_openpose.safetensors" "$MODELS_PATH/controlnet" \
        "9e070426568a3c60c128ffb98c66cdc7a0ea21d0d8abb86f73564aaf2e0c6f42"

    # Depth Anything from LiheYoung (paper author)
    log_warn "Depth Anything models (.pth format - from original paper author)..."
    hf_download "depth-anything/Depth-Anything-V2-Large" "depth_anything_v2_vitl.pth" "$MODELS_PATH/depth" \
        "a7ea19fa0ed99244e67b624c72b8580b7e9553043245905be58796a608eb9345"

    # Depth Anything V1 (direct wget - different URL structure)
    local depth_v1_file="$MODELS_PATH/depth/depth_anything_vitl14.pth"
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
    hf_download "city96/FLUX.1-dev-gguf" "flux1-dev-Q8_0.gguf" "$MODELS_PATH/unet" \
        "129032f32224bf7138f16e18673d8008ba5f84c1ec74063bf4511a8bb4cf553d"
    hf_download "city96/t5-v1_1-xxl-encoder-gguf" "t5-v1_1-xxl-encoder-Q8_0.gguf" "$MODELS_PATH/clip" \
        "9ec60f6028534b7fe5af439fcb535d75a68592a9ca3fcdeb175ef89e3ee99825"

    # IP-Adapter from h94 (huggingface-cli + flatten)
    log_info "IP-Adapter from h94..."
    local ipadapter_dest="$MODELS_PATH/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors"
    local ipadapter_hash="3f5062b8400c94b7159665b21ba5c62acdcd7682262743d7f2aefedef00e6581"
    if [ ! -f "$ipadapter_dest" ]; then
        hf_download "h94/IP-Adapter" "sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" "$MODELS_PATH/ipadapter"
        # Flatten nested sdxl_models/ directory
        if [ -f "$MODELS_PATH/ipadapter/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" ]; then
            mv "$MODELS_PATH/ipadapter/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" "$ipadapter_dest"
            rm -rf "$MODELS_PATH/ipadapter/sdxl_models" "$MODELS_PATH/ipadapter/.cache" 2>/dev/null
            log_info "Flattened sdxl_models/ subdirectory"
        fi
        verify_hash "$ipadapter_dest" "$ipadapter_hash"
    else
        log_info "Exists: ip-adapter-plus_sdxl_vit-h.safetensors"
    fi

    # CLIP Vision from fofr (huggingface-cli + flatten)
    log_info "CLIP Vision encoder from fofr..."
    local clip_vision_dest="$MODELS_PATH/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
    local clip_vision_hash="6ca9667da1ca9e0b0f75e46bb030f7e011f44f86cbfb8d5a36590fcd7507b030"
    if [ ! -f "$clip_vision_dest" ]; then
        hf_download "fofr/comfyui" "clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" "$MODELS_PATH"
        # Flatten nested clip_vision/ directory
        if [ -f "$MODELS_PATH/clip_vision/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" ]; then
            mv "$MODELS_PATH/clip_vision/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" "$clip_vision_dest"
            rm -rf "$MODELS_PATH/clip_vision/clip_vision" "$MODELS_PATH/clip_vision/.cache" 2>/dev/null
            log_info "Flattened clip_vision/ subdirectory"
        fi
        verify_hash "$clip_vision_dest" "$clip_vision_hash"
    else
        log_info "Exists: CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
    fi

    # RealVisXL checkpoints from SG161222
    log_info "RealVisXL checkpoints from SG161222..."
    hf_download "SG161222/RealVisXL_V4.0" "RealVisXL_V4.0.safetensors" "$MODELS_PATH/checkpoints" \
        "912c9dc74f5855175c31a7993f863a043ac8dcc31732b324cd05d75cd7e16844"

    # RealVisXL V5.0 Lightning (requires rename)
    local realvis_dest="$MODELS_PATH/checkpoints/realvisxlV50_v50LightningBakedvae.safetensors"
    local realvis_hash="fabcadd9330dcc4f9702063428d40b9d4d07168d8acefc819b8d1d9db466b3ec"
    if [ ! -f "$realvis_dest" ]; then
        hf_download "SG161222/RealVisXL_V5.0_Lightning" "RealVisXL_V5.0_Lightning_fp16.safetensors" "$MODELS_PATH/checkpoints"
        if [ -f "$MODELS_PATH/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors" ]; then
            mv "$MODELS_PATH/checkpoints/RealVisXL_V5.0_Lightning_fp16.safetensors" "$realvis_dest"
            log_info "Renamed to: realvisxlV50_v50LightningBakedvae.safetensors"
            verify_hash "$realvis_dest" "$realvis_hash"
        fi
    else
        log_info "Exists: realvisxlV50_v50LightningBakedvae.safetensors"
    fi

    # UltraSharp upscaler from uwg/Kim2091 (huggingface-cli + flatten)
    log_warn "4x-UltraSharp upscaler (.pth format)..."
    local upscale_dest="$MODELS_PATH/upscale_models/4x-UltraSharp.pth"
    local upscale_hash="a5812231fc936b42af08a5edba784195495d303d5b3248c24489ef0c4021fe01"
    if [ ! -f "$upscale_dest" ]; then
        hf_download "uwg/upscaler" "ESRGAN/4x-UltraSharp.pth" "$MODELS_PATH/upscale_models"
        # Flatten nested ESRGAN/ directory
        if [ -f "$MODELS_PATH/upscale_models/ESRGAN/4x-UltraSharp.pth" ]; then
            mv "$MODELS_PATH/upscale_models/ESRGAN/4x-UltraSharp.pth" "$upscale_dest"
            rm -rf "$MODELS_PATH/upscale_models/ESRGAN" "$MODELS_PATH/upscale_models/.cache" 2>/dev/null
            log_info "Flattened ESRGAN/ subdirectory"
        fi
        verify_hash "$upscale_dest" "$upscale_hash"
    else
        log_info "Exists: 4x-UltraSharp.pth"
    fi

    # SAM2 from Kijai
    log_info "SAM2 from Kijai..."
    hf_download "Kijai/sam2-safetensors" "sam2.1_hiera_base_plus.safetensors" "$MODELS_PATH/sam2" \
        "eb4b5f725c8b68205aa05bbe6b27efc628b18b4b9c7b9bb8218991b86b9a4932"

    # ========================================================================
    # CLEANUP AND VERIFICATION
    # ========================================================================

    log_section "Post-Download Verification"

    # Clean up any remaining .cache directories
    find "$MODELS_PATH" -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true

    # Verify flat directory structure (no nested subdirectories)
    log_info "Verifying flat directory structure..."
    local errors=0

    # Check IP-Adapter is flat
    if [ -d "$MODELS_PATH/ipadapter/sdxl_models" ]; then
        log_error "IP-Adapter nested directory not flattened!"
        errors=$((errors + 1))
    fi

    # Check CLIP Vision is flat
    if [ -d "$MODELS_PATH/clip_vision/clip_vision" ]; then
        log_error "CLIP Vision nested directory not flattened!"
        errors=$((errors + 1))
    fi

    # Check UltraSharp is flat
    if [ -d "$MODELS_PATH/upscale_models/ESRGAN" ]; then
        log_error "UltraSharp nested directory not flattened!"
        errors=$((errors + 1))
    fi

    if [ $errors -eq 0 ]; then
        log_info "All directories properly flattened"
    else
        log_error "$errors directory structure errors found!"
        exit 1
    fi

    # Count files
    local safetensor_count gguf_count pth_count
    safetensor_count=$(find "$MODELS_PATH" "$VOLUME_PATH/LLM" -name "*.safetensors" 2>/dev/null | wc -l | tr -d ' ')
    gguf_count=$(find "$MODELS_PATH" -name "*.gguf" 2>/dev/null | wc -l | tr -d ' ')
    pth_count=$(find "$MODELS_PATH" -name "*.pth" 2>/dev/null | wc -l | tr -d ' ')

    log_info "Downloaded files by format:"
    log_info "  .safetensors (SAFE):    $safetensor_count files"
    log_warn "  .gguf (from city96):    $gguf_count files"
    log_warn "  .pth (from authors):    $pth_count files"

    # Mark as complete
    touch "$VOLUME_PATH/.models_downloaded"

    # ========================================================================
    # COMPLETION
    # ========================================================================

    log_section "Download Complete"

    echo ""
    log_info "All 16 models downloaded successfully!"
    echo ""
    log_info "Verification commands:"
    echo "  ls -lah $MODELS_PATH/*/"
    echo "  ls $MODELS_PATH/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors"
    echo "  ls $MODELS_PATH/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
    echo "  ls $MODELS_PATH/upscale_models/4x-UltraSharp.pth"
    echo "  ls $VOLUME_PATH/LLM/Florence-2-large/model.safetensors"
    echo ""
    log_info "Next steps:"
    echo "  1. Upload input images to: $VOLUME_PATH/input/"
    echo "  2. Terminate this Pod (models persist on volume)"
    echo "  3. Create production Pod with luma-comfyui Docker image"
    echo ""
    log_info "Download log: $LOG_FILE"

    echo "=== Download completed: $(date) ===" >> "$LOG_FILE"
}

# ============================================================================
# ENTRY POINT
# ============================================================================

main "$@"
