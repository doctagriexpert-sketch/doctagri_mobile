#!/usr/bin/env python3
"""
03_quantize_int8.py
Quantize Float32 model to INT8 using representative dataset.
Target: < 3 MB, accuracy loss < 2%
"""

import os
import numpy as np


def quantize_int8(
    savedmodel_dir: str,
    representative_dataset_file: str,
    output_dir: str,
    model_name: str = "model_int8",
) -> str:
    print(f"[3/6] Quantizing to INT8...")
    print(f"  SavedModel  : {savedmodel_dir}")
    print(f"  Calib data  : {representative_dataset_file}")
    print(f"  Output dir  : {output_dir}")

    import tensorflow as tf

    dataset = np.load(representative_dataset_file)
    def representative_dataset_gen():
        for i in range(len(dataset)):
            yield [dataset[i].astype(np.float32)]

    converter = tf.lite.TFLiteConverter.from_saved_model(savedmodel_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset_gen
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.uint8
    converter.inference_output_type = tf.uint8

    tflite_model = converter.convert()
    output_file = os.path.join(output_dir, f"{model_name}.tflite")
    with open(output_file, "wb") as f:
        f.write(tflite_model)

    size_mb = os.path.getsize(output_file) / (1024 * 1024)
    print(f"  SUCCESS: {output_file} ({size_mb:.2f} MB)")

    if size_mb > 3.0:
        print(f"WARNING: Model size {size_mb:.2f} MB exceeds 3 MB target")

    return output_file


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--savedmodel_dir", required=True)
    parser.add_argument("--representative_dataset_file", required=True)
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--model_name", default="model_int8")
    args = parser.parse_args()
    quantize_int8(
        args.savedmodel_dir,
        args.representative_dataset_file,
        args.output_dir,
        args.model_name,
    )
