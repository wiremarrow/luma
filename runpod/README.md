# Luma ComfyUI - RunPod Deployment

Deploy PH's Archviz ComfyUI workflow (298 nodes, 16 models, 26 custom nodes) on RunPod GPU Pods.

## Quick Start

### 1. Create Network Volume

1. RunPod Console → **Storage** → **Network Volumes**
2. **+ New Network Volume**
   - Name: `luma-comfyui`
   - Size: `75 GB`
   - Datacenter: Any US location
3. **Create**

Cost: ~$5.25/month

### 2. Launch Pod

1. **Pods** → **+ Deploy**
2. Template: Search **"ComfyUI"** (official RunPod template)
3. GPU: RTX 3090 for setup (~$0.20/hr), RTX 4090 for production (~$0.34/hr)
4. Attach Network Volume: `luma-comfyui`
5. **Deploy**

Wait 5-10 minutes for first-time ComfyUI installation.

### 3. Run Setup Script

Connect via **Web Terminal** and run:

```bash
# One-time: Login to HuggingFace (required for Flux VAE)
# Get token from: https://huggingface.co/settings/tokens
# Accept license at: https://huggingface.co/black-forest-labs/FLUX.1-schnell
python3 -c "from huggingface_hub import login; login()"

# Run setup (downloads everything: models, nodes, workflow)
wget -O /workspace/setup.py https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/scripts/setup.py
python3 /workspace/setup.py
```

This takes 30-60 minutes (49 GB of models + 26 custom nodes).

### 4. Test

1. Open ComfyUI: **Connect** → **HTTP Service [Port 8188]**
2. Load workflow: `archviz_v037_cuda.json` (should be in workflows tab)
3. Verify no red "missing node" errors
4. Verify models appear in dropdowns
5. **Queue Prompt** to test

### 5. Future Deployments

Everything persists on the network volume. For new pods:
1. Create pod with same network volume attached
2. Wait for ComfyUI to start
3. Load workflow and use

---

## What the Setup Script Does

The `setup.py` script automates:

1. **Creates directory structure** at `/workspace/models/`
2. **Downloads 16 models** (~49 GB) with SHA256 verification
3. **Creates `extra_model_paths.yaml`** for ComfyUI to find models
4. **Creates symlinks** for nodes with hardcoded paths (SAM2, Florence-2, DepthAnything)
5. **Installs 26 custom nodes** via git clone + requirements.txt
6. **Downloads workflow** to ComfyUI workflows directory

## Directory Structure

```
/workspace/
├── setup.py                    <- Setup script (can delete after)
├── archviz_v037_cuda.json      <- Workflow file
├── models/                     <- All models (~49 GB)
│   ├── checkpoints/            <- RealVisXL V4.0, V5.0 Lightning
│   ├── clip/                   <- clip_l, T5-XXL Q8_0
│   ├── clip_vision/            <- CLIP-ViT-H
│   ├── controlnet/             <- Canny, Depth, OpenPose
│   ├── ipadapter/              <- IP-Adapter Plus
│   ├── unet/                   <- Flux1-dev Q8_0
│   ├── vae/                    <- Flux VAE
│   ├── upscale_models/         <- 4x-UltraSharp
│   ├── depth/                  <- DepthAnything V1, V2
│   └── sam2/                   <- SAM 2.1
├── LLM/
│   └── Florence-2-large/       <- Microsoft Florence-2
└── runpod-slim/
    └── ComfyUI/                <- ComfyUI installation
        ├── extra_model_paths.yaml
        ├── custom_nodes/       <- Installed nodes (persists)
        └── models/             <- Symlinks to /workspace/models
```

## Models (16 total, ~49 GB)

| Model | Size | Source |
|-------|------|--------|
| Flux1-dev Q8_0 | 12 GB | city96 |
| RealVisXL V4.0 | 6.5 GB | SG161222 |
| RealVisXL V5.0 Lightning | 6.5 GB | SG161222 |
| T5-XXL Q8_0 | 4.7 GB | city96 |
| ControlNet Canny | 2.3 GB | lllyasviel |
| ControlNet Depth | 2.3 GB | lllyasviel |
| ControlNet OpenPose | 2.3 GB | lllyasviel |
| CLIP-ViT-H | 2.4 GB | laion |
| Florence-2-large | 1.5 GB | Microsoft |
| Depth Anything V2 | 1.2 GB | LiheYoung |
| Depth Anything V1 | 1.2 GB | LiheYoung |
| IP-Adapter Plus | 808 MB | h94 |
| Flux VAE | 320 MB | Black Forest Labs |
| SAM 2.1 | 308 MB | Kijai |
| clip_l | 235 MB | comfyanonymous |
| 4x-UltraSharp | 64 MB | uwg |

## Troubleshooting

### "Access denied" on Flux VAE?
You need to accept the license:
1. Go to https://huggingface.co/black-forest-labs/FLUX.1-schnell
2. Click "Agree and access repository"
3. Re-run: `rm /workspace/.models_downloaded && python3 /workspace/setup.py`

### Models not showing in dropdowns?
Check that `extra_model_paths.yaml` exists:
```bash
cat /workspace/runpod-slim/ComfyUI/extra_model_paths.yaml
```

### Missing custom nodes (red nodes)?
Install via ComfyUI-Manager, then restart ComfyUI.

### Re-run setup?
```bash
rm /workspace/.models_downloaded
python3 /workspace/setup.py
```

## GPU Recommendations

| GPU | VRAM | $/hr | Use Case |
|-----|------|------|----------|
| RTX 3090 | 24 GB | ~$0.20 | Setup only |
| RTX 4090 | 24 GB | ~$0.34 | Production |
| L40 | 48 GB | ~$0.89 | Large batches |
| A100 80GB | 80 GB | ~$1.99 | Maximum performance |

## Notes

- **DO NOT** use `runpod/worker-comfyui` template - that's for Serverless (no browser UI)
- **USE** the official "ComfyUI" template in RunPod console
- Everything persists on network volume - no setup needed after first time
- The workflow is already patched for CUDA (converted from macOS MPS)
