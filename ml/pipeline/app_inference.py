#!/usr/bin/env python3
"""
app_inference.py
Source UNIQUE du prétraitement et du post-traitement côté Python, alignée sur
l'app Flutter (lib/core/ml/image_preprocessor.dart, model_manager.dart,
diagnosis_repository_impl.dart).

But : que tout script du pipeline (04 validation, 07 analyse terrain, futurs
scripts de calibration) « voie » exactement ce que voit l'app. Dupliquer ce
code dans chaque script rouvrirait le bug de drift corrigé au point 2 (le
script de validation prétraitait différemment de l'app).

Comportements répliqués depuis l'app :
  - Resize bilinéaire vers la taille d'entrée LUE du modèle (160 vs 224).
  - Entrée uint8 brute (0-255) OU float32 ImageNet (pixel-mean)/std, selon le
    dtype d'entrée du modèle.
  - Sortie uint8 déquantifiée (raw - zero) * scale.
  - Si la sortie est déjà une distribution de probabilités (softmax intégré au
    .tflite, cas des modèles embarqués) : recalibration p^(1/T) renormalisée,
    PAS de second softmax. Sinon : softmax(logits / T). T=1.0 par défaut.
  - Labels lus depuis .txt (un par ligne) ou .json (array).
"""

import os
import glob
import json

import numpy as np

IMAGENET_MEAN = np.array([123.675, 116.28, 103.53], dtype=np.float32)
IMAGENET_STD = np.array([58.395, 57.12, 57.375], dtype=np.float32)
IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp")


def load_labels(labels_file: str) -> list:
    """Lit les labels depuis un .txt (un par ligne) ou un .json (array)."""
    with open(labels_file, encoding="utf-8") as f:
        raw = f.read()
    if raw.lstrip().startswith("["):
        return [str(x) for x in json.loads(raw)]
    return [line.strip() for line in raw.splitlines() if line.strip()]


def list_images(images_dir: str) -> list:
    return [
        p
        for p in glob.glob(os.path.join(images_dir, "**", "*.*"), recursive=True)
        if p.lower().endswith(IMAGE_EXTS)
    ]


def preprocess(img_path: str, input_size: int, input_dtype) -> np.ndarray:
    """Produit le tenseur d'entrée (1, H, W, 3) attendu par le modèle.

    Resize BILINEAR ; uint8 brut si le modèle attend de l'uint8, sinon
    normalisation ImageNet. Voir module docstring.
    """
    from PIL import Image

    img = Image.open(img_path).convert("RGB").resize(
        (input_size, input_size), Image.BILINEAR
    )
    pixels = np.array(img, dtype=np.uint8)
    if input_dtype == np.uint8:
        return pixels[np.newaxis, ...]
    normalized = (pixels.astype(np.float32) - IMAGENET_MEAN) / IMAGENET_STD
    return normalized[np.newaxis, ...].astype(np.float32)


def looks_like_probabilities(values: np.ndarray) -> bool:
    """La sortie ressemble-t-elle à une distribution de probabilités
    (valeurs >= ~0 et somme ≈ 1) plutôt qu'à des logits ?

    Réplique looksLikeProbabilities côté Dart. Tolérance sur la somme pour le
    bruit de quantification (uint8 somme à 255/256 ≈ 0.996).
    """
    if values.size == 0:
        return False
    if np.any(values < -1e-3):
        return False
    s = float(values.sum())
    return 0.9 < s < 1.1


def to_probabilities(raw_output: np.ndarray, temperature: float = 1.0) -> np.ndarray:
    """Convertit la sortie brute (déjà déquantifiée) en distribution de
    probabilités EXACTEMENT comme l'app, en évitant le double softmax.
    """
    raw = raw_output.astype(np.float64)
    if looks_like_probabilities(raw):
        # temperatureScaleProbabilities : p^(1/T) renormalisé (T=1 -> renorm).
        if temperature == 1.0:
            s = raw.sum()
            return (raw / s) if s > 0 else np.full_like(raw, 1.0 / raw.size)
        scaled = np.where(raw > 0, np.power(np.clip(raw, 0, None), 1.0 / temperature), 0.0)
        s = scaled.sum()
        return (scaled / s) if s > 0 else np.full_like(raw, 1.0 / raw.size)
    # calibratedSoftmax : softmax(logits / T).
    z = raw / temperature
    z = z - z.max()
    e = np.exp(z)
    return e / e.sum()


def normalized_entropy(probs: np.ndarray) -> float:
    """Entropie de Shannon normalisée ∈ [0, 1] (cf. normalizedEntropy Dart).
    0 = certitude, 1 = uniforme. Comparable entre modèles (÷ log n).
    """
    p = np.asarray(probs, dtype=np.float64)
    if p.size < 2:
        return 0.0
    nz = p[p > 0]
    h = float(-(nz * np.log(nz)).sum())
    return float(np.clip(h / np.log(p.size), 0.0, 1.0))


class TFLiteModel:
    """Charge un .tflite et expose l'inférence alignée sur l'app."""

    def __init__(self, model_path: str, labels_file: str, temperature: float = 1.0):
        import tensorflow as tf

        self.labels = load_labels(labels_file)
        self.temperature = temperature
        self._it = tf.lite.Interpreter(model_path=model_path)
        self._it.allocate_tensors()
        self._inp = self._it.get_input_details()[0]
        self._out = self._it.get_output_details()[0]
        self.input_size = int(self._inp["shape"][1])
        self.input_dtype = self._inp["dtype"]
        self.output_dtype = self._out["dtype"]
        self.out_scale, self.out_zero = self._out["quantization"]
        self.num_classes = int(self._out["shape"][-1])
        if self.num_classes != len(self.labels):
            raise ValueError(
                f"Mismatch: modèle {self.num_classes} classes vs "
                f"{len(self.labels)} labels."
            )

    def infer(self, img_path: str) -> np.ndarray:
        """Retourne la distribution de probabilités pour une image (alignée app)."""
        x = preprocess(img_path, self.input_size, self.input_dtype)
        self._it.set_tensor(self._inp["index"], x)
        self._it.invoke()
        raw = self._it.get_tensor(self._out["index"])[0]
        if self.output_dtype == np.uint8 and self.out_scale:
            raw = (raw.astype(np.float32) - self.out_zero) * self.out_scale
        return to_probabilities(raw, self.temperature)
