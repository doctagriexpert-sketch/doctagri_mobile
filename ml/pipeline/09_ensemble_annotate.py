#!/usr/bin/env python3
"""
09_ensemble_annotate.py
=======================
Moteur d'annotation par comité multi-modèles (Ensemble Consensus Annotation).

Superpose jusqu'à 4 modèles de diagnostic pour pré-étiqueter automatiquement
un jeu de données de photos de terrain avec 3 barrières anti-erreurs :

Barrière 1 : Taxonomie unifiée (aligne PlantVillage, Cassava et VLM sur une ontologie commune).
Barrière 2 : Calibration de température (élimine la sur-confiance INT8, double-softmax évité).
Barrière 3 : Détection hors-domaine & décalage de terrain (rejet de fond, entropie de Shannon, marge).

Modèles intégrés au comité :
  - Modèles Hugging Face (5 architectures complémentaires) :
      1. HF ViT Tomate (`wellCh4n/tomato-leaf-disease-classification-vit` - 10 classes)
      2. HF ResNet-50 Tomate (`wellCh4n/tomato-leaf-disease-classification-resnet50` - 10 classes)
      3. HF ResNet-18 PlantVillage (`neghani/plantvillage-resnet18` - 38 classes)
      4. HF MobileNetV2 PlantVillage (`neghani/plantvillage-mobilenetv2` - 38 classes)
      5. HF ConvNeXt-Tiny PlantVillage (`JohnSupertramp2026/convnext-tiny-plantvillage` - 38 classes)
  - Modèle 6 : PlantVillage INT8 TFLite (39 classes, EfficientNet-B0 local)
  - Modèle 7 : Cassava Float16 TFLite (6 classes manioc, MobileNetV3 local)
  - Modèle 8 (Optionnel) : Keras MobileNetV2 (38 classes, plant_disease_model.keras)
  - Modèle 9 (Optionnel) : VLM (Claude / Gemini vision ou CSV pré-généré de 08_vlm_label.py)

Usage :
    # 1) Annotation des photos de terrain avec les modèles TFLite + VLM CSV existant :
    python 09_ensemble_annotate.py --images_dir ../../data/field_photos \\
        --vlm_csv ../../data/field_labels.csv \\
        --output_csv ../../data/ensemble_annotations.csv

    # 2) Test rapide sur 10 images :
    python 09_ensemble_annotate.py --images_dir ../../data/field_photos --max_images 10

    # 3) Inclure le modèle Keras MobileNetV2 lourd en plus :
    python 09_ensemble_annotate.py --use_keras
"""

from __future__ import annotations

import argparse
import csv
import glob
import json
import math
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

# Chemins relatifs à la racine du projet
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent

# Forcer UTF-8 sur stdout pour éviter les plantages charmap/cp1252 sous Windows
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

sys.path.insert(0, str(SCRIPT_DIR))
try:
    from app_inference import load_labels, preprocess, to_probabilities, normalized_entropy
except ImportError:
    raise ImportError("Impossible d'importer app_inference.py depuis ml/pipeline/")


# ==============================================================================
# 1. BARRIÈRE 1 : TAXONOMIE UNIFIÉE & RÉSOLVEUR SÉMANTIQUE
# ==============================================================================

