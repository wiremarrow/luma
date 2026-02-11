#!/usr/bin/env python3
"""
Patch ComfyUI workflow with scene-specific prompts from a config file.

The base workflow stays untouched. This script reads it + a config,
and writes a patched copy.

Usage:
    # Extract current prompts into a config file:
    python3 patch_scene.py --extract --workflow base.json --output config.json

    # Patch workflow with a config:
    python3 patch_scene.py --workflow base.json --config scene.json --output patched.json
"""

import argparse
import json
import sys
from pathlib import Path

# Node IDs containing scene-specific prompts, grouped by section.
# Used by --extract mode to know which nodes to pull from.
SCENE_NODES = {
    "architecture": {
        "sdxl_positive":     {"node_id": 5,   "widget_index": 0},
        "flux_positive":     {"node_id": 52,  "widget_index": 0},
        "flux_power_prompt": {"node_id": 116, "widget_index": 0},
        "flux_object":       {"node_id": 403, "widget_index": 0},
        "environment":       {"node_id": 404, "widget_index": 0},
        "lighting_style":    {"node_id": 405, "widget_index": 0},
    },
    "human_subject": {
        "person_flux":       {"node_id": 408, "widget_index": 0},
        "person_generation": {"node_id": 396, "widget_index": 0},
        "person_framing":    {"node_id": 82,  "widget_index": 0},
        "photography_style": {"node_id": 482, "widget_index": 0},
        "portrait_framing":  {"node_id": 484, "widget_index": 0},
    },
    "background": {
        "sky_replacement":   {"node_id": 386, "widget_index": 0},
    },
    "detection": {
        "object_detection":  {"node_id": 550, "widget_index": 0},
        "building_detection":{"node_id": 580, "widget_index": 0},
    },
    "negative": {
        "negative_global":         {"node_id": 296, "widget_index": 0},
        "negative_scene_specific": {"node_id": 298, "widget_index": 0},
    },
}


def load_json(path):
    with open(path) as f:
        return json.load(f)


def save_json(data, path):
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def build_node_lookup(workflow):
    """Build {node_id: node} lookup from workflow nodes list."""
    nodes = workflow.get("nodes", [])
    return {node["id"]: node for node in nodes if "id" in node}


def extract_prompts(workflow):
    """Extract current prompts from workflow into config format."""
    lookup = build_node_lookup(workflow)

    config = {
        "_description": "Scene prompts for archviz workflow. Edit 'prompt' values to customize.",
    }

    for section_name, entries in SCENE_NODES.items():
        section = {}
        for entry_name, meta in entries.items():
            node_id = meta["node_id"]
            widget_index = meta["widget_index"]

            node = lookup.get(node_id)
            if node and "widgets_values" in node:
                values = node["widgets_values"]
                if widget_index < len(values):
                    section[entry_name] = {
                        "node_id": node_id,
                        "widget_index": widget_index,
                        "prompt": values[widget_index],
                    }
                else:
                    print(f"[WARN] Node {node_id}: widget_index {widget_index} out of range", file=sys.stderr)
            else:
                print(f"[WARN] Node {node_id} not found in workflow", file=sys.stderr)

        config[section_name] = section

    return config


def patch_workflow(workflow, config):
    """Patch workflow node prompts from config. Returns (workflow, patch_count)."""
    # Build node_id -> (widget_index, prompt) from config
    patches = {}
    for section_key, section in config.items():
        if section_key.startswith("_") or not isinstance(section, dict):
            continue
        for entry_key, entry in section.items():
            if entry_key.startswith("_") or not isinstance(entry, dict):
                continue
            if "node_id" in entry and "prompt" in entry:
                node_id = entry["node_id"]
                widget_index = entry.get("widget_index", 0)
                patches[node_id] = (widget_index, entry["prompt"])

    # Apply patches
    patched = 0
    nodes = workflow.get("nodes", [])
    for node in nodes:
        nid = node.get("id")
        if nid in patches and "widgets_values" in node:
            widget_index, prompt = patches[nid]
            if widget_index < len(node["widgets_values"]):
                node["widgets_values"][widget_index] = prompt
                patched += 1

    return workflow, patched, len(patches)


def main():
    parser = argparse.ArgumentParser(description="Patch ComfyUI workflow with scene prompts")
    parser.add_argument("--workflow", required=True, help="Base workflow JSON (read-only)")
    parser.add_argument("--config", help="Scene config JSON")
    parser.add_argument("--output", help="Output path (required)")
    parser.add_argument("--extract", action="store_true", help="Extract prompts from workflow into config format")
    args = parser.parse_args()

    if not args.output:
        parser.error("--output is required")

    workflow = load_json(args.workflow)

    if args.extract:
        config = extract_prompts(workflow)
        save_json(config, args.output)
        count = sum(len(s) for k, s in config.items() if not k.startswith("_"))
        print(f"Extracted {count} prompts -> {args.output}")
        return 0

    if not args.config:
        parser.error("--config is required when not using --extract")

    config = load_json(args.config)
    workflow, patched, total = patch_workflow(workflow, config)
    save_json(workflow, args.output)
    print(f"Patched {patched}/{total} prompts -> {args.output}")

    if patched < total:
        print(f"[WARN] {total - patched} config entries had no matching node", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
