#!/usr/bin/env python3
"""
diagnose.py
Rejoue le VERDICT de l'app Flutter sur une image, en local, sans device.

Réutilise app_inference.TFLiteModel (source unique alignée sur l'app) pour
l'inférence, puis applique le MÊME arbre de décision que
lib/features/diagnosis/data/repositories/diagnosis_repository_impl.dart :

  1. prob(Background) > 0.25                      -> Image inutilisable
  2. top-1 == Background_without_leaves           -> Image inutilisable
  3. culture hors périmètre maraîcher             -> Culture non prise en charge
  4. sinon                                        -> Diagnostic
       + "validation recommandée" si  confiance < 0.5
                                  OU  marge top1-top2 < 0.1
                                  OU  entropie normalisée > 0.6

But : voir noir sur blanc ce que l'app dirait d'une image (tomate ou autre),
sans émulateur ni téléphone.

Usage :
    py -3.12 ml/pipeline/diagnose.py chemin/vers/feuille_tomate.jpg

Dépendances : tensorflow (Python 3.12), Pillow, numpy.
"""

import argparse
import os
import sys

import numpy as np

# app_inference.py vit dans le même dossier.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app_inference import TFLiteModel, normalized_entropy  # noqa: E402

# ── Constantes répliquées depuis le code Dart (source de vérité) ──
# diagnosis_repository_impl.dart
K_CONFIDENCE_THRESHOLD = 0.5
K_AMBIGUITY_MARGIN = 0.1
K_MAX_ENTROPY = 0.6
K_BACKGROUND_REJECT = 0.25
# culture_detector.dart — kSupportedCultures (option C, focus tomate)
K_SUPPORTED_CULTURES = {"Tomato", "Potato", "Pepper,_bell", "Squash", "Corn"}

# Affichage FR (lisibilité uniquement, ne change pas la logique).
CULTURE_FR = {
    "Tomato": "Tomate",
    "Potato": "Pomme de terre",
    "Pepper,_bell": "Piment/Poivron",
    "Squash": "Courge",
    "Corn": "Maïs",
    "Apple": "Pomme",
    "Grape": "Vigne",
    "Orange": "Orange",
    "Peach": "Pêche",
    "Cherry": "Cerise",
    "Strawberry": "Fraise",
    "Blueberry": "Myrtille",
    "Raspberry": "Framboise",
    "Soybean": "Soja",
    "Cassava": "Manioc",
}

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_MODEL = os.path.join(REPO_ROOT, "assets", "models", "plantvillage", "model_int8.tflite")
DEFAULT_LABELS = os.path.join(REPO_ROOT, "assets", "models", "plantvillage", "class_names.json")


def extract_culture(label: str):
    """Réplique extractCultureFromLabel (culture_detector.dart)."""
    if "___" in label:
        prefix = label.split("___")[0].strip()
        return prefix or None
    if label.lower().startswith("cassava "):
        return "Cassava"
    return None


def is_background(label: str) -> bool:
    low = label.lower()
    return "background" in low and "without" in low and "leaves" in low


def verdict(probs: np.ndarray, labels: list) -> dict:
    order = np.argsort(probs)[::-1]
    top1_i, top2_i = int(order[0]), int(order[1])
    top1_label = labels[top1_i]
    top1_conf = float(probs[top1_i])
    margin = top1_conf - float(probs[top2_i])
    entropy = normalized_entropy(probs)

    bg_prob = 0.0
    for i, lab in enumerate(labels):
        if is_background(lab):
            bg_prob = float(probs[i])
            break

    # Arbre de décision (ordre identique à analyzeImage).
    if bg_prob > K_BACKGROUND_REJECT:
        decision = ("IMAGE INUTILISABLE", f"prob(Background)={bg_prob:.0%} > {K_BACKGROUND_REJECT:.0%}")
    elif is_background(top1_label):
        decision = ("IMAGE INUTILISABLE", "Background est la classe gagnante")
    elif extract_culture(top1_label) not in K_SUPPORTED_CULTURES:
        cult = extract_culture(top1_label)
        fr = CULTURE_FR.get(cult, cult or "inconnue")
        decision = ("CULTURE NON PRISE EN CHARGE", f"culture détectée = {fr} (hors périmètre)")
    else:
        flags = []
        if top1_conf < K_CONFIDENCE_THRESHOLD:
            flags.append(f"confiance {top1_conf:.0%} < {K_CONFIDENCE_THRESHOLD:.0%}")
        if margin < K_AMBIGUITY_MARGIN:
            flags.append(f"marge {margin:.2f} < {K_AMBIGUITY_MARGIN}")
        if entropy > K_MAX_ENTROPY:
            flags.append(f"entropie {entropy:.2f} > {K_MAX_ENTROPY}")
        if flags:
            decision = ("DIAGNOSTIC — validation recommandée", " ; ".join(flags))
        else:
            decision = ("DIAGNOSTIC FIABLE", "tous les signaux au vert")

    return {
        "order": order,
        "top1_label": top1_label,
        "top1_conf": top1_conf,
        "margin": margin,
        "entropy": entropy,
        "bg_prob": bg_prob,
        "decision": decision,
    }


def main():
    parser = argparse.ArgumentParser(description="Rejoue le verdict de l'app DoctAgri sur une image.")
    parser.add_argument("image", help="Chemin de l'image à diagnostiquer")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--labels", default=DEFAULT_LABELS)
    parser.add_argument("--temperature", type=float, default=1.0)
    parser.add_argument("--topk", type=int, default=5)
    args = parser.parse_args()

    # Console Windows (cp1252) : forcer l'UTF-8 pour éviter les crashs
    # d'encodage et afficher correctement les accents.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    if not os.path.exists(args.image):
        sys.exit(f"ERREUR: Image introuvable : {args.image}")

    model = TFLiteModel(args.model, args.labels, temperature=args.temperature)
    probs = model.infer(args.image)
    v = verdict(probs, model.labels)

    print()
    print(f"Image  : {args.image}")
    print(f"Modèle : {os.path.basename(args.model)} "
          f"({model.input_size}x{model.input_size}, {model.num_classes} classes)")
    print()
    print(f"Top-{args.topk} prédictions :")
    for rank, i in enumerate(v["order"][: args.topk], 1):
        lab = model.labels[int(i)]
        cult = extract_culture(lab)
        fr = CULTURE_FR.get(cult, cult or "?")
        scope = "[OK]  " if cult in K_SUPPORTED_CULTURES else "[hors]"
        print(f"  {rank}. {scope} {lab:<45} {probs[int(i)]:.1%}   [{fr}]")
    print()
    print(f"Signaux : confiance={v['top1_conf']:.1%}  "
          f"marge={v['margin']:.2f}  entropie={v['entropy']:.2f}  "
          f"bg={v['bg_prob']:.1%}")
    print()
    title, why = v["decision"]
    print(f"👉 VERDICT APP : {title}")
    print(f"   ({why})")
    print()


if __name__ == "__main__":
    main()
