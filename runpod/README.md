# Luma ComfyUI - RunPod Pod Deployment

Deploy PH's Archviz ComfyUI workflow (298 nodes) on RunPod GPU Pods using the official ComfyUI template.

## Architecture

| Component | Solution |
|-----------|----------|
| **Base Image** | RunPod's official ComfyUI Pod template |
| **Custom Nodes** (26) | Install via ComfyUI-Manager (persists on volume) |
| **Models** (~49 GB) | Network Volume at `/workspace/models/` |
| **Everything** | Persists on network volume at `/workspace` |

## Quick Start

### Step 1: Create Network Volume

1. RunPod Console → **Storage** → **Network Volumes**
2. Click **+ New Network Volume**
3. Configure:
   - **Name**: `luma-comfyui`
   - **Size**: `75 GB` (models + ComfyUI + custom nodes)
   - **Datacenter**: `US-KS-2` or `US-CA-2`
4. Click **Create**

**Cost**: $0.07/GB/month × 75 GB = **$5.25/month**

### Step 2: Launch Setup Pod

1. **Pods** → **+ Deploy**
2. **Select Template**: Search for **"ComfyUI"** (official RunPod template)
3. **Select GPU**: Any cheap GPU (RTX 3090, ~$0.20/hr)
4. **Attach Network Volume**: `luma-comfyui`
5. **Deploy**

Wait 5-10 minutes for first-time ComfyUI installation.

### Step 3: Download Models

Connect via **Web Terminal** and run:

```bash
# Download and run the model download script
wget -O /workspace/download_models.py https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/scripts/download_models.py
python3 /workspace/download_models.py
```

The script will:
- Auto-install `huggingface-hub` if needed
- Create all model directories
- Download all 16 models (~49 GB)
- Verify SHA256 hashes
- Handle directory flattening

Wait ~30-60 minutes for downloads to complete.

### Step 4: Configure Model Paths

```bash
cat > /workspace/runpod-slim/ComfyUI/extra_model_paths.yaml << 'EOF'
luma:
    base_path: /workspace/models/
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
    base_path: /workspace/
    sams: models/sam2/
    depthanything: models/depth/
    LLM: LLM/
EOF
```

Create symlinks for custom nodes with hardcoded paths:

```bash
ln -sf /workspace/models/sam2 /workspace/runpod-slim/ComfyUI/models/sam2
ln -sf /workspace/LLM /workspace/runpod-slim/ComfyUI/models/LLM
ln -sf /workspace/models/depth /workspace/runpod-slim/ComfyUI/models/depthanything
```

### Step 5: Install Custom Nodes

1. Open ComfyUI: Click **Connect** → **HTTP Service [Port 8188]**
2. Open **ComfyUI-Manager** (Manager menu or gear icon)
3. Install each node via **Install Custom Nodes**:

**From Registry (search and install):**
- ComfyUI-ControlNet-Aux
- ComfyUI-Advanced-ControlNet
- ComfyUI-GGUF
- ComfyUI-IPAdapter-Plus
- ComfyUI-Essentials
- ComfyUI-KJNodes (may be pre-installed)
- ComfyUI-DepthAnythingV2
- ComfyUI-Florence2
- ComfyUI-Segment-Anything-2
- ComfyUI-UltimateSDUpscale
- ComfyUI-Custom-Scripts
- rgthree-comfy
- ComfyUI-Easy-Use
- Masquerade-Nodes-ComfyUI
- ComfyUI-ComfyRoll-CustomNodes
- ComfyMath
- ComfyUI-Post-Processing-Nodes
- comfy-mtb
- ComfyUI-Impact-Pack
- Efficiency-Nodes-ComfyUI

**From Git (use "Install via Git URL"):**
- `https://github.com/WASasquatch/was-node-suite-comfyui`
- `https://github.com/theUpsider/ComfyUI-Logic`
- `https://github.com/jamesWalker55/comfyui-various`
- `https://github.com/sipherxyz/comfyui-art-venture`
- `https://github.com/chrisgoringe/cg-image-filter`

4. **Restart ComfyUI** after all installations

### Step 6: Upload Workflow & Test

