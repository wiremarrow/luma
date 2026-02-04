#!/usr/bin/env python3
"""
RunPod Setup Script for PH's Archviz ComfyUI Workflow
Uses huggingface_hub API directly (no CLI dependency)

This script handles the complete setup:
1. Downloads all 16 models (~49 GB) with SHA256 verification
2. Creates extra_model_paths.yaml for ComfyUI
3. Creates symlinks for custom nodes with hardcoded paths
4. Downloads the workflow JSON

Usage:
    wget -O /workspace/setup.py https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/scripts/setup.py
    python3 /workspace/setup.py

Prerequisites:
    - HuggingFace login for gated models (Flux VAE):
      python3 -c "from huggingface_hub import login; login()"
    - Accept license at: https://huggingface.co/black-forest-labs/FLUX.1-schnell
"""

import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path
from datetime import datetime

# =============================================================================
# SELF-BOOTSTRAP: Install huggingface-hub if needed
# =============================================================================

def ensure_huggingface_hub():
    """Install huggingface-hub if not available."""
    try:
        import huggingface_hub
        return True
    except ImportError:
        print("[INFO] Installing huggingface-hub...")
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "-q", "huggingface-hub"
        ])
        return True

ensure_huggingface_hub()

from huggingface_hub import hf_hub_download, snapshot_download

# =============================================================================
# CONFIGURATION
# =============================================================================

VOLUME_PATH = Path("/workspace")
MODELS_PATH = VOLUME_PATH / "models"
LOG_FILE = VOLUME_PATH / "download_log.txt"
MARKER_FILE = VOLUME_PATH / ".models_downloaded"

# Terminal colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
NC = "\033[0m"  # No Color

# =============================================================================
# MODEL MANIFEST
# All 16 models with their source repos, files, destinations, and SHA256 hashes
# =============================================================================