CANONICAL_SYNONYMS = {
    # Rejet & Fond
    "background_without_leaves": "BACKGROUND_REJECT",
    "background": "BACKGROUND_REJECT",
    "cassava___unknown": "OUT_OF_DOMAIN",
    "unknown": "OUT_OF_DOMAIN",
    "indetermine": "OUT_OF_DOMAIN",
    "indéterminé": "OUT_OF_DOMAIN",

    # Manioc
    "cassava bacterial blight (cbb)": "Cassava___CBB",
    "cbb": "Cassava___CBB",
    "bacteriose du manioc": "Cassava___CBB",
    "cassava brown streak disease (cbsd)": "Cassava___CBSD",
    "cbsd": "Cassava___CBSD",
    "striure brune du manioc": "Cassava___CBSD",
    "cassava green mottle (cgm)": "Cassava___CGM",
    "cassava green mite": "Cassava___CGM",
    "cgm": "Cassava___CGM",
    "acariens verts du manioc": "Cassava___CGM",
    "cassava mosaic disease (cmd)": "Cassava___CMD",
    "cmd": "Cassava___CMD",
    "mosaique du manioc": "Cassava___CMD",
    "mosaïque du manioc": "Cassava___CMD",
    "cassava___healthy": "Cassava___healthy",
    "manioc sain": "Cassava___healthy",

    # Tomate (PlantVillage & Hugging Face ViT wellCh4n)
    "tomato___bacterial_spot": "Tomato___Bacterial_spot",
    "a tomato leaf with bacterial spot": "Tomato___Bacterial_spot",
    "gale bacterienne de la tomate": "Tomato___Bacterial_spot",
    "tomato___early_blight": "Tomato___Early_blight",
    "a tomato leaf with early blight": "Tomato___Early_blight",
    "alternariose de la tomate": "Tomato___Early_blight",
    "tomato___late_blight": "Tomato___Late_blight",
    "a tomato leaf with late blight": "Tomato___Late_blight",
    "mildiou de la tomate": "Tomato___Late_blight",
    "tomato___leaf_mold": "Tomato___Leaf_Mold",
    "a tomato leaf with leaf mold": "Tomato___Leaf_Mold",
    "cladosporiose de la tomate": "Tomato___Leaf_Mold",
    "tomato___septoria_leaf_spot": "Tomato___Septoria_leaf_spot",
    "a tomato leaf with septoria leaf spot": "Tomato___Septoria_leaf_spot",
    "septoriose de la tomate": "Tomato___Septoria_leaf_spot",
    "tomato___spider_mites two-spotted_spider_mite": "Tomato___Spider_mites",
    "tomato___spider_mites": "Tomato___Spider_mites",
    "a tomato leaf with spider mites two-spotted spider mite": "Tomato___Spider_mites",
    "tetranyque de la tomate": "Tomato___Spider_mites",
    "tomato___target_spot": "Tomato___Target_Spot",
    "a tomato leaf with target spot": "Tomato___Target_Spot",
    "corynesporiose de la tomate": "Tomato___Target_Spot",
    "tomato___tomato_yellow_leaf_curl_virus": "Tomato___TYLCV",
    "a tomato leaf with tomato yellow leaf curl virus": "Tomato___TYLCV",
    "tylcv": "Tomato___TYLCV",
    "virus de l'enroulement jaune de la tomate": "Tomato___TYLCV",
    "tomato___tomato_mosaic_virus": "Tomato___ToMV",
    "a tomato leaf with tomato mosaic virus": "Tomato___ToMV",
    "tomv": "Tomato___ToMV",
    "mosaique de la tomate": "Tomato___ToMV",
    "tomato___healthy": "Tomato___healthy",
    "a healthy tomato leaf": "Tomato___healthy",
    "tomate saine": "Tomato___healthy",

    # Maïs
    "corn___cercospora_leaf_spot gray_leaf_spot": "Corn___Cercospora",
    "corn___common_rust": "Corn___Common_rust",
    "rouille du mais": "Corn___Common_rust",
    "corn___northern_leaf_blight": "Corn___Northern_Leaf_Blight",
    "helminthosporiose du mais": "Corn___Northern_Leaf_Blight",
    "corn___healthy": "Corn___healthy",
    "mais sain": "Corn___healthy",

    # Pomme de terre
    "potato___early_blight": "Potato___Early_blight",
    "alternariose de la pomme de terre": "Potato___Early_blight",
    "potato___late_blight": "Potato___Late_blight",
    "mildiou de la pomme de terre": "Potato___Late_blight",
    "potato___healthy": "Potato___healthy",
}


def normalize_label(raw: str) -> str:
    """Normalise une étiquette brute vers un label canonique unique."""
    if not raw:
        return "OUT_OF_DOMAIN"
    clean = raw.strip().lower()
    if clean in CANONICAL_SYNONYMS:
        return CANONICAL_SYNONYMS[clean]

    # Détection par préfixe / suffixe standard PlantVillage
    for key, canon in CANONICAL_SYNONYMS.items():
        if key in clean or clean in key:
            return canon

    # Préservation telle quelle si format Culture___Maladie
    if "___" in raw:
        return raw.strip()

    return raw.strip()


def extract_culture(canonical_label: str) -> str:
    """Extrait la culture principale d'un label canonique."""
    if "___" in canonical_label:
        return canonical_label.split("___")[0]
    # Formats textuels VLM : "Laitue sain", "Manioc sain", etc.
    for known in ("Laitue", "Manioc", "Tomate", "Tomato", "Piment", "Mais", "Maïs", "Oignon", "Gombo"):
        if known.lower() in canonical_label.lower():
            return "Tomato" if known.lower() in ("tomate", "tomato", "piment") else known
    return "Autre"


# ==============================================================================
# 2. BARRIÈRE 2 : CALIBRATION & MESURES D'INCERTITUDE
# ==============================================================================

