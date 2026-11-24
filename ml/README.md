# DoctAgri ML Pipeline

## Overview
This directory contains the reproducible ML pipeline for model quantization and validation.

## Pipeline Steps

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `01_export_savedmodel.py` | Export Keras model to TensorFlow SavedModel |
| 2 | `02_build_representative_dataset.py` | Build INT8 calibration dataset (500+ images) |
| 3 | `03_quantize_int8.py` | Quantize Float32 → Int8 with per-channel |
| 4 | `04_validate_accuracy.py` | Validate accuracy on hold-out test set |
| 5 | `05_benchmark_device.py` | Benchmark latency on reference devices |
| 6 | `06_package_artifact.py` | Package with metadata + SHA256 + registry |

### Analysis tools (no labels required)

| Script | Purpose |
|--------|---------|
| `07_field_domain_analysis.py` | Unsupervised lab→field domain-shift analysis: compares model output distributions (confidence/entropy/margin) on field vs lab images, quantifies the gap (KS distance), recommends abstention thresholds. No ground-truth labels needed. |
| `08_vlm_label.py` | VLM-assisted labeling of unlabeled field photos (Claude vision). Proposes crop + disease + severity + photo quality, grounded in the app's taxonomy (registry + knowledge base); outputs a resumable CSV a non-expert verifies. `--validate_dir` first measures VLM reliability against a labeled set (PlantVillage) before trusting it. Needs `pip install anthropic` + `ANTHROPIC_API_KEY`. |
| `09_ensemble_annotate.py` | Multi-model committee annotation (Ensemble Consensus). Combines up to 9 models across complementary paradigms: 5 Hugging Face vision models (ViT Tomato, ResNet-50 Tomato, ResNet-18 PlantVillage, MobileNetV2 PlantVillage, ConvNeXt-Tiny PlantVillage), 2 edge TFLite models (PlantVillage INT8, Cassava FP16), 1 full Keras MobileNetV2, and 1 VLM (Claude/Gemini vision). Governed by 3 safety barriers: unified canonical taxonomy, calibrated temperature scaling, and domain-shift/OOD entropy rejection. Produces an actionable CSV triaged into `AUTO_APPROVED`, `NEEDS_HUMAN_REVIEW`, and `REJECTED_UNUSABLE`. |

### Shared module — `app_inference.py`

`app_inference.py` is the **single source of truth** for pre/post-processing,
aligned with the Flutter app. Scripts 04 and 07 import it. Do NOT reimplement
preprocessing inline — that reopens the validation↔production drift bug.

## Usage

```bash
cd ml/pipeline

# Export model
python 01_export_savedmodel.py --model_path ../../plant_disease_model.keras --output_dir ../../savedmodel

# Build calibration dataset (from real leaf images)
python 02_build_representative_dataset.py --source_dir /path/to/leaf/images --output_file ../datasets/representative/calibration.npy

# Quantize
python 03_quantize_int8.py --savedmodel_dir ../../savedmodel --representative_dataset_file ../datasets/representative/calibration.npy --output_dir ../models

# Validate
python 04_validate_accuracy.py --model_path ../models/model_int8.tflite --test_images_dir /path/to/test --labels_file ../../assets/models/labels.txt

# Benchmark
python 05_benchmark_device.py --model_path ../models/model_int8.tflite

# Package
python 06_package_artifact.py --model_path ../models/model_int8.tflite --labels_file ../../assets/models/labels.txt --output_dir ../models --assets_models_dir ../../assets/models --version cassava-v1.0.0 --accuracy 0.94
```

## Makefile Targets

```bash
make help          # Show available targets
make export        # Step 1: Export to SavedModel
make quantize      # Step 3: Quantize to INT8
make validate      # Step 4: Validate accuracy
make benchmark     # Step 5: Benchmark latency
make package       # Step 6: Package artifact
make all           # Run full pipeline
```

## Model Metadata

| Field | Value |
|-------|-------|
| Base Model | MobileNetV3-Large (TF 2.15 / Keras 2.15) |
| Input Shape | [1, 224, 224, 3] |
| Quantization | INT8 with per-channel |
| Target Size | < 3 MB |
| Target Accuracy | > 92% |
| Target Latency | < 50ms |

## Preprocessing — depends on the model's INPUT dtype

