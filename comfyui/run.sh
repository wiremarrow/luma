#!/usr/bin/env bash
# ============================================================================
# COMFYUI RUN SCRIPT
# PH's Archviz x AI Workflow v0.37
# Version: 1.0.0
# ============================================================================
#
# PURPOSE
# -------
# Starts the ComfyUI server with optimizations for Apple Silicon (M-series)
# Macs with unified memory architecture. This script is the recommended way
# to launch ComfyUI for the PH's Archviz workflow.
#
# USAGE
# -----
#   ./run.sh              Start server (localhost only - secure default)
#   ./run.sh --network    Start server with LAN access (trusted networks only)
#
# PREREQUISITES
# -------------
#   - macOS with Apple Silicon (M1/M2/M3/M4)
#   - Conda environment 'luma' with Python 3.11+
#   - ComfyUI installed at ./ComfyUI/
#   - Models downloaded via ./download_models.sh
#
# APPLE SILICON OPTIMIZATIONS
# ---------------------------
# The following flags are optimized for unified memory architecture:
#
#   --highvram
#     Keeps models loaded in memory. On unified memory systems, there's no
#     benefit to offloading models (VRAM and RAM are the same pool).
#     This reduces latency between operations.
#
#   --force-fp16
#     Uses FP16 precision for activations. Reduces memory usage by ~50%
#     compared to FP32 with minimal quality impact. Note: bf16 is not
#     fully supported on MPS backend.
#
#   --use-pytorch-cross-attention
#     Uses PyTorch's native cross-attention implementation instead of
#     xformers. More compatible with MPS backend and avoids potential
#     memory issues.
#
# FLAGS TO AVOID on Apple Silicon:
#   --lowvram, --novram  - Counterproductive on unified memory
#   --bf16               - Not fully supported on MPS
#
# ENVIRONMENT VARIABLES
# ---------------------
#   PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
#     Allows PyTorch to use maximum available unified memory.
#     Source: https://pytorch.org/docs/stable/notes/mps.html
#
# NETWORK SECURITY
# ----------------
# By default, ComfyUI binds to 127.0.0.1 (localhost only) to prevent
# unauthorized network access. Known vulnerabilities include:
#
#   - CVE-2025-6092: Remote code execution via malicious workflow
#   - CVE-2026-22777: Path traversal in file upload
#
# Use --network flag only on trusted networks where you control all
# connected devices.
#
# WORKFLOW
# --------
# 1. Conda environment 'luma' is activated
# 2. ComfyUI server starts on port 8188
# 3. Open http://localhost:8188 in browser
# 4. Load archviz_ph_sdxlflux_v037.json workflow
# 5. Queue prompt to generate images
#
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFYUI_DIR="$SCRIPT_DIR/ComfyUI"
DEFAULT_PORT="8188"

# ============================================================================
# TERMINAL COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ============================================================================
# VALIDATION
# ============================================================================

# Verify ComfyUI installation
if [ ! -d "$COMFYUI_DIR" ]; then
    echo -e "${RED}[ERROR]${NC} ComfyUI directory not found at $COMFYUI_DIR"
    echo ""
    echo "Please run setup.sh first to install ComfyUI."
    exit 1
fi

# Verify main.py exists
if [ ! -f "$COMFYUI_DIR/main.py" ]; then
    echo -e "${RED}[ERROR]${NC} ComfyUI main.py not found"
    echo ""
    echo "ComfyUI installation appears incomplete. Run setup.sh to reinstall."
    exit 1
fi

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

LISTEN_ADDR="127.0.0.1"

if [[ "$1" == "--network" ]]; then
    LISTEN_ADDR="0.0.0.0"
    echo -e "${YELLOW}[WARN]${NC} Network mode enabled - binding to 0.0.0.0"
    echo -e "${YELLOW}[WARN]${NC} ComfyUI will be accessible from your local network."
    echo -e "${YELLOW}[WARN]${NC} Only use this on trusted networks."
    echo ""
    shift  # Remove --network from remaining args
fi

# ============================================================================
# STARTUP BANNER
# ============================================================================

echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}  PH's Archviz x AI - ComfyUI Server${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo -e "${GREEN}[INFO]${NC} Listen address: $LISTEN_ADDR:$DEFAULT_PORT"
echo -e "${GREEN}[INFO]${NC} ComfyUI path:   $COMFYUI_DIR"
echo ""

# ============================================================================
# CONDA ENVIRONMENT
# ============================================================================

echo -e "${GREEN}[INFO]${NC} Activating conda environment 'luma'..."

# Initialize conda
if ! eval "$(conda shell.bash hook)" 2>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Failed to initialize conda"
    echo ""
    echo "Ensure conda is installed and available in your PATH."
    exit 1
fi

# Activate environment
if ! conda activate luma 2>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Failed to activate conda environment 'luma'"
    echo ""
    echo "Create the environment with:"
    echo "  conda create -n luma python=3.11"
    echo "  conda activate luma"
    echo "  pip install -r ComfyUI/requirements.txt"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Conda environment activated"
echo ""

# ============================================================================
# APPLE SILICON MEMORY OPTIMIZATION
# ============================================================================

# Allow PyTorch MPS backend to use maximum available unified memory.
# Setting to 0.0 disables the watermark limit entirely.
# Reference: https://pytorch.org/docs/stable/notes/mps.html
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

# ============================================================================
# START COMFYUI SERVER
# ============================================================================

echo -e "${GREEN}[INFO]${NC} Starting ComfyUI server..."
echo -e "${GREEN}[INFO]${NC} Flags: --highvram --use-pytorch-cross-attention --force-fp16"
echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────${NC}"
echo ""

cd "$COMFYUI_DIR"

python main.py \
    --listen "$LISTEN_ADDR" \
    --port "$DEFAULT_PORT" \
    --highvram \
    --use-pytorch-cross-attention \
    --force-fp16 \
    "$@"

# ============================================================================
# SHUTDOWN
# ============================================================================

echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${GREEN}[INFO]${NC} ComfyUI server stopped."
