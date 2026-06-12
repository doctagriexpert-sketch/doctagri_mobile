#!/usr/bin/env python3
"""
07_field_domain_analysis.py
Analyse NON-SUPERVISÉE du décalage de domaine labo→terrain — aucune étiquette
requise.

Contexte (point 4) : le modèle est entraîné en laboratoire (PlantVillage :
feuilles détachées, fond uniforme). On veut savoir, AVANT d'investir dans du
réétiquetage ou un détecteur OOD coûteux, à quel point les photos de terrain
sortent du domaine d'entraînement — en comparant les DISTRIBUTIONS de sortie du
modèle (confiance, entropie, marge), qui ne demandent pas de vérité terrain.

Produit :
  1. Stats des photos terrain : histogrammes confiance/entropie/marge, classes
     prédites, % qui seraient abstenues par les seuils actuels de l'app.
  2. Seuils recommandés (confiance, entropie) pour un taux d'abstention cible,
     calibrés de façon non-supervisée sur la distribution terrain.
  3. Si un set labo de référence est fourni : distance de Kolmogorov-Smirnov
     entre terrain et labo sur la confiance et l'entropie → un CHIFFRE de
     l'ampleur du décalage (0 = distributions identiques, 1 = disjointes).

Usage :
  python 07_field_domain_analysis.py \
      --model_path assets/models/plantvillage/model_int8.tflite \
      --labels_file assets/models/plantvillage/class_names.json \
      --field_dir data/field_photos \
      [--lab_dir data/plantvillage_sample] \
      [--target_abstention 0.3] [--report report.json]
"""

import json
from collections import Counter

import numpy as np

# Seuils actuels de l'app (diagnosis_repository_impl.dart) — repère de lecture.
APP_CONFIDENCE_THRESHOLD = 0.5
APP_AMBIGUITY_MARGIN = 0.1
APP_MAX_ENTROPY = 0.6


# ── Fonctions de stats pures (testables sans TensorFlow) ──

def ks_distance(a, b) -> float:
    """Statistique de Kolmogorov-Smirnov à deux échantillons : sup |F_a - F_b|.
    0 = distributions identiques, 1 = totalement disjointes. Sans dépendance
    scipy (calcul direct sur les CDF empiriques).
    """
    a = np.sort(np.asarray(a, dtype=np.float64))
    b = np.sort(np.asarray(b, dtype=np.float64))
    if a.size == 0 or b.size == 0:
        return 0.0
    grid = np.concatenate([a, b])
    cdf_a = np.searchsorted(a, grid, side="right") / a.size
    cdf_b = np.searchsorted(b, grid, side="right") / b.size
    return float(np.max(np.abs(cdf_a - cdf_b)))


def abstention_rate(confidences, margins, entropies) -> float:
    """Fraction d'images que les seuils ACTUELS de l'app abstiendraient
    (confiance < 0.5 OU marge < 0.1 OU entropie > 0.6)."""
    c = np.asarray(confidences)
    m = np.asarray(margins)
    e = np.asarray(entropies)
    if c.size == 0:
        return 0.0
    flagged = (c < APP_CONFIDENCE_THRESHOLD) | (m < APP_AMBIGUITY_MARGIN) | (e > APP_MAX_ENTROPY)
    return float(flagged.mean())


def recommend_thresholds(confidences, entropies, target_abstention: float) -> dict:
    """Seuils non-supervisés pour atteindre ~`target_abstention` sur le terrain.

    - confiance : on abstient sous le quantile `target` des confiances.
    - entropie  : on abstient au-dessus du quantile `1 - target` des entropies.
    Chacun pris isolément vise le taux cible ; combinés ils abstiennent un peu
    plus (recouvrement partiel).
    """
    c = np.asarray(confidences, dtype=np.float64)
    e = np.asarray(entropies, dtype=np.float64)
    t = float(np.clip(target_abstention, 0.0, 1.0))
    return {
        "target_abstention": t,
        "confidence_threshold": float(np.quantile(c, t)) if c.size else None,
        "entropy_threshold": float(np.quantile(e, 1.0 - t)) if e.size else None,
    }


def summarize(values) -> dict:
    v = np.asarray(values, dtype=np.float64)
    if v.size == 0:
        return {"n": 0}
    return {
        "n": int(v.size),
        "mean": float(v.mean()),
        "std": float(v.std()),
        "p10": float(np.quantile(v, 0.10)),
        "p50": float(np.quantile(v, 0.50)),
        "p90": float(np.quantile(v, 0.90)),
    }