MODEL_MANIFEST = {
    # -------------------------------------------------------------------------
    # TIER 1: Official Organization Sources
    # -------------------------------------------------------------------------
    "tier1_official": {
        "description": "Official Organization Sources",
        "models": [
            {
                "name": "Flux VAE",
                "repo": "black-forest-labs/FLUX.1-schnell",
                "file": "ae.safetensors",
                "dest": "vae",
                "hash": "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38",
            },
            {
                "name": "CLIP-L",
                "repo": "comfyanonymous/flux_text_encoders",
                "file": "clip_l.safetensors",
                "dest": "clip",
                "hash": "660c6f5b1abae9dc498ac2d21e1347d2abdb0cf6c0c0c8576cd796491d9a6cdd",
            },
            {
                "name": "Florence-2-large",
                "repo": "microsoft/Florence-2-large",
                "file": None,  # Full repository download
                "dest": "LLM/Florence-2-large",
                "dest_is_absolute": True,  # Relative to VOLUME_PATH, not MODELS_PATH
                "hash": "4f38ce741c6b71188fe2b3419a55e11917a8a7b321ae2e63c61da0191b0ebad7",
                "hash_file": "model.safetensors",  # File to verify within repo
            },
        ],
    },
    # -------------------------------------------------------------------------
    # TIER 2: Original Paper Authors
    # -------------------------------------------------------------------------
    "tier2_authors": {
        "description": "Original Paper Authors",
        "models": [
            {
                "name": "ControlNet Canny",
                "repo": "lllyasviel/sd_control_collection",
                "file": "diffusers_xl_canny_full.safetensors",
                "dest": "controlnet",
                "hash": "80664d80e3f233371cb6921110d0a6b7a40c01571905463f9dde5637e7894ed3",
            },
            {
                "name": "ControlNet Depth",
                "repo": "lllyasviel/sd_control_collection",
                "file": "diffusers_xl_depth_full.safetensors",
                "dest": "controlnet",
                "hash": "8ba4dfaa1958f1f68e5dc7f9839f9ef4e153aef0d330291e5cf966c925f97477",
            },
            {
                "name": "ControlNet OpenPose",
                "repo": "lllyasviel/sd_control_collection",
                "file": "thibaud_xl_openpose.safetensors",
                "dest": "controlnet",
                "hash": "9e070426568a3c60c128ffb98c66cdc7a0ea21d0d8abb86f73564aaf2e0c6f42",
            },
            {
                "name": "Depth Anything V2",
                "repo": "depth-anything/Depth-Anything-V2-Large",
                "file": "depth_anything_v2_vitl.pth",
                "dest": "depth",
                "hash": "a7ea19fa0ed99244e67b624c72b8580b7e9553043245905be58796a608eb9345",
                "format_warning": ".pth format",
            },
            {
                "name": "Depth Anything V1",
                "repo": None,  # Direct URL download
                "url": "https://huggingface.co/spaces/LiheYoung/Depth-Anything/resolve/main/checkpoints/depth_anything_vitl14.pth",
                "file": "depth_anything_vitl14.pth",
                "dest": "depth",
                "hash": "6c6a383e33e51c5fdfbf31e7ebcda943973a9e6a1cbef1564afe58d7f2e8fe63",
                "format_warning": ".pth format",
            },
        ],
    },
    # -------------------------------------------------------------------------
    # TIER 3: Trusted Community Sources
    # -------------------------------------------------------------------------
    "tier3_community": {
        "description": "Trusted Community Sources",
        "models": [
            {
                "name": "Flux1-dev Q8_0",
                "repo": "city96/FLUX.1-dev-gguf",
                "file": "flux1-dev-Q8_0.gguf",
                "dest": "unet",
                "hash": "129032f32224bf7138f16e18673d8008ba5f84c1ec74063bf4511a8bb4cf553d",
                "format_warning": ".gguf format (city96)",
            },
            {
                "name": "T5-XXL Q8_0",
                "repo": "city96/t5-v1_1-xxl-encoder-gguf",
                "file": "t5-v1_1-xxl-encoder-Q8_0.gguf",
                "dest": "clip",
                "hash": "9ec60f6028534b7fe5af439fcb535d75a68592a9ca3fcdeb175ef89e3ee99825",
                "format_warning": ".gguf format (city96)",
            },
            {
                "name": "IP-Adapter Plus",
                "repo": "h94/IP-Adapter",
                "file": "sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors",
                "dest": "ipadapter",
                "hash": "3f5062b8400c94b7159665b21ba5c62acdcd7682262743d7f2aefedef00e6581",
                "flatten_from": "sdxl_models",  # Move from nested dir
            },
            {
                "name": "CLIP Vision",
                "repo": "fofr/comfyui",
                "file": "clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors",
                "dest": "clip_vision",
                "hash": "6ca9667da1ca9e0b0f75e46bb030f7e011f44f86cbfb8d5a36590fcd7507b030",
                "flatten_from": "clip_vision",  # Move from nested dir
            },
            {
                "name": "RealVisXL V4.0",
                "repo": "SG161222/RealVisXL_V4.0",
                "file": "RealVisXL_V4.0.safetensors",
                "dest": "checkpoints",
                "hash": "912c9dc74f5855175c31a7993f863a043ac8dcc31732b324cd05d75cd7e16844",
            },
            {
                "name": "RealVisXL V5.0 Lightning",
                "repo": "SG161222/RealVisXL_V5.0_Lightning",
                "file": "RealVisXL_V5.0_Lightning_fp16.safetensors",
                "dest": "checkpoints",
                "hash": "fabcadd9330dcc4f9702063428d40b9d4d07168d8acefc819b8d1d9db466b3ec",
                "rename_to": "realvisxlV50_v50LightningBakedvae.safetensors",
            },
            {
                "name": "4x-UltraSharp",
                "repo": "uwg/upscaler",
                "file": "ESRGAN/4x-UltraSharp.pth",
                "dest": "upscale_models",
                "hash": "a5812231fc936b42af08a5edba784195495d303d5b3248c24489ef0c4021fe01",
                "flatten_from": "ESRGAN",
                "format_warning": ".pth format",
            },
            {
                "name": "SAM 2.1",
                "repo": "Kijai/sam2-safetensors",
                "file": "sam2.1_hiera_base_plus.safetensors",
                "dest": "sam2",
                "hash": "eb4b5f725c8b68205aa05bbe6b27efc628b18b4b9c7b9bb8218991b86b9a4932",
            },
        ],
    },
}

# =============================================================================
# LOGGING
# =============================================================================

def log_to_file(message: str):
    """Append message to log file."""
    with open(LOG_FILE, "a") as f:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        f.write(f"[{timestamp}] {message}\n")

def log_info(message: str):
    print(f"{GREEN}[INFO]{NC} {message}")
    log_to_file(f"INFO: {message}")

def log_warn(message: str):
    print(f"{YELLOW}[WARN]{NC} {message}")
    log_to_file(f"WARN: {message}")

def log_error(message: str):
    print(f"{RED}[ERROR]{NC} {message}")
    log_to_file(f"ERROR: {message}")

def log_section(title: str):
    print(f"\n{BLUE}{'=' * 68}{NC}")
    print(f"{BLUE}  {title}{NC}")
    print(f"{BLUE}{'=' * 68}{NC}\n")

