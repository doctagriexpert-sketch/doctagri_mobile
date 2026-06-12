#!/usr/bin/env python3
"""
04_validate_accuracy.py
Valide l'accuracy du modèle INT8 sur un set de test étiqueté (structure
`<dir>/<classe>/<image>`). Génère matrice de confusion et F1 par classe.

Le prétraitement et le post-traitement viennent de `app_inference.py`, source
UNIQUE alignée sur l'app Flutter (cf. point 2). Ne PAS réimplémenter ici : ce
serait rouvrir le bug de drift validation ↔ production.
"""

import os

import numpy as np

from app_inference import TFLiteModel, list_images, normalized_entropy


def validate_accuracy(
    model_path: str,
    test_images_dir: str,
    labels_file: str,
    expected_accuracy: float = 0.92,
) -> dict:
    print("[4/6] Validating accuracy...")
    print(f"  Model   : {model_path}")
    print(f"  Test dir: {test_images_dir}")
    print(f"  Labels  : {labels_file}")
    print(f"  Target  : > {expected_accuracy * 100:.0f}%")

    model = TFLiteModel(model_path, labels_file)
    print(
        f"  Input   : {model.input_size}x{model.input_size}, "
        f"dtype={np.dtype(model.input_dtype).name}"
    )
    print(
        f"  Output  : dtype={np.dtype(model.output_dtype).name}"
        + (f", scale={model.out_scale}, zero={model.out_zero}" if model.out_scale else "")
    )

    img_paths = list_images(test_images_dir)
    if not img_paths:
        raise FileNotFoundError(f"Aucune image trouvée dans {test_images_dir}")

    predictions, ground_truths, confidences, entropies = [], [], [], []
    for img_path in img_paths:
        probs = model.infer(img_path)
        pred_idx = int(np.argmax(probs))
        predictions.append(model.labels[pred_idx])
        confidences.append(float(probs[pred_idx]))
        entropies.append(normalized_entropy(probs))
        ground_truths.append(os.path.basename(os.path.dirname(img_path)))

    from sklearn.metrics import (
        accuracy_score,
        confusion_matrix,
        classification_report,
    )

    acc = accuracy_score(ground_truths, predictions)
    cm = confusion_matrix(ground_truths, predictions, labels=model.labels)
    report = classification_report(
        ground_truths, predictions, labels=model.labels, output_dict=True, zero_division=0
    )

    print(f"  Samples : {len(predictions)}")
    print(f"  Accuracy: {acc * 100:.2f}%")
    print(f"  Mean conf (top-1): {np.mean(confidences) * 100:.1f}%")
    print(f"  Mean entropy     : {np.mean(entropies):.3f}")
    print("  PASS" if acc >= expected_accuracy else f"  FAIL (target: {expected_accuracy * 100:.0f}%)")

    return {
        "accuracy": acc,
        "mean_top1_confidence": float(np.mean(confidences)),
        "mean_entropy": float(np.mean(entropies)),
        "num_samples": len(predictions),
        "confusion_matrix": cm.tolist(),
        "classification_report": report,
        "passed": acc >= expected_accuracy,
    }


if __name__ == "__main__":
    import argparse
    import json

    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--test_images_dir", required=True)
    parser.add_argument("--labels_file", required=True)
    parser.add_argument("--expected_accuracy", type=float, default=0.92)
    args = parser.parse_args()
    result = validate_accuracy(
        args.model_path, args.test_images_dir, args.labels_file, args.expected_accuracy
    )
    print(
        json.dumps(
            {
                "accuracy": result["accuracy"],
                "mean_top1_confidence": result["mean_top1_confidence"],
                "mean_entropy": result["mean_entropy"],
                "num_samples": result["num_samples"],
                "passed": result["passed"],
            },
            indent=2,
        )
    )
