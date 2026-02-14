# Workflow Upgrade Research: Archviz Pipeline

Research into upgrading PH's Archviz v0.37 ComfyUI workflow with newer models, techniques, and technologies for taking Revit pre-renders to high-fidelity, structurally accurate 4K output.

## Current Pipeline (v0.37) Weaknesses

| Stage | Current | Limitation |
|-------|---------|------------|
| First pass | SDXL (RealVisXL 4.0, 6.5GB) | Lower quality than Flux-native generation; two-stage approach loses detail between passes |
| ControlNets | SDXL-specific (depth + canny) | Not Flux-native; structural guidance is indirect since Flux stage re-processes SDXL output |
| Depth estimation | DepthAnythingV2 | Good (95.3% DA-2K) but boundary sharpness is inferior to newer options |
| Upscaling | 4x-UltraSharp (ESRGAN) | Basic pixel upscaler; doesn't generate new detail, just interpolates |
| Inpainting | SDXL-based with experimental Flux mask | Weak; author calls it "experimental" |
| Segmentation | Florence-2 + SAM2 | Still strong; no pressing need to upgrade |

---

## Upgrade Recommendations (Priority Order)

### 1. Upgrade to PH's v0.60 (Flux-Native Pipeline)

**Impact: HIGH | Effort: LOW**

