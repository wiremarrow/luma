# ComfyUI Optimization Agent Prompt

## Mission

Get PH's Archviz x AI ComfyUI workflow running optimally on a **64GB unified memory Mac (Apple Silicon)**. Focus exclusively on:
1. Making the workflow run successfully
2. Optimizing for performance on MPS backend
3. Maximizing quality within hardware constraints
4. Cleaning up unused models to save disk space

**Ignore:** Frontend code, web interfaces, anything outside ComfyUI workflow optimization.

---

## Hardware Context

- **Machine:** Mac with 64GB unified memory (Apple Silicon - likely M2/M3/M4 Max)
- **Backend:** MPS (Metal Performance Shaders), NOT CUDA
- **Key Limitation:** MPS is 3-5x slower than RTX 4090 for Stable Diffusion tasks
- **Advantage:** Unified memory means large models can load (no 24GB VRAM limit)

### MPS-Specific Issues (Documented)

1. **bf16 not fully supported** - Forces fp32 fallback, doubling memory usage
2. **Float8 not supported** - Error: "Trying to convert Float8_e4m3fn to the MPS backend"
3. **Some operations fall back to CPU** - Requires: `PYTORCH_ENABLE_MPS_FALLBACK=1`
4. **Memory fragmentation** - MPS doesn't release memory as efficiently as CUDA

---

## Directory Structure

```
/Users/admin/code/luma/
├── comfyui/
│   ├── ComfyUI/                    # Main ComfyUI installation
│   │   ├── models/                 # Secondary models location
│   │   │   ├── LLM/Florence-2-large/  # Florence-2 model (2.8GB)
│   │   │   └── sam2/               # SAM2 models (462MB)
│   │   ├── custom_nodes/           # 29 custom node packages installed
│   │   └── extra_model_paths.yaml  # Model path configuration
│   └── tutorials/
│       └── AIxArchviz_BASIC_ComfyUI/  # 39 basic tutorial workflows
├── models/                         # Primary models location (51GB)
│   ├── checkpoints/                # SDXL models
│   ├── clip/                       # Text encoders
│   ├── clip_vision/                # Vision encoders
│   ├── controlnet/                 # ControlNet models
│   ├── depth/                      # Depth estimation models
│   ├── ipadapter/                  # IP-Adapter models
│   ├── sam2/                       # SAM2 segmentation
│   ├── unet/                       # Flux GGUF models
│   ├── upscale_models/             # Upscalers
│   └── vae/                        # VAE models
└── phsArchvizXAIComfyui_v037/      # Main workflow package
    └── archviz_ph_sdxlflux_v037.json  # 298-node workflow
```

---

## Models Inventory

### REQUIRED MODELS (Used by workflow)

| Model | Path | Size | Purpose |
|-------|------|------|---------|
| `flux1-dev-Q5_K_S.gguf` | `models/unet/` | 7.7GB | Flux diffusion (quantized for memory) |
| `t5-v1_1-xxl-encoder-Q8_0.gguf` | `models/clip/` | 4.7GB | T5 text encoder for Flux |
| `clip_l.safetensors` | `models/clip/` | 235MB | CLIP-L text encoder |
| `RealVisXL_V4.0.safetensors` | `models/checkpoints/` | 6.5GB | SDXL checkpoint (main) |
| `realvisxlV50_v50LightningBakedvae.safetensors` | `models/checkpoints/` | 6.5GB | SDXL Lightning (fast) |
| `diffusers_xl_canny_full.safetensors` | `models/controlnet/` | 2.3GB | ControlNet canny edges |
| `diffusers_xl_depth_full.safetensors` | `models/controlnet/` | 2.3GB | ControlNet depth |
| `thibaud_xl_openpose.safetensors` | `models/controlnet/` | 2.3GB | ControlNet pose |
| `ip-adapter-plus_sdxl_vit-h.safetensors` | `models/ipadapter/` | 808MB | IP-Adapter style transfer |
| `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | `models/clip_vision/` | 2.4GB | CLIP Vision for IP-Adapter |
| `ae.safetensors` | `models/vae/` | 320MB | Flux VAE |
| `4x-UltraSharp.pth` | `models/upscale_models/` | 64MB | ESRGAN upscaler |
| `sam2.1_hiera_base_plus.safetensors` | `models/sam2/` | 308MB | SAM2 segmentation |
| `depth_anything_vitl14.pth` | `models/depth/` | 1.2GB | Depth Anything V1 |
| `depth_anything_v2_vitl.pth` | `models/depth/` | 1.2GB | Depth Anything V2 |
| Florence-2-large | `ComfyUI/models/LLM/` | 2.8GB | Florence-2 vision model |

**Total Required:** ~42GB

### CAN BE DELETED (Unused)

| Model | Path | Size | Reason |
|-------|------|------|--------|
| `flux1-dev-Q8_0.gguf` | `models/unet/` | 12GB | Replaced by Q5_K_S for memory optimization |
| `sam2.1_hiera_base_plus-fp16.safetensors` | `ComfyUI/models/sam2/` | 154MB | Duplicate/unused variant |
| `pytorch_model.bin` | `ComfyUI/models/LLM/Florence-2-large/` | 1.5GB | Redundant - `model.safetensors` is preferred |

**Potential Savings:** ~13.7GB

### DUPLICATES TO CONSOLIDATE

- `sam2.1_hiera_base_plus.safetensors` exists in BOTH:
  - `/Users/admin/code/luma/models/sam2/` (308MB)
  - `/Users/admin/code/luma/comfyui/ComfyUI/models/sam2/` (308MB)

  Only ONE is needed. Check which path the workflow uses.

---

## Workflow Architecture

The 298-node workflow (`archviz_ph_sdxlflux_v037.json`) has 3 stages:

### Stage 1: SDXL Generation
- Load SDXL checkpoint (RealVisXL)
- Text encoding (CLIPTextEncode)
- ControlNet conditioning (depth, canny, pose)
- IPAdapter for style reference
- KSampler generation

### Stage 2: Flux Detailing
- Load Flux GGUF (Q5_K_S)
- DualCLIP encoding (T5-XXL + clip_l)
- FluxGuidance conditioning
- SamplerCustomAdvanced
- Florence2 + SAM2 object detection

### Stage 3: Upscale & Refinement
- UltimateSDUpscale (currently set to 1.5x, originally 4x)
- Image compositing & masking
- Final output

---

## Known Issues & Fixes Applied

### 1. SAM2 CUDA Error
**Error:** `Torch not compiled with CUDA enabled`
**Fix:** Change SAM2 node `device` from `cuda` to `mps`
**Location:** Nodes 107, 234 in workflow JSON - `widgets_values` array

### 2. Memory Optimization
**Original:** `flux1-dev-Q8_0.gguf` (12GB)
**Optimized:** `flux1-dev-Q5_K_S.gguf` (7.7GB)
**Trade-off:** Slight quality reduction for ~4GB memory savings

### 3. Upscale Reduction
**Original:** 4x upscale
**Optimized:** 1.5x upscale
**Reason:** Reduces peak memory during upscale pass

### 4. Broken UnloadModel Nodes
**Issue:** "custom nodes you haven't installed yet" error
**Fix:** Removed UnloadModel nodes (IDs 788, 789) - they were corrupted

---

## Configuration Files

### extra_model_paths.yaml
```yaml
luma:
    base_path: /Users/admin/code/luma/models/
    is_default: true
    checkpoints: checkpoints/
    clip: clip/
    clip_vision: clip_vision/
    controlnet: controlnet/
    ipadapter: ipadapter/
    vae: vae/
    diffusion_models: unet/
    upscale_models: upscale_models/
    loras: loras/

