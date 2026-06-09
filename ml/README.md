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

## Preprocessing (ImageNet normalization)

```python
mean = [123.675, 116.28, 103.53]
std = [58.395, 57.12, 57.375]
pixel = (pixel - mean) / std
```

## Output Dequantization

For quantized models, output must be dequantized:

```python
logit = (raw_uint8 - zero_point) * scale
confidence = softmax(logits)[argmax]
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
