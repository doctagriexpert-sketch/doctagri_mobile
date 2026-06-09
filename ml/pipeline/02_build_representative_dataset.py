#!/usr/bin/env python3
"""
02_build_representative_dataset.py
Build a representative dataset for INT8 calibration.
Requires 500-1000 real leaf disease images.
"""

import os
import numpy as np
from PIL import Image


def build_representative_dataset(
    source_dir: str,
    output_file: str,
    num_samples: int = 500,
    target_size: tuple = (224, 224),
) -> str:
    print(f"[2/6] Building representative dataset...")
    print(f"  Source dir : {source_dir}")
    print(f"  Output     : {output_file}")
    print(f"  Num samples: {num_samples}")
    print(f"  Target size: {target_size}")

    image_files = []
    for ext in ["*.jpg", "*.jpeg", "*.png", "*.webp"]:
        import glob
        image_files.extend(glob.glob(os.path.join(source_dir, "**", ext), recursive=True))

    if len(image_files) < num_samples:
        print(f"WARNING: Found {len(image_files)} images, need {num_samples}")
        print("  Using available images with repetition if needed")

    images = []
    for i in range(num_samples):
        img_path = image_files[i % len(image_files)]
        img = Image.open(img_path).convert("RGB").resize(target_size, Image.BILINEAR)
        img_array = np.array(img, dtype=np.uint8)
        images.append(img_array)

    dataset = np.stack(images)
    np.save(output_file, dataset)
    print(f"  SUCCESS: Saved {dataset.shape} to {output_file}")
    return output_file


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--source_dir", required=True)
    parser.add_argument("--output_file", required=True)
    parser.add_argument("--num_samples", type=int, default=500)
    args = parser.parse_args()
    build_representative_dataset(args.source_dir, args.output_file, args.num_samples)