The workflow author already evolved v0.37 into [v0.60](https://civitai.com/models/972694/phs-archviz-x-ai-comfyui-workflow-flux1tools-cogvideox) which drops SDXL entirely and uses Flux Tools natively:

- **Flux Depth** — native structural conditioning (not an SDXL ControlNet adapted for Flux)
- **Flux Canny** — native edge preservation
- **Flux Fill** — native inpainting/outpainting (replaces the experimental SDXL mask inpainting)
- **CogVideoX** — adds video generation with camera motion
- Runs ~530s for 1920x1440px on a 4090, VRAM peaks ~23GB

**Why this matters**: v0.37 generates an SDXL image, then uses Flux to refine it — losing structural accuracy in the handoff. v0.60 uses Flux natively for the entire pipeline, with Flux's own depth/canny conditioning. This is the single biggest structural accuracy improvement available.

**What's needed**: Download the workflow from Civitai, update `setup.py` model list to match v0.60 requirements, test with our scene configs.

---

### 2. FLUX.2 Dev (32B) — Replace Flux 1 Dev

**Impact: HIGH | Effort: MEDIUM**

[FLUX.2](https://bfl.ai/models/flux-2) was released November 2025. 32B parameters (vs Flux 1's 12B):

- Redesigned VAE with superior geometry and texture preservation
- Mistral-3 24B vision-language model coupled with rectified flow transformer
- For architecture: depth ControlNet maintains floor-to-floor heights within 2-3% variance
- Open-weight dev version on [HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-dev) (non-commercial license)
- Day-0 [ComfyUI support](https://docs.comfy.org/tutorials/flux/flux-2-dev)
- fp8 quantized variant available for 24GB GPUs

**Key model files**:
- `flux2_dev_fp8mixed.safetensors`
- `mistral_3_small_flux2_fp8.safetensors`
- `flux2-vae.safetensors`

**Trade-offs**: Requires 24GB+ VRAM (fits on RTX 4090). Would require building or adapting a workflow since v0.60 uses Flux 1 Tools. No Flux 2-specific ControlNets exist yet — would need to use Flux 1 ControlNets or the InstantX Union adapter.

---

### 3. InstantX Flux Union ControlNet Pro

**Impact: MEDIUM | Effort: LOW**

[Single model](https://huggingface.co/InstantX/FLUX.1-dev-Controlnet-Union) that supports all control modes in one:

- Canny, Depth, Tile, Blur, Pose, Grayscale, Low-quality
- Can combine modes (e.g., depth + canny simultaneously)
- More efficient than loading separate ControlNet models
- Optimal conditioning scale: 0.3-0.8

**Why this matters for archviz**: Tile mode can preserve textures from the input render. Combining depth + canny + tile in a single model gives the tightest structural lock available.

---

### 4. Apple Depth Pro — Better Depth Estimation

**Impact: MEDIUM | Effort: LOW**

[Depth Pro](https://arxiv.org/html/2410.02073v1) produces metric depth (not just relative):

- Sharper boundaries than DepthAnythingV2, especially for thin architectural elements
- Higher recall for fine structures
- 0.3 second inference time
- Pixel-perfect high-resolution depth maps

**vs current DepthAnythingV2**: DA-V2 is 95.3% accurate on DA-2K, but Depth Pro has significantly sharper edges at structure boundaries — critical for window frames, rooflines, and facade details.

**ComfyUI**: Available via [comfyui_controlnet_aux](https://github.com/Fannovel16/comfyui_controlnet_aux) preprocessors.

---

### 5. SUPIR Upscaler — Replace 4x-UltraSharp

**Impact: HIGH | Effort: MEDIUM**

[SUPIR](https://github.com/kijai/ComfyUI-SUPIR) is a diffusion-based upscaler that generates new detail rather than just interpolating pixels:

- Uses SDXL-compatible models as a base
- Acts like an img2img ControlNet — guides the input toward an enhanced version
- "F" variant optimized for lighter degradations (ideal for already-good renders)
- Supports text prompts to guide upscaling (e.g., "sharp architectural photography")
- Can be chained with UltimateSDUpscale for a two-stage approach (SUPIR for detail, USDU for final size)

**vs current 4x-UltraSharp**: ESRGAN upscalers only interpolate existing pixels. SUPIR generates new textures, brick patterns, glass reflections, and fine architectural detail that didn't exist at the lower resolution. For 4K output, this is transformative.

---

### 6. Z-Image Turbo — Future Consideration

**Impact: MEDIUM | Uncertainty: HIGH**

[Z-Image Turbo](https://fal.ai/models/fal-ai/z-image/turbo/controlnet) from Alibaba/Tongyi-MAI:

- 6B parameter model, 3-5x faster than traditional ControlNet workflows
- Has its own [Union ControlNet 2.1](https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1) (depth, canny, HED, pose)
- $0.0065/megapixel for batch processing
- Version 2.1 (Jan 2026) fixed acceleration + blur issues

**Trade-off**: Newer model, less proven for architectural accuracy. Fast and cheap but untested for the precision required in archviz.

---

### 7. IC-Light V2 — Relighting

**Impact: LOW for exteriors**

[IC-Light V2](https://github.com/kijai/ComfyUI-IC-Light) offers AI relighting:

- Text-conditioned: "warm sunset light from the west"
- Background-conditioned: analyze a sky image and match illumination
- Improved edge artifacts vs V1

More useful for interiors than exteriors. The current workflow's lighting is already prompt-driven. Could be useful for matching specific lighting conditions (golden hour, overcast) but not a priority.

---

### 8. FLUX Kontext — Instruction-Based Editing

**Impact: LOW**

[FLUX Kontext](https://bfl.ai/models/flux-kontext) handles instruction-based image editing:

- "Change the facade material to glass" type commands
- Good for iterative refinement and local edits
- Preserves objects/characters well

Useful for post-processing touch-ups, not for the core generation pipeline.

---

## Recommended Upgrade Strategy

### Phase 1: Quick Wins (adapt current RunPod setup)

1. **Upgrade to PH's v0.60** — drops SDXL, goes Flux-native with Flux Tools
2. **Swap DepthAnythingV2 -> Depth Pro** as preprocessor (if supported in v0.60)
3. **Add SUPIR upscaling** after the current UltimateSDUpscale stage

### Phase 2: Next-Gen Pipeline (requires new workflow)

4. **Replace Flux 1 Dev -> FLUX.2 Dev** (32B, once ControlNets catch up)
5. **Use InstantX Union ControlNet** for combined depth+canny+tile conditioning
6. **Evaluate Z-Image Turbo** for speed-critical batch processing

### Phase 3: Polish

7. IC-Light V2 for specific lighting scenarios
8. Flux Kontext for targeted post-edits

---

## Comparison Matrix

| Approach | Quality | Structural Accuracy | Speed | Effort |
|----------|---------|-------------------|-------|--------|
| Keep v0.37 | Baseline | Good (SDXL ControlNets) | ~16min | None |
| Upgrade to v0.60 | Better (Flux-native) | Better (Flux depth/canny) | ~9min | Low |
| v0.60 + SUPIR | Much better (4K detail) | Better | ~12min | Medium |
| FLUX.2 custom workflow | Best available | Best (2-3% variance) | Unknown | High |
| Z-Image Turbo | Good | Unknown for archviz | ~2min | High |

---

## Sources

- [PH's Archviz v0.60 (Civitai)](https://civitai.com/models/972694/phs-archviz-x-ai-comfyui-workflow-flux1tools-cogvideox)
- [FLUX.2 (Black Forest Labs)](https://bfl.ai/models/flux-2)
- [FLUX.2 Dev on HuggingFace](https://huggingface.co/black-forest-labs/FLUX.2-dev)
- [FLUX.2 ComfyUI Docs](https://docs.comfy.org/tutorials/flux/flux-2-dev)
- [InstantX Flux Union ControlNet](https://huggingface.co/InstantX/FLUX.1-dev-Controlnet-Union)
- [Z-Image Turbo ControlNet](https://fal.ai/models/fal-ai/z-image/turbo/controlnet)
- [Z-Image Turbo Union 2.1 (HuggingFace)](https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1)
- [Apple Depth Pro (arXiv)](https://arxiv.org/html/2410.02073v1)
- [SUPIR ComfyUI](https://github.com/kijai/ComfyUI-SUPIR)
- [IC-Light V2 ComfyUI](https://github.com/kijai/ComfyUI-IC-Light)
- [Flux Kontext (BFL)](https://bfl.ai/models/flux-kontext)
- [Flux ControlNet Guide](https://apatero.com/blog/flux-depth-canny-controlnet-complete-guide-2025)
- [Flux vs SDXL Comparison](https://pxz.ai/blog/flux-vs-sdxl)
