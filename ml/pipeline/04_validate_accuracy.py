#!/usr/bin/env python3
"""
04_validate_accuracy.py
Validate INT8 model accuracy against hold-out test set.
Generates confusion matrix and F1 per class.
"""

import os
import numpy as np
from collections import defaultdict


def validate_accuracy(
    model_path: str,
    test_images_dir: str,
    labels_file: str,
    expected_accuracy: float = 0.92,
) -> dict:
    print(f"[4/6] Validating accuracy...")
    print(f"  Model   : {model_path}")
    print(f"  Test dir: {test_images_dir}")
    print(f"  Labels  : {labels_file}")
    print(f"  Target  : > {expected_accuracy * 100:.0f}%")

    import tensorflow as tf

    with open(labels_file) as f:
        labels = [l.strip() for l in f if l.strip()]

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    predictions = []
    ground_truths = []

    import glob
    for img_path in glob.glob(os.path.join(test_images_dir, "**", "*.*"), recursive=True):
        if not any(img_path.lower().endswith(ext) for ext in [".jpg", ".jpeg", ".png", ".webp"]):
            continue

        from PIL import Image
        img = Image.open(img_path).convert("RGB").resize((224, 224))
        img_array = np.array(img, dtype=np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        interpreter.set_tensor(input_details[0]["index"], img_array)
        interpreter.invoke()

        output = interpreter.tensor(output_details[0]["index"])()
        pred_label = labels[np.argmax(output)]

        predictions.append(pred_label)
        gt_label = os.path.basename(os.path.dirname(img_path))
        ground_truths.append(gt_label)

    from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
    acc = accuracy_score(ground_truths, predictions)
    cm = confusion_matrix(ground_truths, predictions, labels=labels)
    report = classification_report(ground_truths, predictions, labels=labels, output_dict=True)

    print(f"  Accuracy: {acc * 100:.2f}%")
    print(f"  PASS" if acc >= expected_accuracy else f"  FAIL (target: {expected_accuracy * 100:.0f}%)")

    return {
        "accuracy": acc,
        "confusion_matrix": cm.tolist(),
        "classification_report": report,
        "passed": acc >= expected_accuracy,
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--test_images_dir", required=True)
    parser.add_argument("--labels_file", required=True)
    parser.add_argument("--expected_accuracy", type=float, default=0.92)
    args = parser.parse_args()
    result = validate_accuracy(
        args.model_path, args.test_images_dir, args.labels_file, args.expected_accuracy
    )
    print(result)
