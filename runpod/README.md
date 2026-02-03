# Luma ComfyUI - RunPod Deployment

Deploy PH's Archviz ComfyUI workflow (298 nodes) on RunPod with GPU Pods.

## Architecture

| Component | Solution |
|-----------|----------|
| **Models** (~49 GB) | Network Volume - persists across sessions |
| **Custom Nodes** (28) | Docker Image - baked in at build time |
| **Development** | GPU Pods - full SSH access |

## Quick Start

### 1. Create Network Volume

1. RunPod Console → Storage → New Network Volume
2. Settings:
   - Name: `luma-models`
   - Size: 60 GB
   - Region: US-KS-2 (or your preferred region)

### 2. Download Models (One-time)

1. Create a temporary Pod (any cheap GPU) with the network volume attached
2. SSH into the Pod: `ssh root@<pod-ip>` (or use RunPod web terminal)
3. Copy the download script to the Pod:

```bash
# From your local machine
scp scripts/download_models_runpod.sh root@<pod-ip>:/root/
```

4. Run the script on the Pod:

```bash
bash /root/download_models_runpod.sh
```

5. Wait ~30-60 minutes for all models to download
6. Verify: `ls -lah /runpod-volume/models/*/`
7. Terminate the temporary Pod (models persist on volume)

### 3. Build & Push Docker Image

```bash
cd /path/to/luma/runpod

# Build for linux/amd64 (required for RunPod)
docker build --platform linux/amd64 -t yourusername/luma-comfyui:v1 .

# Push to Docker Hub
docker login
docker push yourusername/luma-comfyui:v1
```

### 4. Create Pod Template

1. RunPod Console → Pods → Templates → New Template
2. Settings:
   - Template Name: `Luma ComfyUI`
   - Container Image: `yourusername/luma-comfyui:v1`
   - Container Disk: 20 GB
   - Volume Disk: 0 (using network volume)
   - Expose HTTP Ports: `8188`

### 5. Launch Pod

1. Deploy new Pod from template
2. Select GPU: RTX 4090 (24 GB) recommended
3. Attach Network Volume: `luma-models`
4. Access ComfyUI: `https://<pod-id>-8188.proxy.runpod.net`

## Directory Structure

### Network Volume (`/runpod-volume/`)

```
/runpod-volume/
├── models/
│   ├── checkpoints/          # RealVisXL models
│   ├── clip/                 # T5 and CLIP encoders
│   ├── clip_vision/          # CLIP Vision model
│   ├── controlnet/           # Canny, Depth, OpenPose
│   ├── ipadapter/            # IP-Adapter Plus
│   ├── unet/                 # Flux GGUF
│   ├── vae/                  # Flux VAE
│   ├── upscale_models/       # 4x-UltraSharp
│   ├── depth/                # Depth Anything V2
│   └── sam2/                 # SAM 2.1
├── LLM/
│   └── Florence-2-large/     # Florence-2 model
└── input/                    # Workflow input images (user-provided)
```

## Input Images

The workflow requires input images in `/runpod-volume/input/`. You can either:

1. **Upload via SCP** before launching the production Pod
2. **Upload via ComfyUI UI** - load images through the browser interface

### Required Images

| Image | Purpose | Required? |
|-------|---------|-----------|
| `doom.jpg` | Reference/style image | Yes |
| `ph_house01_1DEPTH.jpg` | Depth map input | Yes |
| `ph_house01_SEG_MASK.jpg` | Segmentation mask | Yes |
| `ph_logo_03_transparent.png` | Logo overlay | Optional |
| `ph_credits_02.png` | Credits overlay | Optional |

For initial testing, you can upload images through the ComfyUI browser UI after launching the Pod.

### Docker Image

- Base: `runpod/worker-comfyui:5.1.0-base`
- Custom nodes: 21 from registry + 5 from git
- Model paths configured via `extra_model_paths.yaml`
- Workflow pre-loaded in `/comfyui/user/default/workflows/`

