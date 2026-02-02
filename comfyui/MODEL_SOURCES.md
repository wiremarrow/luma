# Luma - Model Sources Security Audit

**Audit Date:** 2026-01-31
**Audit Version:** 2.0

---

## File Format Security Reference

| Format | Security Level | Code Execution Risk | Recommendation |
|--------|----------------|---------------------|----------------|
| **.safetensors** | EXCELLENT | None - cannot execute code by design | Always prefer |
| **.gguf** | GOOD | Parsing vulnerabilities exist (see arxiv:2505.23786) | Use from trusted sources |
| **.pth/.pt** | DANGEROUS | Arbitrary code execution via pickle | Official sources only |
| **.ckpt** | DANGEROUS | Same as .pth | Avoid, convert to safetensors |

**References:**
- [Safetensors Security Audit - Trail of Bits](https://www.trailofbits.com/documents/2023-03-eleutherai-huggingface-safetensors-securityreview.pdf)
- [GGUF Quantization Vulnerabilities](https://arxiv.org/abs/2505.23786)
- [Pickle Security Risks - Rapid7](https://www.rapid7.com/blog/post/from-pth-to-p0wned-abuse-of-pickle-files-in-ai-model-supply-chains/)

---

## TIER 1: Official Organization Sources (HIGHEST TRUST)

### black-forest-labs/FLUX.1-schnell - VAE

| Field | Value |
|-------|-------|
| **File** | ae.safetensors |
| **Size** | 335 MB |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/black-forest-labs/FLUX.1-schnell |
| **Maintainer** | Black Forest Labs (Official) |
| **Verification** | Official release with enterprise security practices |
| **License** | Apache-2.0 |
| **SHA256** | `afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38` |

### facebook/sam2.1-hiera-base-plus - Segmentation

| Field | Value |
|-------|-------|
| **File** | model.safetensors |
| **Size** | 323.5 MB |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/facebook/sam2.1-hiera-base-plus |
| **Maintainer** | Meta AI (Official) |
| **Verification** | Official Meta research release |
| **License** | Apache-2.0 |

### microsoft/Florence-2-large - Vision Model

| Field | Value |
|-------|-------|
| **File** | Auto-downloaded by ComfyUI |
| **Size** | ~1.5 GB |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/microsoft/Florence-2-large |
| **Maintainer** | Microsoft Research (Official) |
| **Verification** | Official Microsoft release |
| **License** | MIT |

### comfyanonymous/flux_text_encoders - CLIP Encoders

| Field | Value |
|-------|-------|
| **File** | clip_l.safetensors |
| **Size** | ~250 MB |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/comfyanonymous/flux_text_encoders |
| **Maintainer** | comfyanonymous (ComfyUI creator) |
| **Verification** | Official ComfyUI ecosystem |
| **Notes** | Specifically optimized for ComfyUI DualClipLoader |

---

## TIER 2: Original Author Sources (HIGH TRUST)

### lllyasviel/sd_control_collection - ControlNet Models

| Field | Value |
|-------|-------|
| **Files** | diffusers_xl_canny_full.safetensors, diffusers_xl_depth_full.safetensors |
| **Size** | ~2.5 GB each |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/lllyasviel/sd_control_collection |
| **Maintainer** | Lvmin Zhang (ControlNet paper author) |
| **Verification** | Original researcher, CVPR publications |
| **License** | OpenRAIL |

### lllyasviel/sd_control_collection - OpenPose ControlNet

| Field | Value |
|-------|-------|
| **File** | thibaud_xl_openpose.safetensors |
| **Size** | ~2.5 GB |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/lllyasviel/sd_control_collection |
| **Maintainer** | Lvmin Zhang (ControlNet author) |
| **Verification** | Original researcher, model included in official collection |
| **Note** | Thibaud's model included in lllyasviel's curated collection |

### LiheYoung/Depth-Anything-V2 - Depth Estimation

| Field | Value |
|-------|-------|
| **File** | depth_anything_v2_vitl.pth |
| **Size** | ~350 MB |
| **Format** | pth (CAUTION - pickle) |
| **Source** | https://huggingface.co/depth-anything/Depth-Anything-V2-Large |
| **Maintainer** | LiheYoung (original researcher) |
| **Verification** | Published at CVPR 2024 (v1), NeurIPS 2024 (v2) |
| **License** | Apache-2.0 (Small), CC-BY-NC-4.0 (Base/Large) |
| **Security Note** | .pth format uses pickle - only safe because from original author |

---

## TIER 3: Reputable Community Sources (MEDIUM-HIGH TRUST)

### city96/FLUX.1-dev-gguf - Flux.1 Quantized

| Field | Value |
|-------|-------|
| **File** | flux1-dev-Q8_0.gguf |
| **Size** | ~12 GB |
| **Format** | gguf (CAUTION) |
| **Source** | https://huggingface.co/city96/FLUX.1-dev-gguf |
| **Maintainer** | city96 (community contributor) |
| **Original Model** | black-forest-labs/FLUX.1-dev |
| **Verification** | Well-known quantization contributor |
| **Security Note** | GGUF has documented parsing vulnerabilities (arxiv:2505.23786). Risk acceptable from trusted source. |

### city96/t5-v1_1-xxl-encoder-gguf - T5 Text Encoder

| Field | Value |
|-------|-------|
| **File** | t5-v1_1-xxl-encoder-Q8_0.gguf |
| **Size** | ~5 GB |
| **Format** | gguf (CAUTION) |
| **Source** | https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf |
| **Maintainer** | city96 (same as above) |
| **Original Model** | Google T5 v1.1 XXL |

### h94/IP-Adapter - IP-Adapter Models

| Field | Value |
|-------|-------|
| **Files** | sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors, sdxl_models/image_encoder/model.safetensors |
| **Size** | ~100 MB (adapter), ~2.5 GB (CLIP vision encoder) |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/h94/IP-Adapter |
| **Maintainer** | h94 (community, Tencent research-based) |
| **Verification** | Based on official Tencent AI Lab research |
| **Original Research** | https://github.com/tencent-ailab/IP-Adapter |
| **Note** | CLIP vision encoder in sdxl_models/image_encoder/ for SDXL compatibility |

### SG161222/RealVisXL - SDXL Checkpoints

| Field | Value |
|-------|-------|
| **Files** | RealVisXL_V4.0.safetensors, realvisxlV50_v50LightningBakedvae.safetensors |
| **Size** | ~6.5 GB each |
| **Format** | safetensors (SAFE) |
| **Source** | https://huggingface.co/SG161222/RealVisXL_V4.0, https://huggingface.co/SG161222/RealVisXL_V5.0_Lightning |
| **Maintainer** | SG161222 (established model creator) |
| **Verification** | Tens of thousands of downloads, positive community reviews |
| **Alternative** | Also available on CivitAI with verified badge |

### uwg/upscaler - UltraSharp Upscaler

| Field | Value |
|-------|-------|
| **File** | 4x-UltraSharp.pth |
| **Size** | ~64 MB |
| **Format** | pth (CAUTION - pickle) |
| **Source** | https://huggingface.co/uwg/upscaler/blob/main/ESRGAN/4x-UltraSharp.pth |
| **Original Creator** | Kim2091 (established ESRGAN developer) |
| **Alternative Sources** | OpenModelDB, CivitAI |
| **Security Note** | .pth format - verified from known upscaler developer |

---

## Platform Security Assessment

### HuggingFace

| Aspect | Assessment |
|--------|------------|
| **Trust Level** | HIGH |
| **Malware Scanning** | Pickle scanning for .pth/.ckpt files |
| **Integrity** | SHA256 hashes available for all files |
| **Authentication** | Token-based for private/gated models |
| **Recommendation** | Preferred source for all models |

### CivitAI

| Aspect | Assessment |
|--------|------------|
| **Trust Level** | HIGH |
| **Malware Scanning** | ClamAV + Picklescan |
| **Integrity** | Verified badge system |
| **Incidents** | No major security breaches documented |
| **Recommendation** | Safe alternative for SDXL checkpoints |

### OpenModelDB

| Aspect | Assessment |
|--------|------------|
| **Trust Level** | MEDIUM |
| **Malware Scanning** | Not documented |
| **Integrity** | Basic file hosting |
| **Age** | Newer platform |
| **Recommendation** | Use for upscaler models, verify hashes |

---

## Download Verification Checklist

Before using any model:

- [ ] Verify file downloaded from documented source URL
- [ ] Check SHA256 hash matches (where available)
- [ ] Confirm file format is as expected (.safetensors preferred)
- [ ] For .pth files, verify source is from original author/trusted repo
- [ ] Log download timestamp and source for audit trail

---

## References

- [Safetensors GitHub](https://github.com/huggingface/safetensors)
- [HuggingFace Security - Pickle Scanning](https://huggingface.co/docs/hub/security-pickle)
- [CivitAI Model Safety Checks](https://github.com/civitai/civitai/wiki/Model-Safety-Checks)
- [Trail of Bits - Fickling ML Scanner](https://github.com/trailofbits/fickling)
- [GGUF Vulnerabilities - Databricks](https://www.databricks.com/blog/ggml-gguf-file-format-vulnerabilities)

---

*This audit is for internal use. Security situations evolve - verify current status before production deployment.*