luma_extra:
    base_path: /Users/admin/code/luma/models/
    sams: sam2/
    depthanything: depth/
```

---

## Launch Configuration

Recommended ComfyUI launch flags for macOS:
```bash
python main.py --force-fp16 --use-pytorch-cross-attention
```

Environment variable for MPS fallback:
```bash
export PYTORCH_ENABLE_MPS_FALLBACK=1
```

---

## Custom Nodes Installed (29 packages)

Critical for workflow:
- ComfyUI-GGUF (Flux GGUF support)
- ComfyUI_UltimateSDUpscale (tiled upscaling)
- ComfyUI_IPAdapter_plus (style transfer)
- ComfyUI-Advanced-ControlNet (enhanced ControlNets)
- ComfyUI-DepthAnythingV2 (depth estimation)
- ComfyUI-Florence2 (vision model)
- ComfyUI-segment-anything-2 (SAM2 segmentation)
- was-node-suite-comfyui (utilities)
- ComfyUI_essentials (essential nodes)

---

## Tasks for New Agent

### Priority 1: Validate Current State
1. Load the workflow in ComfyUI and verify it runs without errors
2. Check if all model paths resolve correctly
3. Verify SAM2/Florence2 nodes use MPS, not CUDA

### Priority 2: Optimize for MPS
1. Find nodes using bf16 precision and change to fp16
2. Identify any remaining CUDA-specific settings
3. Test memory usage during full workflow run
4. Consider further quantization if memory issues persist

### Priority 3: Performance Tuning
1. Experiment with batch sizes
2. Test different sampler/scheduler combinations
3. Evaluate quality vs speed trade-offs
4. Document optimal settings for Mac

### Priority 4: Cleanup
1. Delete `flux1-dev-Q8_0.gguf` (12GB savings)
2. Remove duplicate SAM2 model
3. Remove unused fp16 SAM2 variant
4. Verify Florence-2 doesn't have redundant files

### Priority 5: Documentation
1. Document final optimized settings
2. Create simple test workflow to verify setup
3. Note any remaining limitations

---

## Success Criteria

1. Workflow completes without errors on macOS
2. Final output image is generated (visible in preview/saved)
3. Memory stays within 64GB during execution
4. Quality is acceptable for architectural visualization
5. Unused models deleted, saving ~12GB disk space

---

## Reference Links

- [PH's Archviz Workflow (Civitai)](https://civitai.com/models/920108/phs-archviz-x-ai-comfyui-workflow-sdxl-flux)
- [Basic Tutorial (40 workflows)](https://civitai.com/models/1734042/phs-basic-comfyui-tutorial-for-archviz-x-ai)
- [Flux on Apple Silicon Guide](https://apatero.com/blog/flux-apple-silicon-m1-m2-m3-m4-complete-performance-guide-2025)
- [MPS Backend Issues](https://github.com/comfyanonymous/ComfyUI/issues/4165)

---

## Files to Read First

1. `/Users/admin/code/luma/phsArchvizXAIComfyui_v037/archviz_ph_sdxlflux_v037.json` - Main workflow
2. `/Users/admin/code/luma/comfyui/ComfyUI/extra_model_paths.yaml` - Model paths config
3. `/Users/admin/code/luma/comfyui/tutorials/AIxArchviz_BASIC_ComfyUI/README.md` - Tutorial docs