# =============================================================================
# HASH VERIFICATION
# =============================================================================

def verify_hash(file_path: Path, expected_hash: str) -> bool:
    """Verify SHA256 hash of a file."""
    if not expected_hash:
        return True

    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)

    actual_hash = sha256.hexdigest()

    if actual_hash == expected_hash:
        log_info(f"Hash verified: {file_path.name}")
        return True
    else:
        log_error(f"Hash mismatch for {file_path}!")
        log_error(f"  Expected: {expected_hash}")
        log_error(f"  Got:      {actual_hash}")
        return False

# =============================================================================
# DOWNLOAD FUNCTIONS
# =============================================================================

def download_file(
    repo_id: str,
    filename: str,
    dest_dir: Path,
    expected_hash: str = None,
    flatten_from: str = None,
    rename_to: str = None,
) -> bool:
    """
    Download a single file from HuggingFace.

    Args:
        repo_id: HuggingFace repo (e.g., "black-forest-labs/FLUX.1-schnell")
        filename: File path within repo (e.g., "ae.safetensors")
        dest_dir: Destination directory
        expected_hash: Optional SHA256 hash for verification
        flatten_from: If file is in nested dir, move it up
        rename_to: Rename file after download

    Returns:
        True if successful, False otherwise
    """
    # Determine final filename
    final_name = rename_to if rename_to else Path(filename).name
    final_path = dest_dir / final_name

    # Skip if already exists
    if final_path.exists():
        log_info(f"Exists: {final_name}")
        return True

    log_info(f"Downloading: {filename} from {repo_id}")

    try:
        # Download to dest_dir
        downloaded_path = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            local_dir=dest_dir,
            local_dir_use_symlinks=False,
        )
        downloaded_path = Path(downloaded_path)

        # Handle nested directory flattening
        if flatten_from:
            nested_path = dest_dir / flatten_from / Path(filename).name
            if nested_path.exists():
                shutil.move(str(nested_path), str(final_path))
                # Clean up nested directory
                nested_dir = dest_dir / flatten_from
                if nested_dir.exists():
                    shutil.rmtree(nested_dir, ignore_errors=True)
                log_info(f"Flattened {flatten_from}/ subdirectory")
        elif rename_to and downloaded_path.name != rename_to:
            # Rename if needed
            shutil.move(str(downloaded_path), str(final_path))
            log_info(f"Renamed to: {rename_to}")

        # Clean up .cache if present
        cache_dir = dest_dir / ".cache"
        if cache_dir.exists():
            shutil.rmtree(cache_dir, ignore_errors=True)

        # Verify hash
        if expected_hash:
            return verify_hash(final_path, expected_hash)

        return True

    except Exception as e:
        log_error(f"Download failed: {e}")
        return False

def download_url(url: str, dest_dir: Path, filename: str, expected_hash: str = None) -> bool:
    """Download a file directly from a URL using requests or urllib."""
    dest_path = dest_dir / filename

    if dest_path.exists():
        log_info(f"Exists: {filename}")
        return True

    log_info(f"Downloading: {filename}")

    try:
        import urllib.request
        urllib.request.urlretrieve(url, dest_path)

        if expected_hash:
            return verify_hash(dest_path, expected_hash)
        return True

    except Exception as e:
        log_error(f"Download failed: {e}")
        return False

def download_repo(repo_id: str, dest_dir: Path, hash_file: str = None, expected_hash: str = None) -> bool:
    """
    Download a full repository from HuggingFace.

    Args:
        repo_id: HuggingFace repo (e.g., "microsoft/Florence-2-large")
        dest_dir: Destination directory
        hash_file: Optional file within repo to verify
        expected_hash: Expected hash of hash_file

    Returns:
        True if successful, False otherwise
    """
    # Check if already downloaded
    marker = dest_dir / "model.safetensors"
    if marker.exists():
        log_info(f"Exists: {dest_dir.name}/")
        return True

    log_info(f"Downloading: {repo_id} (full repository)")

    try:
        dest_dir.mkdir(parents=True, exist_ok=True)

        snapshot_download(
            repo_id=repo_id,
            local_dir=dest_dir,
            local_dir_use_symlinks=False,
        )

        # Remove redundant pytorch_model.bin if present (Florence-2 has both)
        pytorch_bin = dest_dir / "pytorch_model.bin"
        if pytorch_bin.exists():
            pytorch_bin.unlink()
            log_info("Removed redundant pytorch_model.bin")

        # Verify hash if specified
        if hash_file and expected_hash:
            hash_path = dest_dir / hash_file
            if hash_path.exists():
                return verify_hash(hash_path, expected_hash)

        return True

    except Exception as e:
        log_error(f"Repository download failed: {e}")
        return False