def calibrate_distribution(probs: np.ndarray, temperature: float = 1.0) -> np.ndarray:
    """Applique une température de calibration T sur une distribution de probabilités."""
    p = np.asarray(probs, dtype=np.float64)
    if temperature == 1.0:
        s = p.sum()
        return (p / s) if s > 0 else np.full_like(p, 1.0 / p.size)

    scaled = np.where(p > 0, np.power(np.clip(p, 1e-12, None), 1.0 / temperature), 0.0)
    s = scaled.sum()
    return (scaled / s) if s > 0 else np.full_like(p, 1.0 / p.size)


def compute_margin(probs: np.ndarray) -> float:
    """Différence de confiance entre le top-1 et le top-2."""
    if probs.size < 2:
        return 1.0
    top2 = np.partition(probs, -2)[-2:]
    return float(abs(top2[1] - top2[0]))


@dataclass
class SingleModelPrediction:
    model_name: str
    raw_label: str
    canonical_label: str
    confidence: float
    entropy: float
    margin: float
    raw_probs: Optional[np.ndarray] = None


# ==============================================================================
# 3. BARRIÈRE 3 : MOTEUR D'ARBITRAGE DU COMITÉ
# ==============================================================================

@dataclass
class CommitteeDecision:
    decision: str              # AUTO_APPROVED, NEEDS_HUMAN_REVIEW, REJECTED_UNUSABLE
    final_label: str
    final_crop: str
    confidence: float
    agreement: str             # ex: "3/3" ou "2/3"
    entropy: float
    margin: float
    reason: str
    model_details: List[Dict[str, Any]] = field(default_factory=list)


MODEL_CULTURE_DOMAINS = {
    "PlantVillage_INT8": {
        "Tomato", "Corn", "Potato", "Apple", "Grape", "Pepper",
        "Peach", "Strawberry", "Soybean", "Squash", "Cherry",
        "Orange", "Blueberry", "Raspberry", "Poivron", "Tomate",
        "Maïs", "Pomme de terre", "Vigne"
    },
    "Keras_MobileNetV2": {
        "Tomato", "Corn", "Potato", "Apple", "Grape", "Pepper",
        "Peach", "Strawberry", "Soybean", "Squash", "Cherry",
        "Orange", "Blueberry", "Raspberry", "Poivron", "Tomate",
        "Maïs", "Pomme de terre", "Vigne"
    },
    "Cassava_FP16": {"Cassava", "Manioc"},
    # 5 modèles Hugging Face spécialisés
    "HF_ViT_Tomato": {"Tomato", "Tomate", "Piment/Tomate"},
    "HF_ResNet50_Tomato": {"Tomato", "Tomate", "Piment/Tomate"},
    "HF_ResNet18_PV": {
        "Tomato", "Corn", "Potato", "Apple", "Grape", "Pepper",
        "Peach", "Strawberry", "Soybean", "Squash", "Cherry",
        "Orange", "Blueberry", "Raspberry", "Poivron", "Tomate",
        "Maïs", "Pomme de terre", "Vigne"
    },
    "HF_MobileNetV2_PV": {
        "Tomato", "Corn", "Potato", "Apple", "Grape", "Pepper",
        "Peach", "Strawberry", "Soybean", "Squash", "Cherry",
        "Orange", "Blueberry", "Raspberry", "Poivron", "Tomate",
        "Maïs", "Pomme de terre", "Vigne"
    },
    "HF_ConvNeXt_PV": {
        "Tomato", "Corn", "Potato", "Apple", "Grape", "Pepper",
        "Peach", "Strawberry", "Soybean", "Squash", "Cherry",
        "Orange", "Blueberry", "Raspberry", "Poivron", "Tomate",
        "Maïs", "Pomme de terre", "Vigne"
    },
    "VLM_Vision": None,  # VLM universel
}


def is_model_in_domain(model_name: str, crop: str) -> bool:
    """Vérifie si le modèle couvre la culture détectée."""
    domain = MODEL_CULTURE_DOMAINS.get(model_name)
    if domain is None:
        return True  # Couverture universelle (VLM)
    return any(c.lower() in crop.lower() or crop.lower() in c.lower() for c in domain)


