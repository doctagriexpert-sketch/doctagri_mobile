.PHONY: help export quantize validate benchmark package clean

MODEL_PATH ?= ../plant_disease_model.keras
SAVEDMODEL_DIR ?= ../savedmodel
CALIB_FILE ?= ../datasets/representative/calibration.npy
TEST_IMAGES_DIR ?= ../datasets/test
ASSETS_MODELS_DIR ?= ../assets/models
OUTPUT_DIR ?= ../ml/models
LABELS_FILE ?= ../assets/models/labels.txt
VERSION ?= cassava-v1.0.0
EXPECTED_ACCURACY ?= 0.92

help:
	@echo "DoctAgri ML Pipeline"
	@echo "==================="
	@echo "Targets:"
	@echo "  export     - Export Keras model to SavedModel format"
	@echo "  quantize   - Quantize to INT8"
	@echo "  validate   - Validate accuracy on test set"
	@echo "  benchmark  - Benchmark latency"
	@echo "  package    - Package artifact with metadata"
	@echo "  all        - Run full pipeline"
	@echo ""
	@echo "Variables:"
	@echo "  MODEL_PATH=$(MODEL_PATH)"
	@echo "  VERSION=$(VERSION)"
	@echo "  EXPECTED_ACCURACY=$(EXPECTED_ACCURACY)"

export:
	python 01_export_savedmodel.py --model_path $(MODEL_PATH) --output_dir $(SAVEDMODEL_DIR)

quantize:
	python 03_quantize_int8.py \
		--savedmodel_dir $(SAVEDMODEL_DIR) \
		--representative_dataset_file $(CALIB_FILE) \
		--output_dir $(OUTPUT_DIR)

validate:
	python 04_validate_accuracy.py \
		--model_path $(OUTPUT_DIR)/model_int8.tflite \
		--test_images_dir $(TEST_IMAGES_DIR) \
		--labels_file $(LABELS_FILE) \
		--expected_accuracy $(EXPECTED_ACCURACY)

benchmark:
	python 05_benchmark_device.py --model_path $(OUTPUT_DIR)/model_int8.tflite

package:
	python 06_package_artifact.py \
		--model_path $(OUTPUT_DIR)/model_int8.tflite \
		--labels_file $(LABELS_FILE) \
		--output_dir $(OUTPUT_DIR) \
		--assets_models_dir $(ASSETS_MODELS_DIR) \
		--version $(VERSION) \
		--accuracy $(EXPECTED_ACCURACY)

annotate-ensemble:
	python 09_ensemble_annotate.py \
		--images_dir ../../data/field_photos \
		--output_csv ../../data/ensemble_annotations.csv

evaluate-field:
	python 10_evaluate_field_accuracy.py

all: export quantize validate benchmark package

clean:
	rm -rf $(SAVEDMODEL_DIR)
	rm -f $(OUTPUT_DIR)/*.tflite
	rm -f $(OUTPUT_DIR)/registry.json