# =============================================================================
# MAIN
# =============================================================================

def create_directories():
    """Create all required model directories."""
    dirs = [
        MODELS_PATH / "checkpoints",
        MODELS_PATH / "clip",
        MODELS_PATH / "clip_vision",
        MODELS_PATH / "controlnet",
        MODELS_PATH / "ipadapter",
        MODELS_PATH / "unet",
        MODELS_PATH / "vae",
        MODELS_PATH / "upscale_models",
        MODELS_PATH / "depth",
        MODELS_PATH / "sam2",
        VOLUME_PATH / "LLM",
        VOLUME_PATH / "input",
    ]

    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)

    log_info(f"Models directory: {MODELS_PATH}")
    log_info(f"LLM directory: {VOLUME_PATH / 'LLM'}")
    log_info(f"Input directory: {VOLUME_PATH / 'input'}")

def verify_flat_structure() -> int:
    """Verify no nested subdirectories remain. Returns error count."""
    errors = 0

    nested_checks = [
        (MODELS_PATH / "ipadapter" / "sdxl_models", "IP-Adapter"),
        (MODELS_PATH / "clip_vision" / "clip_vision", "CLIP Vision"),
        (MODELS_PATH / "upscale_models" / "ESRGAN", "UltraSharp"),
    ]

    for path, name in nested_checks:
        if path.exists():
            log_error(f"{name} nested directory not flattened!")
            errors += 1

    if errors == 0:
        log_info("All directories properly flattened")

    return errors

def count_files():
    """Count downloaded files by format."""
    safetensor_count = len(list(MODELS_PATH.rglob("*.safetensors"))) + \
                       len(list((VOLUME_PATH / "LLM").rglob("*.safetensors")))
    gguf_count = len(list(MODELS_PATH.rglob("*.gguf")))
    pth_count = len(list(MODELS_PATH.rglob("*.pth")))

    log_info("Downloaded files by format:")
    log_info(f"  .safetensors (SAFE):    {safetensor_count} files")
    log_warn(f"  .gguf (from city96):    {gguf_count} files")
    log_warn(f"  .pth (from authors):    {pth_count} files")

# =============================================================================
# COMFYUI CONFIGURATION
# =============================================================================

EXTRA_MODEL_PATHS_YAML = """luma:
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
"""

def configure_comfyui():
    """Configure ComfyUI model paths and create symlinks."""
    comfyui_path = VOLUME_PATH / "runpod-slim" / "ComfyUI"

    # Check if ComfyUI exists
    if not comfyui_path.exists():
        log_warn(f"ComfyUI not found at {comfyui_path}")
        log_warn("Skipping configuration - run this again after ComfyUI is installed")
        return False

    log_section("Configuring ComfyUI")

    # Create extra_model_paths.yaml
    yaml_path = comfyui_path / "extra_model_paths.yaml"
    log_info(f"Creating {yaml_path}")
    with open(yaml_path, "w") as f:
        f.write(EXTRA_MODEL_PATHS_YAML)
    log_info("Created extra_model_paths.yaml")

    # Create models directory if it doesn't exist
    models_dir = comfyui_path / "models"
    models_dir.mkdir(parents=True, exist_ok=True)

    # Create symlinks for custom nodes with hardcoded paths
    symlinks = [
        (MODELS_PATH / "sam2", models_dir / "sam2"),
        (VOLUME_PATH / "LLM", models_dir / "LLM"),
        (MODELS_PATH / "depth", models_dir / "depthanything"),
    ]

    for source, target in symlinks:
        if target.exists() or target.is_symlink():
            target.unlink() if target.is_symlink() else None
        try:
            target.symlink_to(source)
            log_info(f"Symlink: {target.name} -> {source}")
        except Exception as e:
            log_error(f"Failed to create symlink {target}: {e}")

    log_info("ComfyUI configuration complete")
    return True