⚠️ Read the input dtype from the model; do not assume. Both bundled models are
full-integer quantized → **uint8 input**, fed RAW 0-255 (this is what INT8
calibration in step 2 expects). ImageNet normalization applies ONLY to
float-input models.

```python
# Resize: bilinear, to the size read from the model (160 or 224 — NOT hardcoded)
# uint8-input model:  feed raw pixels 0-255  (cassava, plantvillage)
# float-input model:  pixel = (pixel - mean) / std
mean = [123.675, 116.28, 103.53]
std  = [58.395, 57.12, 57.375]
```

## Output — these models output PROBABILITIES, not logits

⚠️ Both bundled models include a final softmax (dequantized output sums to ~1,
scale 1/256, zero 0). Applying `softmax` again is a **double softmax** that
crushes confidence (99% → ~7% on 39 classes). Dequantize, then renormalize —
do NOT re-softmax. `app_inference.to_probabilities` handles both cases.

```python
prob = (raw_uint8 - zero_point) * scale   # already a probability for these models
probs = prob / prob.sum()                  # renormalize, NO softmax
confidence = probs[argmax]
```

## Registry

Each packaged model gets an entry in `ml/models/registry.json`:

```json
{
  "version": "cassava-v1.0.0",
  "filename": "model.tflite",
  "sha256": "abc123...",
  "accuracy": 0.94,
  "mean": [123.675, 116.28, 103.53],
  "std": [58.395, 57.12, 57.375],
  "input_shape": [1, 224, 224, 3],
  "num_classes": 6,
  "released_at": "2026-04-17T00:00:00Z"
}
```

## Notebooks d'entraînement & Stockage des poids bruts

### 1. Notebooks (`ml/notebooks/`)
- `ml/notebooks/plantvillage_training_colab.ipynb` : Notebook d'entraînement Google Colab (MobileNetV2, 38 classes PlantVillage). Permet de reproduire l'apprentissage du modèle de base.

### 2. Poids bruts Keras (`plant_disease_model.keras`)
- **Poids** : ~395 Mo (Keras SavedModel / format `.keras`).
- **Politique de stockage GitHub** : GitHub refuse les fichiers supérieurs à 100 Mo (`GH001`). Le fichier `*.keras` est donc exclu par le `.gitignore`.
- **Hébergement recommandé** : Stocké sur Hugging Face Hub, Google Drive ou GitHub Releases (liens de téléchargement directs), puis quantifié en TFLite INT8 (`assets/models/plantvillage/model_int8.tflite`, 4,9 Mo) pour l'application mobile.

## Démarche de modélisation : Modèle de laboratoire (.keras) vs Modèle embarqué terrain (TFLite INT8)

La conception du système de vision artificielle de DoctAgri s'est articulée en deux phases complémentaires :

1. **Phase expérimentale & reproductibilité (Laboratoire)** :
   - Conception et entraînement d'une architecture MobileNetV2 (38 classes, format `.keras`, 395 Mo) documentée dans `ml/notebooks/plantvillage_training_colab.ipynb`.
   - **Objectif** : Maîtriser la chaîne complète d'apprentissage (augmentation de données, pondération des classes, convergence) et établir une **baseline de référence scientifique**.

2. **Phase d'industrialisation & contraintes terrain au Togo (Edge AI)** :
   - Le déploiement au champ auprès des producteurs togolais impose un diagnostic **100 % hors-ligne** sur des smartphones d'entrée de gamme (avec interface adaptée en Français, Éwé et Kabyè).
   - Un modèle Float32 de 395 Mo étant incompatible avec ces contraintes (téléchargement impossible en zone rurale, saturation mémoire RAM, décharge rapide de la batterie), nous avons retenu une architecture EfficientNet quantifiée en **Full INT8** (`assets/models/plantvillage/model_int8.tflite`, 4,9 Mo).
   - **Bénéfices d'ingénierie** : Réduction de l'empreinte mémoire de **98,7 %**, inférence fluide en moins de 100 ms sur CPU mobile et zéro consommation de données mobiles au champ.

3. **Synergie opérationnelle (Comité d'annotation multi-modèles)** :
   - Le modèle `.keras` n'est pas abandonné : il est réexploité côté pipeline / station de travail dans l'outil d'annotation par consensus (`ml/pipeline/09_ensemble_annotate.py`) aux côtés des modèles Hugging Face et du VLM pour valider et calibrer les annotations des photos de terrain.