class EnsembleAnnotator:
    """Arbitre les votes des différents modèles selon les 3 barrières anti-erreurs."""

    def __init__(
        self,
        min_agreement: int = 2,
        min_confidence: float = 0.65,
        max_entropy: float = 0.45,
        min_margin: float = 0.15,
    ):
        self.min_agreement = min_agreement
        self.min_confidence = min_confidence
        self.max_entropy = max_entropy
        self.min_margin = min_margin

    def evaluate(self, predictions: List[SingleModelPrediction]) -> CommitteeDecision:
        if not predictions:
            return CommitteeDecision(
                decision="REJECTED_UNUSABLE",
                final_label="NONE",
                final_crop="NONE",
                confidence=0.0,
                agreement="0/0",
                entropy=1.0,
                margin=0.0,
                reason="Aucune prédiction disponible",
            )

        details = [
            {
                "model": p.model_name,
                "label": p.canonical_label,
                "confidence": round(p.confidence, 4),
                "entropy": round(p.entropy, 4),
                "margin": round(p.margin, 4),
            }
            for p in predictions
        ]

        # 1. Vérification Rejet Fond / Non-plante (Barrière 3)
        for p in predictions:
            if p.canonical_label == "BACKGROUND_REJECT" and p.confidence > 0.35:
                return CommitteeDecision(
                    decision="REJECTED_UNUSABLE",
                    final_label="BACKGROUND_REJECT",
                    final_crop="Indéterminé",
                    confidence=p.confidence,
                    agreement=f"1/{len(predictions)}",
                    entropy=p.entropy,
                    margin=p.margin,
                    reason=f"Détection de fond sans feuille par {p.model_name} (conf: {p.confidence:.2%})",
                    model_details=details,
                )

        # 2. Détermination de la culture cible prédominante
        # Priorité aux modèles généralistes (PlantVillage, VLM, Keras) pour identifier la culture.
        # Un spécialiste mono-culture (ex: HF_ViT_Tomato) ne peut pas imposer sa culture si un
        # modèle multi-cultures ou VLM identifie une autre culture (ex: Laitue, Manioc).
        generalist_crops: Dict[str, float] = {}
        all_crops: Dict[str, float] = {}
        for p in predictions:
            crop = extract_culture(p.canonical_label)
            if crop not in ("Autre", "Indéterminé", "BACKGROUND_REJECT", "OUT_OF_DOMAIN"):
                all_crops[crop] = all_crops.get(crop, 0.0) + p.confidence
                if p.model_name in ("VLM_Vision", "PlantVillage_INT8", "Keras_MobileNetV2"):
                    generalist_crops[crop] = generalist_crops.get(crop, 0.0) + p.confidence

        if generalist_crops:
            top_crop = max(generalist_crops.items(), key=lambda x: x[1])[0]
        elif all_crops:
            top_crop = max(all_crops.items(), key=lambda x: x[1])[0]
        else:
            top_crop = "Indéterminé"

        # Si aucune culture couverte par le catalogue n'est trouvée
        if top_crop == "Indéterminé":
            return CommitteeDecision(
                decision="REJECTED_UNUSABLE",
                final_label="OUT_OF_DOMAIN",
                final_crop="Hors-catalogue",
                confidence=1.0,
                agreement=f"{len(predictions)}/{len(predictions)}",
                entropy=0.0,
                margin=1.0,
                reason="Culture hors du catalogue DoctAgri ou photo sans végétal identifié",
                model_details=details,
            )

        # 3. Filtrage des modèles pertinents pour cette culture (Domain Routing)
        in_domain_preds = [p for p in predictions if is_model_in_domain(p.model_name, top_crop)]
        active_preds = in_domain_preds if in_domain_preds else predictions

        # 4. Entropie moyenne des modèles dans le domaine
        avg_entropy = float(np.mean([p.entropy for p in active_preds]))
        if avg_entropy > self.max_entropy:
            top_p = max(active_preds, key=lambda x: x.confidence)
            return CommitteeDecision(
                decision="NEEDS_HUMAN_REVIEW",
                final_label=top_p.canonical_label,
                final_crop=top_crop,
                confidence=top_p.confidence,
                agreement=f"1/{len(active_preds)}",
                entropy=avg_entropy,
                margin=top_p.margin,
                reason=f"Forte incertitude de terrain (Entropie domaine: {avg_entropy:.2f} > {self.max_entropy:.2f})",
                model_details=details,
            )

        # 5. Dépouillement des votes parmi les modèles actifs dans le domaine
        vote_counts: Dict[str, int] = {}
        vote_scores: Dict[str, float] = {}
        for p in active_preds:
            lbl = p.canonical_label
            if lbl not in ("OUT_OF_DOMAIN", "BACKGROUND_REJECT"):
                vote_counts[lbl] = vote_counts.get(lbl, 0) + 1
                vote_scores[lbl] = vote_scores.get(lbl, 0.0) + p.confidence

        if not vote_counts:
            return CommitteeDecision(
                decision="NEEDS_HUMAN_REVIEW",
                final_label="Indéterminé",
                final_crop=top_crop,
                confidence=0.0,
                agreement="0/0",
                entropy=avg_entropy,
                margin=0.0,
                reason="Aucun modèle du domaine n'a pu classifier avec certitude",
                model_details=details,
            )

        winner_label, count = max(vote_counts.items(), key=lambda item: item[1])
        avg_winner_conf = vote_scores[winner_label] / count
        matching_margins = [p.margin for p in active_preds if p.canonical_label == winner_label]
        avg_winner_margin = float(np.mean(matching_margins)) if matching_margins else 0.0

        agreement_str = f"{count}/{len(active_preds)}"

        # 6. Règle d'auto-approbation
        # Si 2 modèles couvrent le domaine et les 2 sont d'accord (ou 1 seul expert très confiant)
        is_consensus = (count >= min(self.min_agreement, len(active_preds)))
        is_confident = (avg_winner_conf >= self.min_confidence)
        is_clear_margin = (avg_winner_margin >= self.min_margin)

        if is_consensus and is_confident and is_clear_margin:
            return CommitteeDecision(
                decision="AUTO_APPROVED",
                final_label=winner_label,
                final_crop=top_crop,
                confidence=round(avg_winner_conf, 4),
                agreement=agreement_str,
                entropy=round(avg_entropy, 4),
                margin=round(avg_winner_margin, 4),
                reason="Consensus validé entre les modèles experts du domaine",
                model_details=details,
            )
        else:
            reasons = []
            if not is_consensus:
                reasons.append(f"Désaccord ({agreement_str})")
            if not is_confident:
                reasons.append(f"Confiance ({avg_winner_conf:.2%} < {self.min_confidence:.2%})")
            if not is_clear_margin:
                reasons.append(f"Marge ({avg_winner_margin:.2f} < {self.min_margin:.2f})")

            return CommitteeDecision(
                decision="NEEDS_HUMAN_REVIEW",
                final_label=winner_label,
                final_crop=top_crop,
                confidence=round(avg_winner_conf, 4),
                agreement=agreement_str,
                entropy=round(avg_entropy, 4),
                margin=round(avg_winner_margin, 4),
                reason=" | ".join(reasons),
                model_details=details,
            )