## Custom Nodes Included

### From ComfyUI Registry (21)

- comfyui-manager
- comfyui-controlnet-aux
- comfyui-advanced-controlnet
- comfyui-gguf
- comfyui-ipadapter-plus
- comfyui-essentials
- comfyui-kjnodes
- comfyui-depthanythingv2
- comfyui-florence2
- comfyui-segment-anything-2
- comfyui-ultimatesdupscale
- comfyui-custom-scripts
- rgthree-comfy
- comfyui-easy-use
- masquerade-nodes-comfyui
- comfyui-comfyroll-customnodes
- comfymath
- comfyui-post-processing-nodes
- comfy-mtb
- comfyui-impact-pack
- efficiency-nodes-comfyui

### From Git (5)

- was-node-suite-comfyui
- ComfyUI-Logic
- comfyui-various
- comfyui-art-venture
- cg-image-filter

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
| RTX 4090 | 24 GB | $0.34-0.59 | Development, single image |
| L40 | 48 GB | $0.89 | Multi-model, larger batches |
| A100 80GB | 80 GB | $1.99 | Production, max performance |

## Cost Estimates

- **Network Volume**: $4.20/month (60 GB @ $0.07/GB)
- **RTX 4090 Pod**: ~$0.50/hr average
- **Per image**: ~$0.02-0.05 (assuming 2-5 min generation)

## Troubleshooting

### Missing Models

```bash
# Check if models exist
ls -lah /runpod-volume/models/*/

# Re-run download if needed
rm /runpod-volume/.models_downloaded
bash /path/to/download_models_runpod.sh
```

### Missing Custom Nodes

Check ComfyUI console for errors. The image includes all 26 required custom nodes.

### OOM Errors

- Use fp16 precision (default)
- Reduce batch size
- Consider upgrading to L40 (48 GB) or A100 (80 GB)

### Network Volume Not Mounted

Verify the volume is attached in RunPod Console. Check mount point:

```bash
df -h | grep runpod-volume
```

## Verification Checklists

### Pre-Deployment

- [ ] Docker image built and pushed to Docker Hub
- [ ] Network volume created (60 GB)
- [ ] Download script copied to Pod

### Model Download Verification

After running `download_models_runpod.sh`:

```bash
# All 16 models present
ls -lah /runpod-volume/models/*/

# Verify flat directory structure (critical!)
ls /runpod-volume/models/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors
ls /runpod-volume/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors
ls /runpod-volume/models/upscale_models/4x-UltraSharp.pth

# Florence-2 directory
ls /runpod-volume/LLM/Florence-2-large/model.safetensors

# Marker file exists
ls /runpod-volume/.models_downloaded

# NO nested subdirectories (these should NOT exist)
ls /runpod-volume/models/ipadapter/sdxl_models/  # Should fail
ls /runpod-volume/models/clip_vision/clip_vision/ # Should fail
ls /runpod-volume/models/upscale_models/ESRGAN/   # Should fail
```

### Pod Testing Checklist

- [ ] Pod starts without container errors
- [ ] ComfyUI UI accessible at `https://<pod-id>-8188.proxy.runpod.net`
- [ ] No "missing node" errors in browser console
- [ ] Workflow loads: File → Load → archviz_v037_cuda.json
- [ ] All models detected (check ComfyUI model dropdowns)
- [ ] Input images selectable in LoadImage nodes
- [ ] Queue prompt → Generation starts
- [ ] Generation completes without OOM
- [ ] Output image quality acceptable

### Performance Baseline

Record these metrics for reference:
- Pod startup time: ~2-3 minutes expected
- Full workflow generation time: ~2-5 minutes expected
- Peak VRAM usage: Should stay under 20 GB on RTX 4090

## Serverless (Future)

When ready for API access, create a Serverless endpoint using the same image and network volume. See the plan document for Python client examples.