def download_workflow():
    """Download the workflow JSON file."""
    workflow_url = "https://raw.githubusercontent.com/wiremarrow/luma/main/runpod/workflows/archviz_v037_cuda.json"

    # Try multiple possible locations
    comfyui_path = VOLUME_PATH / "runpod-slim" / "ComfyUI"
    workflows_dir = comfyui_path / "user" / "default" / "workflows"

    # Also save to /workspace for easy access
    workspace_dest = VOLUME_PATH / "archviz_v037_cuda.json"

    log_section("Downloading Workflow")

    try:
        import urllib.request

        # Download to workspace
        if not workspace_dest.exists():
            log_info(f"Downloading workflow to {workspace_dest}")
            urllib.request.urlretrieve(workflow_url, workspace_dest)
            log_info("Workflow downloaded to /workspace/")
        else:
            log_info("Workflow already exists in /workspace/")

        # Copy to ComfyUI workflows if directory exists
        if workflows_dir.exists():
            comfyui_dest = workflows_dir / "archviz_v037_cuda.json"
            if not comfyui_dest.exists():
                shutil.copy(workspace_dest, comfyui_dest)
                log_info("Workflow copied to ComfyUI workflows directory")

        return True
    except Exception as e:
        log_error(f"Failed to download workflow: {e}")
        return False

def main():
    print()
    print("=" * 72)
    print("  RUNPOD MODEL DOWNLOAD - PH's Archviz ComfyUI Workflow")
    print("  Using huggingface_hub Python API (no CLI dependency)")
    print("=" * 72)
    print()

    # Check if already downloaded
    if MARKER_FILE.exists():
        log_warn("Models already downloaded. Delete .models_downloaded to re-download.")
        log_warn(f"  rm {MARKER_FILE}")
        return 0

    # Initialize log
    log_to_file("=== Download started ===")

    # Create directories
    log_section("Creating Directory Structure")
    create_directories()

    # Download all models
    success_count = 0
    total_count = 0

    for tier_key, tier_data in MODEL_MANIFEST.items():
        log_section(f"Downloading {tier_data['description']}")

        for model in tier_data["models"]:
            total_count += 1
            name = model["name"]

            # Print format warning if present
            if model.get("format_warning"):
                log_warn(f"{name} ({model['format_warning']})...")
            else:
                log_info(f"{name}...")

            # Determine destination directory
            if model.get("dest_is_absolute"):
                dest_dir = VOLUME_PATH / model["dest"]
            else:
                dest_dir = MODELS_PATH / model["dest"]

            # Download based on type
            if model.get("url"):
                # Direct URL download
                success = download_url(
                    url=model["url"],
                    dest_dir=dest_dir,
                    filename=model["file"],
                    expected_hash=model.get("hash"),
                )
            elif model.get("file") is None:
                # Full repository download
                success = download_repo(
                    repo_id=model["repo"],
                    dest_dir=dest_dir,
                    hash_file=model.get("hash_file"),
                    expected_hash=model.get("hash"),
                )
            else:
                # Single file download
                success = download_file(
                    repo_id=model["repo"],
                    filename=model["file"],
                    dest_dir=dest_dir,
                    expected_hash=model.get("hash"),
                    flatten_from=model.get("flatten_from"),
                    rename_to=model.get("rename_to"),
                )

            if success:
                success_count += 1

    # Verification
    log_section("Post-Download Verification")

    # Clean up any remaining .cache directories
    for cache_dir in MODELS_PATH.rglob(".cache"):
        shutil.rmtree(cache_dir, ignore_errors=True)

    # Verify flat structure
    log_info("Verifying flat directory structure...")
    errors = verify_flat_structure()

    if errors > 0:
        log_error(f"{errors} directory structure errors found!")
        return 1

    # Count files
    count_files()

    # Mark as complete
    MARKER_FILE.touch()

    # Check if all models downloaded
    if success_count != total_count:
        log_error(f"Downloaded {success_count}/{total_count} models")
        log_error("Fix the failed downloads and run again")
        return 1

    log_info(f"All {total_count} models downloaded successfully!")

    # Configure ComfyUI (model paths + symlinks)
    configure_comfyui()

    # Download workflow
    download_workflow()

    # Completion
    log_section("Setup Complete")

    print()
    log_info("Verification commands:")
    print(f"  ls -lah {MODELS_PATH}/*/")
    print(f"  ls {VOLUME_PATH}/LLM/Florence-2-large/model.safetensors")
    print(f"  cat /workspace/runpod-slim/ComfyUI/extra_model_paths.yaml")
    print()
    log_info("Remaining manual step:")
    print("  1. Open ComfyUI (Connect -> HTTP Service [Port 8188])")
    print("  2. Install custom nodes via ComfyUI-Manager (see README Step 5)")
    print("  3. Load workflow: archviz_v037_cuda.json")
    print("  4. Test generation")
    print()
    log_info(f"Download log: {LOG_FILE}")

    log_to_file("=== Setup completed ===")

    return 0

if __name__ == "__main__":
    sys.exit(main())
