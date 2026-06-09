#!/usr/bin/env python3
"""
01_export_savedmodel.py
Export Keras model to TensorFlow SavedModel format.
"""

import os
import sys

TF_VERSION = "2.15.0"
KERAS_VERSION = "2.15.0"


def export_savedmodel(model_path: str, output_dir: str) -> str:
    print(f"[1/6] Exporting to SavedModel format...")
    print(f"  Input : {model_path}")
    print(f"  Output: {output_dir}")
    print(f"  TensorFlow : {TF_VERSION}")
    print(f"  Keras      : {KERAS_VERSION}")

    try:
        import tensorflow as tf
        print(f"  Loaded TensorFlow: {tf.__version__}")
    except ImportError:
        print("ERROR: TensorFlow not installed. Run: pip install tensorflow==2.15.0")
        sys.exit(1)

    model = tf.keras.models.load_model(model_path, compile=False)
    model.export(output_dir)
    print(f"  SUCCESS: Exported to {output_dir}")
    return output_dir


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--output_dir", required=True)
    args = parser.parse_args()
    export_savedmodel(args.model_path, args.output_dir)