# ── Collecte (TensorFlow) ──

def collect(model, images_dir: str) -> dict:
    """Passe toutes les images d'un dossier dans le modèle et collecte
    confiance top-1, marge top-1/top-2, entropie, classe prédite."""
    from app_inference import list_images, normalized_entropy

    paths = list_images(images_dir)
    confidences, margins, entropies, preds = [], [], [], []
    for p in paths:
        probs = model.infer(p)
        order = np.argsort(probs)[::-1]
        top1 = float(probs[order[0]])
        top2 = float(probs[order[1]]) if probs.size > 1 else 0.0
        confidences.append(top1)
        margins.append(top1 - top2)
        entropies.append(normalized_entropy(probs))
        preds.append(model.labels[int(order[0])])
    return {
        "num_images": len(paths),
        "confidences": confidences,
        "margins": margins,
        "entropies": entropies,
        "predicted_labels": preds,
    }


def analyze(
    model_path: str,
    labels_file: str,
    field_dir: str,
    lab_dir: str = None,
    target_abstention: float = 0.3,
) -> dict:
    from app_inference import TFLiteModel

    model = TFLiteModel(model_path, labels_file)
    field = collect(model, field_dir)
    if field["num_images"] == 0:
        raise FileNotFoundError(f"Aucune image terrain dans {field_dir}")

    result = {
        "field": {
            "num_images": field["num_images"],
            "confidence": summarize(field["confidences"]),
            "entropy": summarize(field["entropies"]),
            "margin": summarize(field["margins"]),
            "current_app_abstention_rate": abstention_rate(
                field["confidences"], field["margins"], field["entropies"]
            ),
            "top_predicted_classes": Counter(field["predicted_labels"]).most_common(10),
        },
        "recommended_thresholds": recommend_thresholds(
            field["confidences"], field["entropies"], target_abstention
        ),
    }

    if lab_dir:
        lab = collect(model, lab_dir)
        if lab["num_images"] > 0:
            result["lab_reference"] = {
                "num_images": lab["num_images"],
                "confidence": summarize(lab["confidences"]),
                "entropy": summarize(lab["entropies"]),
            }
            result["domain_shift"] = {
                "ks_confidence": ks_distance(field["confidences"], lab["confidences"]),
                "ks_entropy": ks_distance(field["entropies"], lab["entropies"]),
                "interpretation": "0 = identique au labo, 1 = totalement décalé",
            }
    return result


def _print_human(result: dict) -> None:
    f = result["field"]
    print(f"\n=== Terrain ({f['num_images']} images) ===")
    print(f"  Confiance top-1 : moy {f['confidence']['mean']:.2f} "
          f"(p10 {f['confidence']['p10']:.2f} / p90 {f['confidence']['p90']:.2f})")
    print(f"  Entropie        : moy {f['entropy']['mean']:.2f} "
          f"(p10 {f['entropy']['p10']:.2f} / p90 {f['entropy']['p90']:.2f})")
    print(f"  Abstention seuils actuels : {f['current_app_abstention_rate']*100:.1f}%")
    rt = result["recommended_thresholds"]
    print(f"\n=== Seuils recommandés (cible abstention {rt['target_abstention']*100:.0f}%) ===")
    print(f"  confiance < {rt['confidence_threshold']:.3f}  OU  entropie > {rt['entropy_threshold']:.3f}")
    if "domain_shift" in result:
        ds = result["domain_shift"]
        print("\n=== Décalage de domaine (labo→terrain) ===")
        print(f"  KS confiance : {ds['ks_confidence']:.3f}")
        print(f"  KS entropie  : {ds['ks_entropy']:.3f}   (0=identique, 1=disjoint)")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", required=True)
    parser.add_argument("--labels_file", required=True)
    parser.add_argument("--field_dir", required=True)
    parser.add_argument("--lab_dir", default=None)
    parser.add_argument("--target_abstention", type=float, default=0.3)
    parser.add_argument("--report", default=None)
    args = parser.parse_args()

    result = analyze(
        args.model_path,
        args.labels_file,
        args.field_dir,
        args.lab_dir,
        args.target_abstention,
    )
    _print_human(result)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as fh:
            json.dump(result, fh, indent=2, ensure_ascii=False)
        print(f"\nRapport JSON écrit : {args.report}")
