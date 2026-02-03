# Luma - Architectural Visualization with AI

A ComfyUI-based workflow for generating high-quality architectural visualizations using Stable Diffusion XL and Flux models.

Based on [PH's Archviz x AI ComfyUI Workflow v0.37](https://civitai.com/models/920108/phs-archviz-x-ai-comfyui-workflow-sdxl-flux).

---

## ⚠️ Development Status

**macOS/Apple Silicon development is paused indefinitely.**

### Why

The PH's Archviz workflow requires ~25-30 GB of models loaded simultaneously (SDXL + Flux + ControlNets + T5 encoder + CLIP Vision + SAM2 + Florence2). This workflow was designed for RTX 4090 with 24GB dedicated VRAM + system RAM.

On Apple Silicon's unified memory architecture:
- **CPU RAM = GPU VRAM** (shared memory pool)
- ComfyUI memory flags (`--highvram`, `--lowvram`, `--disable-smart-memory`) have no effect on MPS
- MPS forces `SHARED` vram state regardless of configuration
- "Offload to RAM" is meaningless when VRAM = RAM
- 64GB unified memory is insufficient for simultaneous model loading

The only verified solution (adding `Unload Model` nodes to call `torch.mps.empty_cache()`) requires modifying the workflow graph itself, which is out of scope.

### Recommendation

**Use RunPod with NVIDIA GPU for production development:**
- Dedicated VRAM separate from system RAM
- Memory flags work as documented
- Can use full Q8 models for maximum quality
- RTX 4090 or A100 recommended

### What This Repo Contains

The macOS setup scripts are retained for reference and potential future optimization:
- Local development setup that works for simpler workflows
- Model download scripts (models work on any platform)
- Documentation of MPS limitations discovered during testing

---

## Table of Contents

1. [Development Status](#️-development-status)
2. [Overview](#overview)
3. [Requirements](#requirements)
4. [Quick Start](#quick-start)
5. [Directory Structure](#directory-structure)
6. [Models](#models)
7. [Scripts](#scripts)
8. [Workflow](#workflow)
9. [Apple Silicon Notes](#apple-silicon-notes)
10. [Troubleshooting](#troubleshooting)
11. [Security Notes](#security-notes)

---

## Overview

This project provides setup scripts for the PH's Archviz workflow. The workflow combines:

- **SDXL** for initial image generation with ControlNet guidance
- **Flux** for detail enhancement and refinement
- **Florence-2** for intelligent object detection
- **SAM2** for precise segmentation
- **Depth Anything** for depth map generation
- **IP-Adapter** for style transfer from reference images

All models are pre-downloaded for offline operation. See [Development Status](#️-development-status) for platform recommendations.

---

## Requirements

### Hardware

- **Mac with Apple Silicon** (M1/M2/M3/M4)
- **64GB unified memory** recommended (48GB minimum)
- **50GB free disk space** for models

### Software

- **macOS** 13.0 or later
- **Conda** (Miniconda or Anaconda)
- **Python 3.11+**
- **Git**

---

## Quick Start

### Step 1: Clone this repository

```bash
git clone <repository-url>
cd luma
```

### Step 2: Create and activate the conda environment

```bash
conda create -n luma python=3.11 -y
conda activate luma
```

### Step 3: Clone ComfyUI

ComfyUI is not included in this repository. You must clone it manually:

```bash
cd comfyui
git clone https://github.com/comfyanonymous/ComfyUI.git
```

### Step 4: Install ComfyUI dependencies

```bash
pip install -r ComfyUI/requirements.txt
```

### Step 5: Install custom nodes

This script clones 28 required custom node packages and installs their dependencies:

```bash
./setup.sh
```

### Step 6: Download models (~44 GB)

This script downloads all 16 required models from HuggingFace:

```bash
./download_models.sh
```

### Step 7: Copy the workflow to ComfyUI

```bash
cp ../archviz_ph_sdxlflux_v037_original.json ComfyUI/user/default/workflows/archviz_v037.json
```

### Step 8: Start ComfyUI

```bash
./run.sh
```

### Step 9: Load the workflow

1. Open http://localhost:8188 in your browser
2. Click **Load** in the menu
3. Select `archviz_v037.json`

---

**Important:** Always run `conda activate luma` before running any scripts (`setup.sh`, `download_models.sh`, `run.sh`).

---

## Directory Structure

```
luma/
├── README.md                           # This file
├── archviz_ph_sdxlflux_v037_original.json  # Original workflow (canonical source)
│
├── comfyui/                            # ComfyUI installation and scripts
│   ├── ComfyUI/                        # ComfyUI application
│   │   ├── custom_nodes/               # 28 installed node packages
│   │   ├── models/                     # Custom node models (SAM2, Florence-2)
│   │   │   ├── LLM/Florence-2-large/   # Vision-language model
│   │   │   └── sam2/                   # Segmentation model
│   │   ├── user/default/workflows/     # Working workflows directory
│   │   │   └── archviz_v037.json       # Workflow copy for ComfyUI UI
│   │   └── extra_model_paths.yaml      # Model path configuration
│   │
│   ├── download_models.sh              # Model download script (16 models)
│   ├── run.sh                          # ComfyUI startup script
│   └── setup.sh                        # Initial setup script
│
├── models/                             # Main model storage (~43 GB)
│   ├── checkpoints/                    # SDXL base models
│   ├── clip/                           # Text encoders
│   ├── clip_vision/                    # Vision encoders
│   ├── controlnet/                     # ControlNet models
│   ├── depth/                          # Depth estimation models
│   ├── ipadapter/                      # IP-Adapter models
│   ├── unet/                           # Flux diffusion model
│   ├── upscale_models/                 # Upscaler models
│   └── vae/                            # VAE models
│
└── phsArchvizXAIComfyui_v037/          # Original workflow package (reference)
    ├── archviz_ph_sdxlflux_v037.json   # Workflow from Civitai
    ├── README.txt                      # Original instructions
    └── assets/                         # Sample images and references
```

### Workflow File Locations

| Location | Purpose |
|----------|---------|
| `/archviz_ph_sdxlflux_v037_original.json` | Canonical source - the original unmodified workflow |
| `/comfyui/ComfyUI/user/default/workflows/archviz_v037.json` | Working copy loaded by ComfyUI UI |
| `/phsArchvizXAIComfyui_v037/archviz_ph_sdxlflux_v037.json` | Original from Civitai download (reference) |

---

## Models

### Model Inventory (16 total)

All models are downloaded via `download_models.sh` from verified HuggingFace sources.

#### Location: `/models/` (14 models, ~42 GB)

| Model | Size | Purpose |
|-------|------|---------|
| `RealVisXL_V4.0.safetensors` | 6.5 GB | Primary SDXL checkpoint |
| `realvisxlV50_v50LightningBakedvae.safetensors` | 6.5 GB | Fast SDXL (4-step Lightning) |
| `flux1-dev-Q8_0.gguf` | 12 GB | Flux diffusion model (Q8 quantization) |
| `t5-v1_1-xxl-encoder-Q8_0.gguf` | 4.7 GB | T5-XXL text encoder for Flux |
| `clip_l.safetensors` | 235 MB | CLIP-L text encoder |
| `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 2.4 GB | CLIP Vision for IP-Adapter |
| `diffusers_xl_canny_full.safetensors` | 2.3 GB | ControlNet - edge detection |
| `diffusers_xl_depth_full.safetensors` | 2.3 GB | ControlNet - depth |
| `thibaud_xl_openpose.safetensors` | 2.3 GB | ControlNet - pose |
| `ip-adapter-plus_sdxl_vit-h.safetensors` | 808 MB | IP-Adapter style transfer |
| `depth_anything_v2_vitl.pth` | 1.2 GB | Depth Anything V2 |
| `depth_anything_vitl14.pth` | 1.2 GB | Depth Anything V1 |
| `4x-UltraSharp.pth` | 64 MB | ESRGAN 4x upscaler |
| `ae.safetensors` | 320 MB | Flux VAE |

#### Location: `ComfyUI/models/` (2 models, ~1.8 GB)

These models are placed here because their custom nodes check hardcoded paths.

| Model | Size | Purpose |
|-------|------|---------|
| `sam2/sam2.1_hiera_base_plus.safetensors` | 308 MB | Segment Anything 2 |
| `LLM/Florence-2-large/` | 1.5 GB | Florence-2 vision-language model |

### Model Sources

All models are from verified sources:

- **Tier 1 (Official):** Black Forest Labs, Microsoft, ComfyUI maintainer
- **Tier 2 (Paper Authors):** lllyasviel (ControlNet), LiheYoung (Depth Anything)
- **Tier 3 (Trusted Community):** city96, SG161222, Kijai, h94

See `download_models.sh` header for complete source documentation.

### Re-downloading Models

To re-download all models:

```bash
cd comfyui
./download_models.sh
```

The script skips existing files, so it's safe to run multiple times.

---

## Scripts

### `download_models.sh`

Downloads all 16 required models from HuggingFace.

```bash
./download_models.sh
```

**Features:**
- Comprehensive MODEL MANIFEST documenting every file
- SHA256 verification for critical files
- Skips existing downloads (idempotent)
- Security audit summary at startup
- Logs all activity to `download_log.txt`

### `run.sh`

Starts the ComfyUI server.

```bash
./run.sh              # Localhost only (default - secure)
./run.sh --network    # Allow LAN connections (trusted networks only)
```

**Flags applied:**
- `--force-fp16` - Reduces memory usage
- `--use-pytorch-cross-attention` - More compatible with MPS backend

### `setup.sh`

Installs all required custom nodes for the workflow. Clones node packages into `ComfyUI/custom_nodes/` and installs their Python dependencies via pip.

**Note:** This script does NOT create the conda environment or clone ComfyUI. Those steps must be done first (see Quick Start steps 2-4).

```bash
./setup.sh
```

---

## Workflow

### Workflow Architecture

The 298-node workflow operates in three stages:

#### Stage 1: SDXL Generation
- Loads RealVisXL checkpoint
- Applies ControlNet conditioning (depth, canny, pose)
- Uses IP-Adapter for style reference
- Generates initial image with KSampler

#### Stage 2: Flux Detailing
- Loads Flux GGUF model with DualCLIP encoding
- Florence-2 detects objects for targeted enhancement
- SAM2 creates precise masks
- SamplerCustomAdvanced refines details

#### Stage 3: Upscale & Refinement
- UltimateSDUpscale for resolution increase
- Image compositing and masking
- Final output

### Loading the Workflow

1. Start ComfyUI: `./run.sh`
2. Open http://localhost:8188
3. Click "Load" in the menu
4. Select `archviz_v037.json`

### Workflow Inputs

The workflow expects:
- **Input image** - Base architectural render or photo
- **Text prompt** - Description of desired output
- **Reference image** (optional) - Style reference for IP-Adapter

---

## Apple Silicon Notes

> **Note:** macOS development is paused. See [Development Status](#️-development-status).

### Memory Architecture Limitations

On Apple Silicon, CPU RAM and GPU VRAM share the same unified memory pool. This creates fundamental limitations for workflows designed for dedicated VRAM systems:

| Component | Memory Usage |
|-----------|-------------|
| Flux Q8 | ~12 GB |
| SDXL Checkpoint | ~6.5 GB |
| ControlNets (3x) | ~7 GB |
| T5-XXL Encoder | ~5 GB |
| Other models | ~5 GB |
| **Total models** | **~35 GB** |

When all models load simultaneously (as this workflow requires), the system exceeds available memory even on 64GB machines due to:
- OS and application overhead (~8-10 GB)
- PyTorch memory fragmentation
- MPS memory management overhead

### Flags That Have No Effect on MPS

ComfyUI memory management flags are designed for CUDA and have no effect on Apple Silicon:

- `--highvram`, `--lowvram`, `--novram` - MPS forces `SHARED` vram state regardless
- `--disable-smart-memory` - Not applicable to unified memory
- `--cache-none` - Does not address simultaneous model loading

### Environment Variable

```bash
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
```

This allows PyTorch to use all available unified memory. Set automatically by `run.sh`.

### Flags to Avoid

- `--bf16` - Not fully supported on MPS backend

### Known MPS Limitations

1. **bf16 not supported** - Uses fp16 fallback
2. **Some operations fall back to CPU** - Normal behavior
3. **Memory fragmentation** - MPS doesn't release memory as efficiently as CUDA
4. **No memory offloading** - "Offload to RAM" meaningless when VRAM = RAM

---

## Troubleshooting

### "CUDA not available" errors

This is expected on Mac. The SAM2 and Florence-2 nodes should use `mps` device, not `cuda`. The workflow has been updated for this.

### Out of memory errors

1. Close other applications
2. Reduce upscale factor in UltimateSDUpscale node
3. Consider using Q5 Flux quantization (not included by default)

### Model not found errors

Run the download script:
```bash
cd comfyui
./download_models.sh
```

### Slow generation

MPS is 3-5x slower than CUDA. Expected times on M4 Max:
- SDXL generation: 30-60 seconds
- Flux detailing: 60-120 seconds
- Full workflow: 3-5 minutes

### Custom node errors

Update custom nodes via ComfyUI Manager or:
```bash
cd ComfyUI/custom_nodes/<node-name>
git pull
```

---

## Security Notes

### Network Security

ComfyUI binds to `127.0.0.1` by default. Known vulnerabilities:
- CVE-2025-6092: Remote code execution via malicious workflow
- CVE-2026-22777: Path traversal in file upload

Only use `--network` flag on trusted networks.

### Model Security

File formats and trust levels:
- `.safetensors` - **SAFE** - Cannot execute arbitrary code
- `.gguf` - **CAUTION** - Binary format, potential parsing vulnerabilities
- `.pth` - **CAUTION** - Uses Python pickle, can execute code on load

All `.pth` and `.gguf` files in this project are from verified original authors or trusted community members.

---

## Credits

- **PH** - Original Archviz workflow creator ([Civitai](https://civitai.com/models/920108))
- **Black Forest Labs** - Flux model
- **Stability AI** - SDXL foundation
- **ComfyUI** - Node-based interface
- **Microsoft** - Florence-2
- **Meta AI** - SAM2

---

## License

This project configuration is provided as-is. Individual models have their own licenses - check each model's HuggingFace page for details.
