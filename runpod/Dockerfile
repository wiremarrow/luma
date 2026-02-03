# runpod/Dockerfile
# Custom ComfyUI image for PH's Archviz workflow on RunPod
FROM runpod/worker-comfyui:5.1.0-base

# ============================================================================
# CUSTOM NODES - Registry installations (21 packages)
# ============================================================================
RUN comfy-node-install \
    comfyui-manager \
    comfyui-controlnet-aux \
    comfyui-advanced-controlnet \
    comfyui-gguf \
    comfyui-ipadapter-plus \
    comfyui-essentials \
    comfyui-kjnodes \
    comfyui-depthanythingv2 \
    comfyui-florence2 \
    comfyui-segment-anything-2 \
    comfyui-ultimatesdupscale \
    comfyui-custom-scripts \
    rgthree-comfy \
    comfyui-easy-use \
    masquerade-nodes-comfyui \
    comfyui-comfyroll-customnodes \
    comfymath \
    comfyui-post-processing-nodes \
    comfy-mtb \
    comfyui-impact-pack \
    efficiency-nodes-comfyui

# ============================================================================
# CUSTOM NODES - Git clones (archived/non-registry) (7 packages)
# ============================================================================
WORKDIR /comfyui/custom_nodes

# Archived but required (22 nodes from WAS, 12 nodes from Logic)
RUN git clone --depth 1 https://github.com/WASasquatch/was-node-suite-comfyui.git && \
    git clone --depth 1 https://github.com/theUpsider/ComfyUI-Logic.git && \
    git clone --depth 1 https://github.com/jamesWalker55/comfyui-various.git && \
    git clone --depth 1 https://github.com/sipherxyz/comfyui-art-venture.git && \
    git clone --depth 1 https://github.com/chrisgoringe/cg-image-filter.git

# Dependencies for cloned nodes
RUN pip install soundfile --no-cache-dir
RUN find . -name "requirements.txt" -exec pip install -r {} --no-cache-dir \;

# ============================================================================
# MODEL PATH CONFIGURATION
# ============================================================================
WORKDIR /comfyui

# Create extra_model_paths.yaml for network volume
RUN printf 'runpod:\n\
    base_path: /runpod-volume/models/\n\
    is_default: true\n\
    checkpoints: checkpoints/\n\
    clip: clip/\n\
    clip_vision: clip_vision/\n\
    controlnet: controlnet/\n\
    ipadapter: ipadapter/\n\
    vae: vae/\n\
    diffusion_models: unet/\n\
    upscale_models: upscale_models/\n\
    loras: loras/\n\
\n\
runpod_extra:\n\
    base_path: /runpod-volume/models/\n\
    sams: sam2/\n\
    depthanything: depth/\n' > extra_model_paths.yaml

# Symlinks for custom node hardcoded paths
RUN mkdir -p /comfyui/models && \
    ln -sf /runpod-volume/models/sam2 /comfyui/models/sam2 && \
    ln -sf /runpod-volume/LLM /comfyui/models/LLM && \
    ln -sf /runpod-volume/models/depth /comfyui/models/depthanything && \
    ln -sf /runpod-volume/input /comfyui/input

# ============================================================================
# WORKFLOW
# ============================================================================
COPY workflows/ /comfyui/user/default/workflows/

WORKDIR /
