#!/usr/bin/env python3
"""
Patch ComfyUI workflow for CUDA/RunPod deployment.
Converts MPS device references to CUDA and optimizes precision settings.
"""

import json
import sys
from pathlib import Path


def patch_workflow(input_path: str, output_path: str) -> dict:
    """
    Patch workflow JSON for CUDA deployment.

    Args:
        input_path: Path to input workflow JSON
        output_path: Path to output patched workflow JSON

    Returns:
        Dictionary with counts of patches applied
    """
    with open(input_path) as f:
        workflow = json.load(f)

    patches = {
        'mps_to_cuda': 0,
        'fp32_to_fp16': 0,
        'eager_to_sdpa': 0,
    }

    # Handle both API format (flat dict) and UI format (nested with 'nodes')
    nodes = workflow.get('nodes', workflow) if isinstance(workflow, dict) else workflow

    # If it's the UI format, nodes is a list
    if isinstance(nodes, list):
        for node in nodes:
            if isinstance(node, dict) and 'widgets_values' in node:
                values = node['widgets_values']
                for i, val in enumerate(values):
                    if val == 'mps':
                        values[i] = 'cuda'
                        patches['mps_to_cuda'] += 1
                    elif val == 'fp32':
                        values[i] = 'fp16'
                        patches['fp32_to_fp16'] += 1
                    elif val == 'eager':
                        values[i] = 'sdpa'
                        patches['eager_to_sdpa'] += 1
    else:
        # API format: iterate over node dict
        for node_id, node in nodes.items():
            if isinstance(node, dict) and 'inputs' in node:
                inputs = node['inputs']
                # MPS -> CUDA device
                if inputs.get('device') == 'mps':
                    inputs['device'] = 'cuda'
                    patches['mps_to_cuda'] += 1
                # fp32 -> fp16 for VRAM efficiency
                if inputs.get('precision') == 'fp32':
                    inputs['precision'] = 'fp16'
                    patches['fp32_to_fp16'] += 1
                # eager -> sdpa attention for CUDA
                if inputs.get('attention') == 'eager':
                    inputs['attention'] = 'sdpa'
                    patches['eager_to_sdpa'] += 1

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    return patches


def main():
    if len(sys.argv) < 3:
        print("Usage: patch_workflow.py <input.json> <output.json>")
        print("       Patches MPS->CUDA, fp32->fp16, eager->sdpa")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    if not Path(input_path).exists():
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    patches = patch_workflow(input_path, output_path)

    print(f"Patched workflow saved to: {output_path}")
    print(f"  - MPS -> CUDA: {patches['mps_to_cuda']}")
    print(f"  - fp32 -> fp16: {patches['fp32_to_fp16']}")
    print(f"  - eager -> sdpa: {patches['eager_to_sdpa']}")

    if sum(patches.values()) == 0:
        print("  (No changes needed - workflow already CUDA-compatible)")


if __name__ == '__main__':
    main()
