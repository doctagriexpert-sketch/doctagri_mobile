#!/usr/bin/env python3
"""
06_package_artifact.py
Package final artifact with metadata and signature.
Copies model to assets/models/ and creates registry entry.
"""

import os
import json
import hashlib
import shutil
from datetime import datetime


def package_artifact(
    model_path: str,
    labels_file: str,
    output_dir: str,
    assets_models_dir: str,
    version: str,
    accuracy: float,
    mean: list = None,
    std: list = None,
) -> str:
    print(f"[6/6] Packaging artifact...")
    print(f"  Model    : {model_path}")
    print(f"  Version  : {version}")
    print(f"  Accuracy : {accuracy}")
    print(f"  Assets   : {assets_models_dir}")

    if mean is None:
        mean = [123.675, 116.28, 103.53]
    if std is None:
        std = [58.395, 57.12, 57.375]

    with open(model_path, "rb") as f:
        model_bytes = f.read()
    sha256 = hashlib.sha256(model_bytes).hexdigest()

    dest_path = os.path.join(assets_models_dir, "model.tflite")
    os.makedirs(assets_models_dir, exist_ok=True)
    shutil.copy2(model_path, dest_path)

    with open(labels_file) as f:
        labels = [l.strip() for l in f if l.strip()]

    registry_entry = {
        "version": version,
        "filename": "model.tflite",
        "sha256": sha256,
        "accuracy": accuracy,
        "mean": mean,
        "std": std,
        "input_shape": [1, 224, 224, 3],
        "num_classes": len(labels),
        "labels": labels,
        "released_at": datetime.now().isoformat(),
        "min_app_version": "1.0.0",
    }

    registry_file = os.path.join(output_dir, "registry.json")
    registry = []
    if os.path.exists(registry_file):
        with open(registry_file) as f:
            registry = json.load(f)

    registry = [e for e in registry if e["version"] != version]
    registry.append(registry_entry)

    with open(registry_file, "w") as f:
        json.dump(registry, f, indent=2)

    print(f"  SUCCESS: {dest_path}")
    print(f"  SHA256  : {sha256[:16]}...")
    print(f"  Registry: {registry_file}")

    return registry_file


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--labels_file", required=True)
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--assets_models_dir", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--accuracy", type=float, required=True)
    args = parser.parse_args()
    package_artifact(
        args.model_path,
        args.labels_file,
        args.output_dir,
        args.assets_models_dir,
        args.version,
        args.accuracy,
    )