1. In ComfyUI: **Load** → upload `archviz_v037_cuda.json`
2. Verify no "missing node" errors
3. Verify models appear in dropdowns
4. **Queue Prompt** to test generation
5. If working, **Terminate** setup Pod

### Step 7: Launch Production Pod

1. **Pods** → **+ Deploy**
2. **Select Template**: **ComfyUI** (official)
3. **Select GPU**: **RTX 4090** (24 GB, $0.34/hr)
4. **Attach Network Volume**: `luma-comfyui`
5. **Deploy**

Everything is already configured - instant access!

## Directory Structure

```
/workspace/                              <- Network volume
├── runpod-slim/
│   └── ComfyUI/                         <- ComfyUI installation
│       ├── custom_nodes/                <- Installed nodes (persists)
│       ├── models/                      <- Symlinks to /workspace/models
│       ├── input/                       <- Input images
│       ├── output/                      <- Generated images
│       └── extra_model_paths.yaml       <- Model path config
├── models/                              <- Model storage
│   ├── checkpoints/
│   ├── clip/
│   ├── clip_vision/
│   ├── controlnet/
│   ├── ipadapter/
│   ├── unet/
│   ├── vae/
│   ├── upscale_models/
│   ├── depth/
│   └── sam2/
└── LLM/
    └── Florence-2-large/
```

## Models (~49 GB)

| Model | Size | Location |
|-------|------|----------|
| RealVisXL V4.0 | 6.5 GB | checkpoints/ |
| RealVisXL V5.0 Lightning | 6.5 GB | checkpoints/ |
| Flux1-dev Q8_0 | 12 GB | unet/ |
| T5-XXL Q8_0 | 4.7 GB | clip/ |
| clip_l | 235 MB | clip/ |
| CLIP-ViT-H | 2.4 GB | clip_vision/ |
| ControlNet Canny | 2.3 GB | controlnet/ |
| ControlNet Depth | 2.3 GB | controlnet/ |
| ControlNet OpenPose | 2.3 GB | controlnet/ |
| IP-Adapter Plus | 808 MB | ipadapter/ |
| Flux VAE | 320 MB | vae/ |
| 4x-UltraSharp | 64 MB | upscale_models/ |
| Depth Anything V2 | 1.2 GB | depth/ |
| Depth Anything V1 | 1.2 GB | depth/ |
| SAM 2.1 | 308 MB | sam2/ |
| Florence-2-large | 1.5 GB | LLM/ |

## GPU Recommendations

| GPU | VRAM | Price/hr | Use Case |
|-----|------|----------|----------|
| RTX 4090 | 24 GB | $0.34 | Development, single image |
| L40 | 48 GB | $0.89 | Multi-model, larger batches |
| A100 80GB | 80 GB | $1.99 | Production, max performance |

## Cost Estimates

- **Network Volume**: $5.25/month (75 GB @ $0.07/GB)
- **RTX 4090 Pod**: $0.34/hr
- **Per image**: ~$0.01-0.03 (2-5 min generation)

## Verification

### After Model Download
```bash
ls /workspace/.models_downloaded          # Marker file exists
ls /workspace/models/checkpoints/         # 2 checkpoint files
ls /workspace/models/unet/                # flux1-dev-Q8_0.gguf
ls /workspace/LLM/Florence-2-large/       # Florence-2 model
```

### After Node Installation
- Load workflow → No red "missing node" errors
- All nodes visible in node menu

## Troubleshooting

### Models not found?
- Verify `extra_model_paths.yaml` exists and has correct paths
- Check symlinks: `ls -la /workspace/runpod-slim/ComfyUI/models/`

### Missing custom nodes?
- Open ComfyUI-Manager → Install missing nodes
- Restart ComfyUI after installation

### OOM errors?
- RTX 4090 (24 GB) should work
- Try L40 (48 GB) if issues persist

### Pod starts slow?
- First boot takes 5-10 min (ComfyUI installation)
- Subsequent boots are fast (everything on volume)

## Important Notes

- **DO NOT** use `runpod/worker-comfyui` - that's for Serverless only (no browser UI)
- **USE** the official "ComfyUI" template in RunPod console
- Everything persists on network volume - no setup needed after first time
