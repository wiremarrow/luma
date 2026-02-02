# Luma - ComfyUI Custom Nodes Security Audit

**Audit Date:** 2025-01-31
**Audit Version:** 1.0
**Auditor:** Claude Code Security Analysis

---

## Executive Summary

This document provides a comprehensive security audit of all ComfyUI custom node packages required for the PH's Archviz x AI workflow. The audit identified **2 critical CVEs** (now patched) and **1 malware incident** in the dependency chain. All packages have been classified by risk level with mitigation strategies.

**Overall Assessment: LOW-MEDIUM RISK** (with mitigations applied)

---

## Critical Security Findings

### CVE-2025-45076: ComfyUI-Manager Remote Code Execution

| Field | Details |
|-------|---------|
| **Package** | ltdrdata/ComfyUI-Manager |
| **Severity** | CRITICAL |
| **Status** | PATCHED in v3.31+ |
| **Description** | RCE via malicious custom node installation through untrusted channel repositories |
| **Reported** | 2025-03-11 |
| **Patched** | 2025-03-12 |
| **Reference** | [Doyensec Advisory](https://www.doyensec.com/resources/Doyensec_Advisory_ComfyUI_Manager_RCE_via_Custom_Node_Install.pdf) |
| **Mitigation** | Use v3.31+ (v3.38+ recommended for additional fixes) |

### CVE-2025-67303: ComfyUI-Manager Insecure File Location

| Field | Details |
|-------|---------|
| **Package** | ltdrdata/ComfyUI-Manager |
| **Severity** | HIGH |
| **Status** | PATCHED in v3.38+ |
| **Description** | Manager data stored in unprotected path, accessible via web APIs when using --listen |
| **Reference** | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2025-67303) |
| **Mitigation** | Use v3.38+ with System User Protection API |

### CVE-2026-22777: ComfyUI-Manager CRLF Injection

| Field | Details |
|-------|---------|
| **Package** | ltdrdata/ComfyUI-Manager |
| **Severity** | MEDIUM |
| **Status** | PATCHED in v3.39.2+ and v4.0.5+ |
| **Description** | CRLF injection via ConfigParser allows arbitrary config.ini modification |
| **Reference** | [GitHub Advisory GHSA-562r-8445-54r2](https://github.com/Comfy-Org/ComfyUI-Manager/security/advisories/GHSA-562r-8445-54r2) |
| **Mitigation** | Use v3.39.2+ (current version 3.39.2 is safe) |

### CVE-2025-6092: ComfyUI Core XSS

| Field | Details |
|-------|---------|
| **Package** | comfyanonymous/ComfyUI (core) |
| **Severity** | MEDIUM |
| **Status** | Affects ≤0.3.39 |
| **Description** | XSS vulnerability in /upload/image endpoint (incomplete fix of previous issue) |
| **Reference** | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2025-6092) |
| **Mitigation** | Update ComfyUI core to latest version |

### CVE-2024-21575: ComfyUI-Impact-Pack Path Traversal