# ==============================================================================
# 4. CHARGEMENT DU COMITÉ DE MODÈLES
# ==============================================================================

class SafeTFLiteModel:
    """Interprète TFLite sans delegate XNNPACK problématique sur tenseurs dynamiques (évite STATUS_HEAP_CORRUPTION sous Windows)."""

    def __init__(self, model_path: str, labels_file: str, temperature: float = 1.0):
        import tensorflow as tf

        self.labels = load_labels(labels_file)
        self.temperature = temperature
        # BUILTIN_WITHOUT_DEFAULT_DELEGATES désactive XNNPACK qui crash sur les tenseurs dynamiques sous Windows
        resolver = tf.lite.experimental.OpResolverType.BUILTIN_WITHOUT_DEFAULT_DELEGATES
        self._it = tf.lite.Interpreter(model_path=model_path, experimental_op_resolver_type=resolver)
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
                f"Mismatch: modèle {self.num_classes} classes vs {len(self.labels)} labels."
            )

    def infer(self, img_path: str) -> np.ndarray:
        x = preprocess(img_path, self.input_size, self.input_dtype)
        self._it.set_tensor(self._inp["index"], x)
        self._it.invoke()
        raw = self._it.get_tensor(self._out["index"])[0]
        if self.output_dtype == np.uint8 and self.out_scale:
            raw = (raw.astype(np.float32) - self.out_zero) * self.out_scale
        return to_probabilities(raw, self.temperature)


class HuggingFaceClassificationModel:
    """Wrapper générique pour modèles de vision Hugging Face (ViT, ResNet, MobileNet, ConvNeXt)."""

    def __init__(
        self,
        repo_id: str,
        temperature: float = 1.0,
    ):
        from transformers import AutoImageProcessor, AutoModelForImageClassification

        self.repo_id = repo_id
        self.temperature = temperature
        self.processor = AutoImageProcessor.from_pretrained(repo_id)
        self.model = AutoModelForImageClassification.from_pretrained(repo_id)
        self.model.eval()
        self.id2label = self.model.config.id2label
        self.labels = [self.id2label[i] for i in range(len(self.id2label))]

    def infer(self, img_path: str) -> np.ndarray:
        import torch
        from PIL import Image

        image = Image.open(img_path).convert("RGB")
        inputs = self.processor(images=image, return_tensors="pt")
        with torch.no_grad():
            outputs = self.model(**inputs)
            logits = outputs.logits[0].cpu().numpy()
        return to_probabilities(logits, temperature=self.temperature)


