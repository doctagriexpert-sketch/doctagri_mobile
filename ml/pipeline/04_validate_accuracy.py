#!/usr/bin/env python3
"""
04_validate_accuracy.py
Validate INT8 model accuracy against a hold-out test set.
Generates a confusion matrix and per-class F1.

CRITICAL — le prétraitement ici reproduit EXACTEMENT celui de l'app Flutter
(lib/core/ml/image_preprocessor.dart + diagnosis_repository_impl.dart). Sans
cela, l'accuracy mesurée ne reflète pas ce que le modèle voit en production et
le chiffre est trompeur.

Comportements répliqués depuis l'app :
  - Taille d'entrée LUE depuis le modèle (jamais codée en dur) :
    plantvillage = 160x160, cassava = 224x224.
  - Resize bilinéaire (img.Interpolation.linear dans l'app, Image.BILINEAR ici),
    identique au jeu de calibration de 02_build_representative_dataset.py.
  - Type d'entrée LU depuis le modèle :
      * entrée uint8   -> on envoie les pixels bruts 0-255 (branche uint8Pixels
        de l'app ET ce sur quoi la quantification INT8 a été calibrée).
      * entrée float32 -> on envoie (pixel - mean) / std normalisé ImageNet
        (branche float32Input de l'app).
  - Sortie uint8 déquantifiée : (raw - zero_point) * scale, puis argmax.

Les labels sont lus depuis un .txt (un par ligne) OU un .json (array de
strings), comme ModelManager._parseLabels dans l'app.
"""

import os
import glob
import json

import numpy as np

# Mêmes constantes que lib/core/ml/image_preprocessor.dart
IMAGENET_MEAN = np.array([123.675, 116.28, 103.53], dtype=np.float32)
IMAGENET_STD = np.array([58.395, 57.12, 57.375], dtype=np.float32)

IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp")


def load_labels(labels_file: str) -> list:
    """Lit les labels depuis un .txt (un par ligne) ou un .json (array).

    Réplique ModelManager._parseLabels : plantvillage utilise class_names.json,
    cassava utilise labels.txt.
    """
    with open(labels_file, encoding="utf-8") as f:
        raw = f.read()
    if raw.lstrip().startswith("["):
        decoded = json.loads(raw)
        return [str(x) for x in decoded]
    return [line.strip() for line in raw.splitlines() if line.strip()]


def preprocess(img_path: str, input_size: int, input_dtype) -> np.ndarray:
    """Produit le tenseur d'entrée (1, H, W, 3) attendu par le modèle.

    - Resize BILINEAR vers input_size (lu depuis le modèle).
    - Si le modèle attend de l'uint8 : pixels bruts 0-255 (ce sur quoi la
      quantification a été calibrée, cf. 02/03).
    - Sinon (float32) : normalisation ImageNet (pixel - mean) / std.
    """
    from PIL import Image

    img = Image.open(img_path).convert("RGB").resize(
        (input_size, input_size), Image.BILINEAR
    )
    pixels = np.array(img, dtype=np.uint8)  # (H, W, 3), 0-255

    if input_dtype == np.uint8:
        return pixels[np.newaxis, ...]  # (1, H, W, 3) uint8

    normalized = (pixels.astype(np.float32) - IMAGENET_MEAN) / IMAGENET_STD
    return normalized[np.newaxis, ...].astype(np.float32)


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

    import tensorflow as tf

    labels = load_labels(labels_file)

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    # Taille et type d'entrée LUS depuis le modèle — c'est le cœur du correctif.
    # plantvillage attend 160x160 uint8, cassava 224x224 (uint8 ou float selon
    # l'export). On s'adapte au lieu de coder en dur 224 + /255.
    input_shape = input_details["shape"]  # [1, H, W, 3]
    input_size = int(input_shape[1])
    input_dtype = input_details["dtype"]
    output_dtype = output_details["dtype"]
    out_scale, out_zero = output_details["quantization"]

    print(f"  Input   : {input_size}x{input_size}, dtype={np.dtype(input_dtype).name}")
    print(
        f"  Output  : dtype={np.dtype(output_dtype).name}"
        + (f", scale={out_scale}, zero={out_zero}" if out_scale else "")
    )

    num_classes = int(output_details["shape"][-1])
    if num_classes != len(labels):
        raise ValueError(
            f"Mismatch: le modèle produit {num_classes} classes mais "
            f"{len(labels)} labels ont été chargés."
        )

    predictions = []
    ground_truths = []
    confidences = []

    img_paths = [
        p
        for p in glob.glob(os.path.join(test_images_dir, "**", "*.*"), recursive=True)
        if p.lower().endswith(IMAGE_EXTS)
    ]
    if not img_paths:
        raise FileNotFoundError(f"Aucune image trouvée dans {test_images_dir}")

    for img_path in img_paths:
        x = preprocess(img_path, input_size, input_dtype)
        interpreter.set_tensor(input_details["index"], x)
        interpreter.invoke()

        raw = interpreter.get_tensor(output_details["index"])[0]

        # Déquantification de la sortie uint8 (mêmes maths que l'app :
        # (raw - zeroPoint) * scale). N'affecte pas l'argmax mais rend la
        # confiance comparable à celle affichée dans l'app.
        if output_dtype == np.uint8 and out_scale:
            logits = (raw.astype(np.float32) - out_zero) * out_scale
        else:
            logits = raw.astype(np.float32)

        probs = _softmax(logits)
        pred_idx = int(np.argmax(probs))

        predictions.append(labels[pred_idx])
        confidences.append(float(probs[pred_idx]))
        ground_truths.append(os.path.basename(os.path.dirname(img_path)))

    from sklearn.metrics import (
        accuracy_score,
        confusion_matrix,
        classification_report,
    )

    acc = accuracy_score(ground_truths, predictions)
    cm = confusion_matrix(ground_truths, predictions, labels=labels)
    report = classification_report(
        ground_truths, predictions, labels=labels, output_dict=True, zero_division=0
    )

    print(f"  Samples : {len(predictions)}")
    print(f"  Accuracy: {acc * 100:.2f}%")
    print(f"  Mean conf (top-1): {np.mean(confidences) * 100:.1f}%")
    print("  PASS" if acc >= expected_accuracy else f"  FAIL (target: {expected_accuracy * 100:.0f}%)")

    return {
        "accuracy": acc,
        "mean_top1_confidence": float(np.mean(confidences)),
        "num_samples": len(predictions),
        "confusion_matrix": cm.tolist(),
        "classification_report": report,
        "passed": acc >= expected_accuracy,
    }


def _softmax(logits: np.ndarray) -> np.ndarray:
    """Softmax stable numériquement (max-subtract trick), comme l'app."""
    shifted = logits - np.max(logits)
    exps = np.exp(shifted)
    return exps / np.sum(exps)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--test_images_dir", required=True)
    parser.add_argument("--labels_file", required=True)
    parser.add_argument("--expected_accuracy", type=float, default=0.92)
    args = parser.parse_args()
    result = validate_accuracy(
        args.model_path,
        args.test_images_dir,
        args.labels_file,
        args.expected_accuracy,
    )
    # Résumé compact ; le rapport complet par classe est dans result.
    print(
        json.dumps(
            {
                "accuracy": result["accuracy"],
                "mean_top1_confidence": result["mean_top1_confidence"],
                "num_samples": result["num_samples"],
                "passed": result["passed"],
            },
            indent=2,
        )
    )