| Field | Details |
|-------|---------|
| **Package** | ltdrdata/ComfyUI-Impact-Pack |
| **Severity** | CRITICAL |
| **Status** | PATCHED |
| **Description** | Missing validation of image.filename in POST requests to /upload/temp endpoint allows arbitrary file write |
| **Impact** | Arbitrary file write to filesystem, potential RCE |
| **Reference** | [GitHub Advisory GHSA-6mx8-m8xp-f2vc](https://github.com/advisories/GHSA-6mx8-m8xp-f2vc) |
| **Mitigation** | Update to latest version |

### Ultralytics Cryptocurrency Mining Malware

| Field | Details |
|-------|---------|
| **Dependency** | ultralytics 8.3.41, 8.3.42, 8.3.45, 8.3.46 |
| **Severity** | CRITICAL |
| **Status** | BLOCKED |
| **Description** | Malicious versions download and execute XMRig cryptocurrency miner to /tmp/ultralytics_runner |
| **Affected Package** | ComfyUI-Impact-Pack (uses ultralytics) |
| **Attack Vector** | Supply chain attack via GitHub Actions cache poisoning |
| **Reference** | [PyPI Attack Analysis](https://blog.pypi.org/posts/2024-12-11-ultralytics-attack-analysis/), [Issue #843](https://github.com/ltdrdata/ComfyUI-Impact-Pack/issues/843) |
| **Mitigation** | Pin ultralytics version < 8.3.41 or use 8.3.47+ |

---

## Package Risk Classification

### TIER 1: Core Infrastructure (MEDIUM Risk - Required)

| Package | Maintainer | Stars | CVEs | Mitigation |
|---------|------------|-------|------|------------|
| ltdrdata/ComfyUI-Manager | Dr.Lt.Data | 13.4k | CVE-2025-45076 | Use v3.38+ |

### TIER 2: Verified Low-Risk Packages (LOW Risk)

| Package | Maintainer | Stars | License | Notes |
|---------|------------|-------|---------|-------|
| Fannovel16/comfyui_controlnet_aux | Fannovel16 | 3.7k | - | No CVEs, active |
| city96/ComfyUI-GGUF | city96 | 3.2k | Apache-2.0 | Model loader only |
| pythongosssss/ComfyUI-Custom-Scripts | pythongosssss | 2.9k | - | UI-only JavaScript |
| ssitu/ComfyUI_UltimateSDUpscale | ssitu | 1.4k | - | Wrapper pattern |
| Kosinkadink/ComfyUI-Advanced-ControlNet | Kosinkadink | 394 | GPL-3.0 | Active development |
| cubiq/ComfyUI_IPAdapter_plus | Matteo Spinelli | 5.8k | GPL-3.0 | Maintenance mode |
| cubiq/ComfyUI_essentials | Matteo Spinelli | 1k | MIT | Maintenance mode |
| kijai/ComfyUI-KJNodes | Jukka Seppänen | 2.3k | MIT | Reputable maintainer |
| kijai/ComfyUI-DepthAnythingV2 | Jukka Seppänen | - | MIT | Same maintainer |
| kijai/ComfyUI-Florence2 | Jukka Seppänen | 1.6k | MIT | Same maintainer |
| kijai/ComfyUI-segment-anything-2 | Jukka Seppänen | - | - | Same maintainer |
| rgthree/rgthree-comfy | Regis Gaughan III | 2.6k | MIT | Google Tech Lead |
| melMass/comfy_mtb | Mel Massadian | 672 | MIT | VFX professional |
| yolain/ComfyUI-Easy-Use | yolain | 2.3k | GPL | Security page exists |
| BadCafeCode/masquerade-nodes-comfyui | BadCafeCode | 460 | - | Dependency-free |
| Suzie1/ComfyUI_Comfyroll_CustomNodes | Akatsuzi | 1.1k | - | Comfyroll co-founder |
| evanspearman/ComfyMath | evanspearman | 135 | Apache-2.0 | Math only |
| jamesWalker55/comfyui-various | jamesWalker55 | 177 | - | Utility nodes |
| EllangoK/ComfyUI-post-processing-nodes | Karun | 242 | - | Core contributor |

### TIER 3: Medium-Risk Packages (MEDIUM Risk - Monitor)

| Package | Maintainer | Stars | Risk Factors | Mitigation |
|---------|------------|-------|--------------|------------|
| ltdrdata/ComfyUI-Impact-Pack | Dr.Lt.Data | 2.9k | CVE + malware dep | Pin ultralytics, update |
| jags111/efficiency-nodes-comfyui | jags111 | - | Community fork | Monitor updates |
| sipherxyz/comfyui-art-venture | sipherxyz | 331 | Limited maintainer data | Monitor updates |
| chrisgoringe/cg-image-filter | chrisgoringe | 336 | Replacement package | Stable |

### TIER 4: Archived Packages (HIGH Risk - Required for Workflow)

> ⚠️ **WARNING**: These packages are archived and receive NO security updates.
> They are installed because the workflow requires them. Use for INTERNAL purposes only.
> Consider forking these repositories to maintain security patches.

| Package | Status | Nodes Used | Risk | Action |
|---------|--------|------------|------|--------|
| WASasquatch/was-node-suite-comfyui | ARCHIVED June 2025 | 22 nodes | HIGH | Monitor, consider fork |
| theUpsider/ComfyUI-Logic | ARCHIVED June 2025 | 12 nodes | HIGH | Monitor, consider fork |

**Nodes required from was-node-suite-comfyui (22):**
- Image Resize, BLIP Analyze Image, Text Concatenate, Text String
- Number Input, True/False, Text to Conditioning, Image Bounds
- Image Crop Location, Samples Passthrough, Create Grid Image, Image Flip
- Image Levels Adjustment, Image Blending Mode, Image High Pass Filter
- CLIP Text Encode (NSP), Number to Seed, Number to Float, Mask Fill Region
- Image Bounds to Console, Random Number, Logic Boolean

**Nodes required from ComfyUI-Logic (12):**
- Int, Float, Bool, String, Compare, IfExecute
- DebugPrint, And, Or, Not, ClampInt, ClampFloat

### EXCLUDED: Archived Packages (Not Required)

| Package | Status | Last Update | Replacement |
|---------|--------|-------------|-------------|
| chrisgoringe/cg-image-picker | ARCHIVED | May 2025 | cg-image-filter (installed) |
| palant/image-resize-comfyui | ARCHIVED | May 2024 | Nodes in was-node-suite |

---

## Maintainer Verification

### Verified Professional Backgrounds

| Maintainer | Identity | Background | Verification |
|------------|----------|------------|--------------|
| ltdrdata | Dr.Lt.Data | Core ComfyUI ecosystem maintainer | GitHub activity, community recognition |
| kijai | Jukka Seppänen | Finland, 5.6k GitHub followers | Professional ML work |
| rgthree | Regis Gaughan III | Technical Lead at Google | LinkedIn, personal website |
| cubiq | Matteo Spinelli | Prolific developer | Multiple successful projects |
| melMass | Mel Massadian | VFX Supervisor/TD, France | HuggingFace profile, Blender community |
| Kosinkadink | - | AnimateDiff-Evolved author (3.3k stars) | Major project success |
| chrisgoringe | - | ComfyUI guide author | cg-use-everywhere (906 stars) |
| palant | Wladimir Palant | Security researcher | malicious-extensions-list project |
| EllangoK | Karun | NYC-based developer | ComfyUI core CORS PR merged |

---

## Ecosystem Threat Intelligence (2024-2025)

### Known Attack Vectors in ComfyUI Custom Nodes

1. **Cryptocurrency Miners**
   - 30-day delayed activation to avoid detection
   - 500+ star packages have been compromised
   - Connect to mining pools via non-standard ports

2. **Data Exfiltration**
   - Workflow files uploaded to external servers
   - Browser passwords and credit cards stolen (LLMVISION variants)
   - Discord C2 channels for command and control

3. **Remote Code Execution**
   - `eval()` and `exec()` abuse
   - Obfuscated Python code
   - Base64-encoded payloads

4. **Supply Chain Attacks**
   - Malicious dependencies (ultralytics incident)
   - Typosquatting on package names
   - Compromised maintainer accounts

### ComfyUI Security Mitigations (v3.38+)

- AI + static analysis scanning for threats
- Ban on incremental `eval()`/`exec()` additions
- Code obfuscation blocking within registry
- Base64 encoding detection in suspicious contexts

---

## Model Source Security Audit

A comprehensive security audit of all model download sources has been completed.
See **MODEL_SOURCES.md** for full details including:

- File format security analysis (.safetensors, .gguf, .pth)
- Source verification for each model (official vs community)
- SHA256 hashes for integrity verification
- Platform security assessments (HuggingFace, CivitAI, OpenModelDB)

### Model Format Security Summary

| Format | Risk Level | Notes |
|--------|------------|-------|
| .safetensors | SAFE | Cannot execute code by design |
| .gguf | CAUTION | Parsing vulnerabilities (arxiv:2505.23786) |
| .pth | DANGEROUS | Pickle can execute arbitrary code |
| .ckpt | DANGEROUS | Same as .pth |

**Recommendation:** Use `download_models.sh` which only downloads from verified sources.

---

## Security Recommendations

### Before Installation

1. **Verify Package Sources**
   - Only install from official GitHub repositories
   - Check star counts and recent activity
   - Verify maintainer identity when possible

2. **Review Dependencies**
   - Check requirements.txt for each package
   - Avoid packages with outdated or vulnerable dependencies

### After Installation

1. **Verify Versions**
   ```bash
   # Check ComfyUI-Manager version (must be 3.38+)
   git -C ComfyUI/custom_nodes/ComfyUI-Manager describe --tags

   # Check ultralytics version (must NOT be 8.3.41 or 8.3.42)
   pip show ultralytics | grep Version
   ```

2. **Monitor for Suspicious Activity**
   - Check for unexpected network connections
   - Monitor GPU/CPU usage for mining activity
   - Review any new files created outside expected directories

### Ongoing Maintenance

- **Weekly:** Check GitHub for security advisories on installed packages
- **Monthly:** Update packages and re-run security scan
- **Before Production:** Run full dependency audit with `pip-audit`

---

## References

### Security Advisories
- [Doyensec CVE-2025-45076 Advisory](https://www.doyensec.com/resources/Doyensec_Advisory_ComfyUI_Manager_RCE_via_Custom_Node_Install.pdf)
- [GitHub Advisory GHSA-6mx8-m8xp-f2vc](https://github.com/advisories/GHSA-6mx8-m8xp-f2vc)
- [ComfyUI Impact-Pack Virus Alert](https://comfyui-wiki.com/en/news/2024-12-05-comfyui-impact-pack-virus-alert)
- [Akira Stealer Distribution Issue #11791](https://github.com/Comfy-Org/ComfyUI/issues/11791)

### Security Guidance
- [ComfyUI Standards - Registry Requirements](https://docs.comfy.org/registry/standards)
- [Snyk Labs: Hacking ComfyUI Through Custom Nodes](https://labs.snyk.io/resources/hacking-comfyui-through-custom-nodes/)
- [ComfyUI 2025 Jan Security Update](https://blog.comfy.org/p/comfyui-2025-jan-security-update)
- [ComfyUI Custom Nodes Security Guide 2025](https://apatero.com/blog/comfyui-custom-nodes-security-guide-protect-yourself-2025)

---

## Audit Methodology

This audit was conducted using:

1. **Web Search** - Security advisories, CVE databases, GitHub issues
2. **GitHub Analysis** - Repository metrics, maintainer profiles, commit history
3. **Dependency Analysis** - requirements.txt review, known vulnerable packages
4. **Code Pattern Analysis** - Search for dangerous patterns (eval, exec, subprocess)
5. **Community Intelligence** - ComfyUI wiki, Reddit, Discord reports

---

*This audit is provided for informational purposes. Security situations evolve rapidly. Always verify current status before deployment.*