class ModelCommittee:
    """Orchestre les modèles disponibles pour former le comité."""

    def __init__(
        self,
        use_keras: bool = False,
        use_hf: bool = True,
        vlm_csv_path: Optional[str] = None,
    ):
        self.models: List[Tuple[str, Any, float]] = []  # (nom, instance/loader, temperature)
        self.vlm_cache: Dict[str, Dict[str, Any]] = {}

        # 1. Modèle PlantVillage INT8 (Généraliste - 39 classes)
        pv_model_path = REPO_ROOT / "assets" / "models" / "plantvillage" / "model_int8.tflite"
        pv_labels_path = REPO_ROOT / "assets" / "models" / "plantvillage" / "class_names.json"
        if pv_model_path.exists() and pv_labels_path.exists():
            print(f"[+] Modèle 1 chargé : PlantVillage INT8 ({pv_model_path.name})")
            m1 = SafeTFLiteModel(str(pv_model_path), str(pv_labels_path), temperature=1.2)
            self.models.append(("PlantVillage_INT8", m1, 1.2))
        else:
            print(f"[!] Modèle PlantVillage absent : {pv_model_path}")

        # 2. Modèle Manioc Float16 (Spécialiste - 6 classes)
        cas_model_path = REPO_ROOT / "assets" / "models" / "model.tflite"
        cas_labels_path = REPO_ROOT / "assets" / "models" / "labels.txt"
        if cas_model_path.exists() and cas_labels_path.exists():
            print(f"[+] Modèle 2 chargé : Cassava Float16 ({cas_model_path.name})")
            m2 = SafeTFLiteModel(str(cas_model_path), str(cas_labels_path), temperature=1.0)
            self.models.append(("Cassava_FP16", m2, 1.0))

        # 3. Les 5 modèles Hugging Face (Diversité architecturale & spécialisation)
        if use_hf:
            hf_models_registry = [
                ("HF_ViT_Tomato", "wellCh4n/tomato-leaf-disease-classification-vit", 1.0),
                ("HF_ResNet50_Tomato", "wellCh4n/tomato-leaf-disease-classification-resnet50", 1.0),
                ("HF_ResNet18_PV", "neghani/plantvillage-resnet18", 1.0),
                ("HF_MobileNetV2_PV", "neghani/plantvillage-mobilenetv2", 1.0),
                ("HF_ConvNeXt_PV", "JohnSupertramp2026/convnext-tiny-plantvillage", 1.0),
            ]
            for m_name, repo_id, temp in hf_models_registry:
                try:
                    print(f"[+] Modèle Hugging Face : {m_name} ({repo_id})")
                    m_inst = HuggingFaceClassificationModel(repo_id=repo_id, temperature=temp)
                    self.models.append((m_name, m_inst, temp))
                except Exception as e:
                    print(f"[!] Modèle HF {m_name} indisponible : {e}")

        # 4. Modèle Keras MobileNetV2 (Optionnel - 38 classes)
        if use_keras:
            self._load_keras_model()

        # 5. VLM CSV Cache (Résultats Claude / Gemini si existants)
        if vlm_csv_path and os.path.exists(vlm_csv_path):
            self._load_vlm_cache(vlm_csv_path)

    def _load_keras_model(self):
        keras_path = REPO_ROOT / "plant_disease_model.keras"
        if not keras_path.exists():
            print(f"[!] Fichier Keras introuvable : {keras_path}")
            return
        try:
            import zipfile
            import keras
            print(f"[+] Modèle 3 en cours de chargement : Keras MobileNetV2 ({keras_path.name})...")
            base = keras.applications.MobileNetV2(input_shape=(224, 224, 3), include_top=False, weights=None)
            inp = keras.Input(shape=(224, 224, 3))
            x = base(inp)
            x = keras.layers.Flatten()(x)
            x = keras.layers.Dense(512, activation="relu")(x)
            x = keras.layers.Dropout(0.5)(x)
            out = keras.layers.Dense(38, activation="softmax")(x)
            kmodel = keras.Model(inputs=inp, outputs=out)

            # Charger les poids
            with zipfile.ZipFile(keras_path, "r") as z:
                z.extract("model.weights.h5", str(SCRIPT_DIR))
            w_file = SCRIPT_DIR / "model.weights.h5"
            kmodel.load_weights(str(w_file))
            if w_file.exists():
                os.remove(w_file)

            # Labels correspondants (38 classes triées)
            pv_labels_path = REPO_ROOT / "assets" / "models" / "plantvillage" / "class_names.json"
            with open(pv_labels_path, "r", encoding="utf-8") as f:
                c39 = json.load(f)
            c38_sorted = sorted([c for c in c39 if c != "Background_without_leaves"])

            self.models.append(("Keras_MobileNetV2", (kmodel, c38_sorted), 1.0))
            print("[+] Modèle 3 chargé avec succès !")
        except Exception as e:
            print(f"[!] Échec du chargement du modèle Keras : {e}")

    def _load_vlm_cache(self, vlm_csv_path: str):
        print(f"[+] Modèle 4 chargé : Annotations VLM depuis {vlm_csv_path}")
        with open(vlm_csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                img_name = os.path.basename(row.get("image", ""))
                self.vlm_cache[img_name] = row

    def predict_image(self, img_path: str) -> List[SingleModelPrediction]:
        predictions: List[SingleModelPrediction] = []
        base_name = os.path.basename(img_path)

        for name, m, temp in self.models:
            try:
                if isinstance(m, (SafeTFLiteModel, HuggingFaceClassificationModel)):
                    probs = m.infer(img_path)
                    cal_probs = calibrate_distribution(probs, temperature=temp)
                    top_idx = int(np.argmax(cal_probs))
                    raw_lbl = m.labels[top_idx]
                    conf = float(cal_probs[top_idx])
                    ent = float(normalized_entropy(cal_probs))
                    mrg = float(compute_margin(cal_probs))

                    predictions.append(
                        SingleModelPrediction(
                            model_name=name,
                            raw_label=raw_lbl,
                            canonical_label=normalize_label(raw_lbl),
                            confidence=conf,
                            entropy=ent,
                            margin=mrg,
                            raw_probs=cal_probs,
                        )
                    )

                elif name == "Keras_MobileNetV2":
                    kmodel, labels = m
                    x = preprocess(img_path, 224, np.float32)
                    raw_out = kmodel.predict(x, verbose=0)[0]
                    cal_probs = calibrate_distribution(raw_out, temperature=temp)
                    top_idx = int(np.argmax(cal_probs))
                    raw_lbl = labels[top_idx]
                    conf = float(cal_probs[top_idx])
                    ent = float(normalized_entropy(cal_probs))
                    mrg = float(compute_margin(cal_probs))

                    predictions.append(
                        SingleModelPrediction(
                            model_name=name,
                            raw_label=raw_lbl,
                            canonical_label=normalize_label(raw_lbl),
                            confidence=conf,
                            entropy=ent,
                            margin=mrg,
                            raw_probs=cal_probs,
                        )
                    )
            except Exception as e:
                print(f"[!] Erreur inférence {name} sur {base_name}: {e}")

        # VLM (si présent dans le cache)
        if base_name in self.vlm_cache:
            v_row = self.vlm_cache[base_name]
            v_disease = v_row.get("disease", "")
            v_crop = v_row.get("crop", "")
            v_conf_str = v_row.get("confidence", "moyenne").lower()
            conf_val = 0.90 if v_conf_str == "élevée" else (0.75 if v_conf_str == "moyenne" else 0.55)

            raw_combined = f"{v_crop} — {v_disease}" if v_disease != "Sain" else f"{v_crop} sain"
            canon = normalize_label(raw_combined)

            predictions.append(
                SingleModelPrediction(
                    model_name="VLM_Vision",
                    raw_label=raw_combined,
                    canonical_label=canon,
                    confidence=conf_val,
                    entropy=0.20 if conf_val > 0.8 else 0.40,
                    margin=0.50,
                )
            )

        return predictions


# ==============================================================================
# 5. PIPELINE D'EXÉCUTION & SAUVEGARDE
# ==============================================================================

def run_ensemble_annotation(
    images_dir: str,
    output_csv: str,
    vlm_csv: Optional[str] = None,
    use_keras: bool = False,
    use_hf: bool = True,
    max_images: Optional[int] = None,
    min_agreement: int = 2,
    min_confidence: float = 0.65,
    overwrite: bool = False,
) -> Dict[str, Any]:
    images_path = Path(images_dir)
    if not images_path.exists():
        raise FileNotFoundError(f"Dossier introuvable : {images_dir}")

    images = [
        p for p in glob.glob(str(images_path / "**" / "*.*"), recursive=True)
        if p.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
    ]

    if max_images:
        images = images[:max_images]

    print(f"\n{'='*70}")
    print(f" DEMARRAGE DU PIPELINE D'ANNOTATION PAR COMITE")
    print(f" Images a traiter : {len(images)}")
    print(f" Dossier source    : {images_dir}")
    print(f" Fichier de sortie : {output_csv}")
    print(f"{'='*70}\n")

    committee = ModelCommittee(use_keras=use_keras, use_hf=use_hf, vlm_csv_path=vlm_csv)
    annotator = EnsembleAnnotator(min_agreement=min_agreement, min_confidence=min_confidence)

    output_path = Path(output_csv)
    already_done = set()
    if output_path.exists() and not overwrite:
        with open(output_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for r in reader:
                already_done.add(r.get("image", ""))
        if already_done:
            print(f"[i] Reprise activee : {len(already_done)} images deja traitees (ignorees).\n")
    elif output_path.exists() and overwrite:
        print("[i] Mode ecrasement (--overwrite) : re-annotation complete.\n")

    fieldnames = [
        "image",
        "decision",
        "final_crop",
        "final_label",
        "confidence",
        "agreement",
        "entropy",
        "margin",
        "reason",
        "models_summary",
    ]

    stats = {
        "total": len(images),
        "AUTO_APPROVED": 0,
        "NEEDS_HUMAN_REVIEW": 0,
        "REJECTED_UNUSABLE": 0,
    }

    mode = "a" if (output_path.exists() and not overwrite) else "w"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, mode, newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        if mode == "w":
            writer.writeheader()

        for idx, img_p in enumerate(images, 1):
            fname = os.path.basename(img_p)
            if fname in already_done:
                continue

            predictions = committee.predict_image(img_p)
            decision = annotator.evaluate(predictions)

            stats[decision.decision] = stats.get(decision.decision, 0) + 1

            models_summary_str = " | ".join(
                f"{d['model']}:{d['label']}({d['confidence']:.2f})"
                for d in decision.model_details
            )

            writer.writerow({
                "image": fname,
                "decision": decision.decision,
                "final_crop": decision.final_crop,
                "final_label": decision.final_label,
                "confidence": decision.confidence,
                "agreement": decision.agreement,
                "entropy": decision.entropy,
                "margin": decision.margin,
                "reason": decision.reason,
                "models_summary": models_summary_str,
            })

            # Affichage console
            icon = "[AUTO]" if decision.decision == "AUTO_APPROVED" else ("[REVIEW]" if decision.decision == "NEEDS_HUMAN_REVIEW" else "[REJECT]")
            print(
                f"[{idx:03d}/{len(images)}] {icon} {fname} -> {decision.decision:18s} "
                f"| {decision.final_label} ({decision.confidence:.2%}, acc={decision.agreement})"
            )

    print(f"\n{'='*70}")
    print(" BILAN DE L'ANNOTATION PAR COMITE")
    print(f"{'='*70}")
    print(f"  Total traite         : {stats['total']}")
    print(f"  [AUTO] Auto-valides  : {stats['AUTO_APPROVED']} ({stats['AUTO_APPROVED']/max(stats['total'],1):.1%})")
    print(f"  [REVIEW] A reviser   : {stats['NEEDS_HUMAN_REVIEW']} ({stats['NEEDS_HUMAN_REVIEW']/max(stats['total'],1):.1%})")
    print(f"  [REJECT] Rejets fond : {stats['REJECTED_UNUSABLE']} ({stats['REJECTED_UNUSABLE']/max(stats['total'],1):.1%})")
    print(f"  Fichier produit      : {output_path.resolve()}\n")

    return stats


def main():
    parser = argparse.ArgumentParser(description="Annotation de photos par comité multi-modèles.")
    parser.add_argument("--images_dir", default=str(REPO_ROOT / "data" / "field_photos"), help="Dossier d'images")
    parser.add_argument("--output_csv", default=str(REPO_ROOT / "data" / "ensemble_annotations.csv"), help="CSV de sortie")
    parser.add_argument("--vlm_csv", default=str(REPO_ROOT / "data" / "field_labels.csv"), help="CSV VLM facultatif")
    parser.add_argument("--use_keras", action="store_true", help="Inclure le modèle lourd Keras MobileNetV2")
    parser.add_argument("--no_hf", action="store_true", help="Désactiver les 5 modèles Hugging Face")
    parser.add_argument("--max_images", type=int, default=None, help="Nombre max d'images à traiter")
    parser.add_argument("--min_agreement", type=int, default=2, help="Nombre minimum de modèles d'accord")
    parser.add_argument("--min_confidence", type=float, default=0.65, help="Confiance moyenne minimale requise")
    parser.add_argument("--overwrite", action="store_true", help="Écrase le CSV de sortie plutôt que de reprendre")

    args = parser.parse_args()

    run_ensemble_annotation(
        images_dir=args.images_dir,
        output_csv=args.output_csv,
        vlm_csv=args.vlm_csv,
        use_keras=args.use_keras,
        use_hf=not args.no_hf,
        max_images=args.max_images,
        min_agreement=args.min_agreement,
        min_confidence=args.min_confidence,
        overwrite=args.overwrite,
    )


if __name__ == "__main__":
    main()
