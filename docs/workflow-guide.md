# PH's Archviz v0.37 Workflow - Technical Reference

Comprehensive notes on the inner workings of the 298-node ComfyUI workflow, based on JSON analysis and the author's video walkthrough.

---

## Table of Contents

1. [Workflow Overview](#workflow-overview)
2. [Input System](#input-system)
3. [ControlNet Preprocessing (SWITCH CNET)](#controlnet-preprocessing-switch-cnet)
4. [Segmentation Systems](#segmentation-systems)
5. [Manual Color Mask (MaskFromRGBCMYBW+)](#manual-color-mask-maskfromrgbcmybw)
6. [Auto Segmentation (Florence-2 + SAM2)](#auto-segmentation-florence-2--sam2)
7. [Architectural Structure Preservation](#architectural-structure-preservation)
8. [Detail Conservation](#detail-conservation)
9. [Person Insertion](#person-insertion)
10. [BASE CONFIG Toggles](#base-config-toggles)
11. [Prompting Architecture](#prompting-architecture)
12. [Scene Config System](#scene-config-system)
13. [Models](#models)
14. [RunPod Deployment](#runpod-deployment)
15. [Known Issues and Fixes](#known-issues-and-fixes)

---

## Workflow Overview

The workflow operates in three stages:

1. **SDXL Generation** — Initial image generation using ControlNet guidance (depth + canny) with an SDXL checkpoint. Produces a base image from the input render.
2. **Flux Detailing** — Enhances the SDXL output with Flux for finer architectural detail. Uses Florence-2 for object detection and SAM2 for precise masking.
3. **Upscale & Refinement** — UltimateSDUpscale increases resolution (default 4x via 4x-UltraSharp). Final compositing, overlay, and output.

**Typical timings** (RTX 4090): ~10-16 minutes for a full run at default settings.

**Output resolution**: Input at 1536x1024 produces ~4000px on the long side at default upscale. Factor of 8 produces 12,288x8,192px.

---

## Input System

The workflow accepts three input types. Only the first is required.

### 1. Base Input Image (Node 79) — REQUIRED

The main architectural render or photo. Can be a low-effort 3D render (the author tested with a quick V-Ray render from 3ds Max with minimal scene setup).

### 2. Depth Map (Node 25) — OPTIONAL

A pre-rendered depth pass (e.g., Z-depth from V-Ray). If not available, the workflow can auto-generate one using DepthAnythingV2. Controlled by Node 456 "SWITCH CNET":

| Value | Mode | Description |
|-------|------|-------------|
| 1 | EXTRA (manual) | Uses the image loaded in Node 25 as the depth input |
| 2 | PREPROCESS (auto) | Auto-generates depth from the base input via DepthAnythingV2 (Node 38) |

### 3. Manual Segmentation Mask (Node 338) — OPTIONAL

A hand-painted color image where different pure colors represent different zones of the scene (building, sky, ground, etc.). The author stated in his video: "I created a multimat mask. I didn't use this one at all in the example, but by now I highly recommend to have something like this."

If not provided, disable "Enable Process SEGMENTATION" and "Enable MASKS" in the BASE CONFIG to avoid errors.

---

## ControlNet Preprocessing (SWITCH CNET)

**Node 456** — an integer constant that controls whether ControlNet uses manual inputs or auto-generated preprocessing.

### How It Works

Node 456's value feeds into two CR Image Input Switch nodes (542, 732) that select between:
- **Slot 1 (manual)**: Images from the EXTRA input nodes (Node 25 for depth, Node 79 resized for canny)
- **Slot 2 (auto)**: Output from the preprocessor nodes

### Auto Preprocessing Pipeline

When Node 456 = 2, these nodes generate the control images:

| Node | Type | Output |
|------|------|--------|
| 38 | DepthAnythingV2Preprocessor | Depth map from base input |
| 164 | HEDPreprocessor | Soft edge detection |
| 165 | Image Edge Detection Filter | Final canny/edge output |

### Requirements

Both settings must be aligned:
- **Node 456 = 2** AND **"Enable ControlNet Preprocessors + Extras" = yes** in BASE CONFIG
- If preprocessors are disabled but switch is set to 2, the switch selects an empty path
- If preprocessors are enabled but switch is 1, preprocessors run but their output is ignored

The author confirmed in his video: "if I turn this to two I also can use the generated z-depths from the ControlNet preprocessors."

---

## Segmentation Systems

The workflow has **two completely separate** segmentation systems that serve different purposes. They are independent pipelines.

### At a Glance

| System | Input | Output | Purpose | Automatic? |
|--------|-------|--------|---------|------------|
| Manual color mask | User-painted RGB image (Node 338) | 8 fixed color-channel masks | Zone-based detail conservation | No — requires hand-painted image |
| Florence-2 + SAM2 | Text prompts from scene config | Per-object binary masks | Object detection and masking | Yes — fully automatic |

---

## Manual Color Mask (MaskFromRGBCMYBW+)

### How It Works

1. User paints an image with pure colors — each color represents a different zone of the scene
2. Node 338 (LoadImage) loads the painted image
3. Node 337 (MaskFromRGBCMYBW+) splits it into 8 separate masks by color channel

### The 8 Channels

| Channel | Slot | Color | Status in v0.37 |
|---------|------|-------|-----------------|
| Red | 0 | Pure red (#FF0000) | **ACTIVE** — feeds into Flux inpainting pipeline |
| Green | 1 | Pure green (#00FF00) | Preview only |
| Blue | 2 | Pure blue (#0000FF) | Preview only |
| Cyan | 3 | Pure cyan (#00FFFF) | Preview only |
| Magenta | 4 | Pure magenta (#FF00FF) | Preview only |
| Yellow | 5 | Pure yellow (#FFFF00) | Preview only |
| Black | 6 | Pure black (#000000) | Preview only |
| White | 7 | Pure white (#FFFFFF) | Preview only |

### Red Channel Processing Path

The only actively wired channel in v0.37:

```
Node 337 (Red output, slot 0)
  -> Node 570 (Reroute)
    -> Node 361 (MaskBlur+) — softens edges for smooth blending
      -> Node 356 (InpaintModelConditioning) — combines mask + prompt + image
        -> Node 363 (FluxGuidance) — applies Flux guidance
          -> Node 359 (BasicGuider)
            -> Node 357 (SamplerCustomAdvanced) — generates new content in masked region
              -> Node 358 (VAEDecode) — final output
```

The red-masked region is regenerated using the `flux_positive` prompt (Node 52). This is the **"Flux inpaint by Mask"** feature, which the author describes as **experimental**: "this feature is a real experiment and does not give always the desired results."

### Other Channels

Channels 1-7 all follow the same pattern: Node 337 output -> MaskToImage converter -> PreviewImage node. They are visualized in the UI but not connected to any processing. The infrastructure exists for future multi-region inpainting but has not been built out in v0.37.

### BASE CONFIG Toggles

Two toggles control this pipeline:

- **"Enable Process SEGMENTATION"** — Controls the upstream compute stage (Node 337 MaskFromRGBCMYBW+, Florence-2 building detection Node 580, SAM2 Node 585, compositing). This is where masks are **created**.
- **"Enable MASKS"** — Controls the downstream display/routing stage (8 MaskToImage converters, PreviewImage nodes, Reroute nodes 570/571 to detail transfer and region inpaint). This is where masks are **displayed and routed**.

These are **sequential** — Process SEGMENTATION feeds into MASKS.

| Process SEG | MASKS | Effect |
|-------------|-------|--------|
| off | off | No segmentation, no mask routing — safest without a color mask |
| on | off | AI runs but results don't get routed anywhere |
| off | on | MASKS group receives nothing, previews are empty |
| on | on | Full pipeline — needs a color mask in Node 338 |

---

## Auto Segmentation (Florence-2 + SAM2)

### How It Works

This is a **prompt-driven** automatic system. Florence-2 reads text descriptions of what to look for, finds those objects in the image, and SAM2 refines the detections into precise masks.

### Pipeline

```
Scene config detection prompts
  -> Node 550 (Florence2Run, caption_to_phrase_grounding)
    -> Node 114 (Florence2toCoordinates) — extracts bounding boxes
      -> Node 115 (Sam2Segmentation) — refines to precise masks

  -> Node 580 (Florence2Run, caption_to_phrase_grounding)
    -> Node 584 (Florence2toCoordinates) — extracts bounding boxes
      -> Node 585 (Sam2Segmentation) — refines to precise masks
```

### Detection Prompts

These come from the `detection` section of the scene config:

- **Node 550** (`object_detection`): "people, human, face, hand, feet, shoe, leg, bag, backpack, pet, dog, cat, gun, animal"
- **Node 580** (`building_detection`): "house, building, facade"

### Florence-2 Output

Florence-2's `caption_to_phrase_grounding` task produces a **colored visualization** where each detected phrase gets a unique color. This is the multi-colored segmentation image visible in the UI (many colors like cyan for sky, green for trees, magenta for foliage, olive for building walls, etc.). These colors are dynamically assigned per phrase — they are not fixed like the manual color mask.

The actual processing uses the **coordinates** passed to SAM2, not the colored image. The colored output is just for visualization.

### Independence from Manual Mask

The Florence-2 + SAM2 pipeline runs independently of the manual color mask system. It is **always automatic** and is not affected by the "Enable Process SEGMENTATION" or "Enable MASKS" toggles (those control the manual mask pipeline).

---

## Architectural Structure Preservation

The workflow uses several layered mechanisms to prevent the AI from inventing a completely different building. All models in the pipeline are **SDXL** (not SD 1.5) — the checkpoint, ControlNets, and IP-Adapter are all SDXL-specific.

### ControlNet (Primary Constraint)

Two SDXL ControlNets run simultaneously during the first-pass generation. These are the main things that lock the building's geometry:

- **Depth ControlNet** (`diffusers_xl_depth_full.safetensors`) — Takes the depth map and tells the model "the 3D spatial structure must match this." Preserves the building's volume, proportions, and spatial relationships.
- **Canny/Edge ControlNet** (`diffusers_xl_canny_full.safetensors`) — Takes the edge map and tells the model "the outlines and hard edges must follow these lines." Preserves the building's silhouette, window placement, rooflines, and geometric details.

Together, depth locks the **shape** and canny locks the **edges**. The model can change materials, lighting, textures, and vegetation, but the building's geometry stays anchored.

### Denoise Strength (How Much Freedom the AI Gets)

The workflow has two generation modes:

- **Mode 1** (denoise = 1.0, txt2img): The image is fully regenerated — but still guided by ControlNets. More creative, but the building structure comes entirely from ControlNet conditioning, not from original pixels.
- **Mode 2** (adjustable denoise, img2img): At lower values (e.g., 0.4-0.7), the model starts from the actual input image and only partially changes it. More of the original render is preserved.

### Detail Conservation (Re-injection)

Nodes 565, 573, 579 (`easy imageDetailTransfer`) transfer fine details from the input image into the output at each stage. This counteracts the AI's tendency to soften or warp architectural features like straight lines and sharp edges. See the next section for details.

### IP-Adapter (Optional Style Guidance)

The IP-Adapter (`ip-adapter-plus_sdxl_vit-h.safetensors`) takes a reference image and steers the overall visual style — lighting mood, color palette, material feel. It doesn't preserve structure directly, but guides the aesthetic.

### How They Stack

```
ControlNet Depth     ->  "Keep this 3D shape"
ControlNet Canny     ->  "Keep these edges and lines"
Denoise Strength     ->  "How much can you change overall?"
Detail Conservation  ->  "Re-inject these fine details from the input"
IP-Adapter           ->  "Make it look like this reference style"
Text Prompts         ->  "The building is red brick with cream panels..."
```

The ControlNets are doing the heavy lifting. Everything else is refinement on top.

---

## Detail Conservation

The author describes a feature called **"detail conservation"** that preserves specific architectural details from the input image through all AI generation stages.

From the video (7:40): "basically it transfers details from the image of your input. In this case I painted some vertical lines here for my facade — this is conserved through all the stages. If you turn this off you will most likely not get as much straight lines as we want to have in architecture."

This is handled by the `easy imageDetailTransfer` nodes (565, 573, 579) which blend input image details into the generated output. These nodes use masks from a **separate pipeline** (Node 571 <- Node 754 <- Node 749), not from the 8-channel color mask.

---

## Person Insertion

### How to Place a Person

1. Open the **base input image** (Node 79) in ComfyUI's **mask editor** (right-click the node)
2. Paint a red overlay on the area where you want the person placed
3. Enable the relevant toggles in BASE CONFIG:
   - "Enable PPL SEGMENTATION" = yes
   - "Enable PPL FLUX Generate" = yes
   - "Enable PPL FLUX Composite" = yes
4. Configure the person prompt in the scene config (`human_subject` section)

The mask editor's red overlay is **different** from the color segmentation map — it's ComfyUI's built-in mask system that attaches directly to the image node.

### Person Generation Pipeline

The workflow generates a person using Flux based on the `person_flux` prompt, segments it with Florence-2 + SAM2, then composites it into the scene. Key nodes:

- Node 408: Person Flux prompt
- Node 459: PPL Switch (selects Flux generation)
- Node 775: ImageCompositeMasked — composites person onto scene
- Node 579: easy imageDetailTransfer — blends with blend_factor 0.48, additive mode

### Note on Compositing Strength

Node 579 uses `blend_factor = 0.48` with `blend_mode = 'add'`. The person is composited onto a black background (Node 776, `color = 0`) before blending. This can make the person appear faint. Consider increasing the blend factor if the person is barely visible.

---

## BASE CONFIG Toggles

The **Fast Groups Bypasser** (Node 479, rgthree) provides master toggles for 19 node groups. Each toggle enables or disables (bypasses) a group of nodes.

### Toggle Reference

| Toggle | Group | Purpose |
|--------|-------|---------|
| Enable MODEL LOADERS | Model loading nodes | Load all AI models into memory |
| Enable INPUTS | Input handling (22 nodes) | All LoadImage nodes including Node 338 (mask) |
| Enable CONTROL | ControlNet config (35 nodes) | Node 456 SWITCH CNET + ControlNet apply nodes |
| Enable SAMPLER CONFIGURATION | Sampler settings | KSampler and noise configuration |
| Enable ControlNet Preprocessors + Extras | Preprocessing (22 nodes) | DepthAnythingV2, HED, edge detection — auto preprocessing |
| Enable MASKS | Mask display/routing (22 nodes) | MaskToImage converters, previews, reroute to detail transfer |
| Enable PPL SEGMENTATION | Person segmentation | Florence-2 + SAM2 for person detection |
| Enable PPL FLUX Generate | Person generation | Flux-based person generation from prompt |
| Enable PPL FLUX Composite | Person compositing | Blend generated person into scene |
| Enable PPL 3D INPAINT Detail | 3D inpaint (default: no) | Experimental 3D inpainting |
| Enable Process SEGMENTATION | Segmentation compute (12 nodes) | Florence-2 building detection, SAM2, MaskFromRGBCMYBW+ |
| Enable Process SDXL | SDXL generation | First-pass SDXL image generation |
| Enable Process FLUX | Flux detailing | Second-pass Flux detail enhancement |
| Enable Process UPSCALE | Upscaling | UltimateSDUpscale resolution increase |
| Enable Process ADD LOGO | Logo overlay | Image Overlay nodes for branding |
| Enable OUTPUT | Final output | Save/preview final images |
| Enable PREVIZ | Preview (default: no) | Preview visualization |
| Enable FLUX INPAINT DETAIL FROM MASK | Mask inpaint (default: no) | Experimental Flux inpaint by mask |
| Enable PPL_POSED_TBD | Posed person (default: no) | Future feature — not implemented |

### Recommended Settings for Single Input (No Manual Masks)

For running with just a base input image and auto preprocessing:

| Toggle | Setting | Why |
|--------|---------|-----|
| Enable INPUTS | yes | Need to load the base image |
| Enable CONTROL | yes | Need ControlNet configuration |
| Enable ControlNet Preprocessors + Extras | yes | Auto-generate depth + canny |
| Enable Process SEGMENTATION | **no** | No manual color mask provided |
| Enable MASKS | **no** | No masks to display/route |
| Enable Process SDXL | yes | First-pass generation |
| Enable Process FLUX | yes | Second-pass detailing |
| Enable Process UPSCALE | yes | Resolution increase |
| Enable Process ADD LOGO | **no** | Unless overlay images are set up |
| Node 456 SWITCH CNET | **2** | Use auto preprocessors instead of manual depth |

---

## Prompting Architecture

The workflow uses **16 text prompts** organized into 5 sections. Each prompt targets a specific node that controls a different aspect of the generation.

### Architecture (6 prompts)

| Name | Node | Purpose |
|------|------|---------|
| sdxl_positive | 5 | Primary SDXL prompt — describes the building and scene for first-pass generation |
| flux_positive | 52 | Primary Flux prompt — describes the building for second-pass detailing. Also used for red mask inpainting |
| flux_power_prompt | 116 | Additional Flux conditioning — building details and atmosphere |
| flux_object | 403 | Detailed building description for Flux object-focused generation |
| environment | 404 | Surrounding environment (landscaping, terrain, sky) |
| lighting_style | 405 | Lighting and photography style (sun direction, contrast, lens) |

The author keeps prompts separated by concern: "I like to keep it separated — the object and the environment and the light. It gets concatenated in the end so you can just put a very long prompt also in the first panel."

### Human Subject (5 prompts)

| Name | Node | Purpose |
|------|------|---------|
| person_flux | 408 | Describes the person to generate with Flux |
| person_generation | 396 | Person generation base prompt |
| person_framing | 82 | Camera framing for the person (fullbody, portrait, etc.) |
| photography_style | 482 | Photography style for person shots |
| portrait_framing | 484 | Portrait-specific framing |

### Background (1 prompt)

| Name | Node | Purpose |
|------|------|---------|
| sky_replacement | 386 | Sky/background replacement prompt |

### Detection (2 prompts)

| Name | Node | Purpose |
|------|------|---------|
| object_detection | 550 | Florence-2 object detection labels — comma-separated list of things to find |
| building_detection | 580 | Florence-2 building detection labels |

### Negative (2 prompts)

| Name | Node | Purpose |
|------|------|---------|
| negative_global | 296 | Global negative prompt (quality, artifacts, style exclusions) |
| negative_scene_specific | 298 | Scene-specific negatives (elements to avoid for this particular scene) |

---

## Scene Config System

Scene configs extract all 16 prompts into an editable JSON file, allowing you to switch between projects without manually editing nodes in the ComfyUI GUI.

### Files

```
runpod/
  configs/
    scene_default.json          # Default prompts (black tinyhouse in forest)
    scene_sped_center.json      # FBISD SPED Transportation Center
  scripts/
    patch_scene.py              # Extract/patch prompts: base workflow + config -> patched copy
    setup.py                    # Calls apply_scene_config() after downloading workflow
  workflows/
    archviz_v037_cuda.json      # Base template (NEVER modified)
```

### Usage

```bash
# Extract current prompts as a starting point
python3 runpod/scripts/patch_scene.py --extract \
  --workflow runpod/workflows/archviz_v037_cuda.json \
  --output runpod/configs/scene_myproject.json

# Patch workflow with custom prompts
python3 runpod/scripts/patch_scene.py \
  --workflow runpod/workflows/archviz_v037_cuda.json \
  --config runpod/configs/scene_myproject.json \
  --output /tmp/patched.json
```

### Deployment

When `/workspace/scene_config.json` exists on the RunPod pod, `setup.py` automatically patches the base workflow into `archviz_v037_cuda_custom.json`. The original is never modified.

### Config Format

```json
{
  "architecture": {
    "sdxl_positive": {
      "node_id": 5,
      "widget_index": 0,
      "prompt": "your prompt here"
    }
  }
}
```

Partial configs are supported — only the entries you include get patched.

---

## Models

### SDXL Checkpoint

The entire first-pass pipeline is **SDXL-based** (not SD 1.5). The checkpoint, both ControlNets, the IP-Adapter, and the LoRA slots are all SDXL-specific. SD 1.5 models are not compatible with this workflow.

The workflow ships with **RealVisXL_V4.0.safetensors** (6.5 GB), but the author uses **Juggernaut SDXL** in his video demonstration. Both are realistic photography-focused SDXL models. The choice of checkpoint affects the style and quality of the first-pass generation.

A Lightning variant (**realvisxlV50_v50LightningBakedvae.safetensors**) is also downloaded for faster 4-step generation when speed is preferred over quality.

### Full Model Inventory (16 models, ~49 GB)

| Model | Size | Purpose |
|-------|------|---------|
| RealVisXL_V4.0.safetensors | 6.5 GB | Primary SDXL checkpoint |
| realvisxlV50_v50LightningBakedvae.safetensors | 6.5 GB | Fast SDXL (4-step Lightning) |
| flux1-dev-Q8_0.gguf | 12 GB | Flux diffusion model |
| t5-v1_1-xxl-encoder-Q8_0.gguf | 4.7 GB | T5-XXL text encoder for Flux |
| clip_l.safetensors | 235 MB | CLIP-L text encoder |
| CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors | 2.4 GB | CLIP Vision for IP-Adapter |
| diffusers_xl_canny_full.safetensors | 2.3 GB | ControlNet — edge detection |
| diffusers_xl_depth_full.safetensors | 2.3 GB | ControlNet — depth |
| thibaud_xl_openpose.safetensors | 2.3 GB | ControlNet — pose |
| ip-adapter-plus_sdxl_vit-h.safetensors | 808 MB | IP-Adapter style transfer |
| depth_anything_v2_vitl.pth | 1.2 GB | Depth Anything V2 |
| depth_anything_vitl14.pth | 1.2 GB | Depth Anything V1 |
| 4x-UltraSharp.pth | 64 MB | ESRGAN 4x upscaler |
| ae.safetensors | 320 MB | Flux VAE |
| sam2.1_hiera_base_plus.safetensors | 308 MB | Segment Anything 2 |
| Florence-2-large/ | 1.5 GB | Florence-2 vision-language model |

### Compatibility Pins

| Package/Node | Pinned Version | Reason |
|-------------|----------------|--------|
| transformers | 4.51.3 | Florence-2 produces degenerate `<s><s><s>...` output on newer versions |
| ComfyUI-Florence2 | v1.0.7 (commit 6c766b1) | Latest uses `dtype=dtype` (Transformers V5 API), but 4.51.3 requires `torch_dtype=dtype` |

---

## RunPod Deployment

### First-Time Setup

```bash
wget -O /workspace/setup.py https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/scripts/setup.py
python3 /workspace/setup.py
```

Handles everything: ComfyUI configuration, 26 custom nodes, 16 models, compatibility pins, workflow installation.

### Subsequent Runs (After Pod Restart)

Models persist on the network volume. Python packages don't. Run setup to reinstall, then restart ComfyUI:

```bash
wget -O /workspace/setup.py https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/scripts/setup.py
python3 /workspace/setup.py
pkill -f 'python.*main.py'
cd /workspace/runpod-slim/ComfyUI && python3 main.py --listen 0.0.0.0 --port 8188
```

### With Custom Scene Config

```bash
wget -O /workspace/setup.py https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/scripts/setup.py
wget -O /workspace/scene_config.json https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/configs/scene_sped_center.json
python3 /workspace/setup.py
pkill -f 'python.*main.py'
cd /workspace/runpod-slim/ComfyUI && python3 main.py --listen 0.0.0.0 --port 8188
```

Open `archviz_v037_cuda_custom.json` in ComfyUI (not the base workflow).

---

## Known Issues and Fixes

### Florence-2 Degenerate Output

**Symptom**: Florence-2 outputs `<s><s><s>...` repeated tokens instead of meaningful captions.

**Cause**: Incompatible transformers version. Versions newer than 4.51.3 (especially V5) cause degenerate output.

**Fix**: `setup.py` pins `transformers==4.51.3`.

### ComfyUI-Florence2 dtype Error

**Symptom**: `Florence2ForConditionalGeneration.__init__() got an unexpected keyword argument 'dtype'`

**Cause**: Latest ComfyUI-Florence2 uses `dtype=dtype` (Transformers V5 API), but transformers 4.51.3 expects `torch_dtype=dtype`.

**Fix**: `setup.py` pins ComfyUI-Florence2 to v1.0.7 (commit `6c766b1`) which uses the correct parameter.

### Image Overlay "tuple index out of range"

**Symptom**: `tuple index out of range` error in efficiency-nodes Image Overlay node.

**Cause**: Overlay images (logos/credits) were replaced with 1x1 transparent PNGs. The `tensor2pil()` function calls `.squeeze()` which collapses a 1x1 mask to a 0-dimensional scalar.

**Fix**: `setup.py` creates `transparent_square.png` (1024x1024 RGBA) as a safe placeholder. User must update the LoadImage nodes (309, 301) in ComfyUI to reference `transparent_square.png`.

### python vs python3 on RunPod

**Symptom**: `bash: python: command not found` when restarting ComfyUI.

**Fix**: Use `python3` instead of `python`. All commands in documentation use `python3`.
