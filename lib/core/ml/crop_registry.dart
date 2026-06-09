import 'package:equatable/equatable.dart';

class CropModule extends Equatable {
  final String id;
  final String displayName;
  final PreprocessingConfig preprocessing;
  final List<DiseaseInfo> diseases;

  const CropModule({
    required this.id,
    required this.displayName,
    required this.preprocessing,
    required this.diseases,
  });

  @override
  List<Object?> get props => [id, displayName, preprocessing, diseases];
}

class PreprocessingConfig extends Equatable {
  final List<double> mean;
  final List<double> std;
  final int inputSize;

  const PreprocessingConfig({
    required this.mean,
    required this.std,
    this.inputSize = 224,
  });

  @override
  List<Object?> get props => [mean, std, inputSize];
}

class DiseaseInfo extends Equatable {
  final String id;
  final String modelLabel;
  final String displayName;
  final String description;
  final String severity;
  final bool isHealthy;
  final List<Treatment> treatments;
  final List<Product> products;

  const DiseaseInfo({
    required this.id,
    required this.modelLabel,
    required this.displayName,
    required this.description,
    required this.severity,
    required this.isHealthy,
    required this.treatments,
    required this.products,
  });

  @override
  List<Object?> get props => [id, modelLabel, displayName];
}

class Treatment extends Equatable {
  final String method;
  final List<String> steps;

  const Treatment({required this.method, required this.steps});

  @override
  List<Object?> get props => [method, steps];
}

class Product extends Equatable {
  final String name;
  final String dosage;

  const Product({required this.name, required this.dosage});

  @override
  List<Object?> get props => [name, dosage];
}

class CropRegistry {
  static final CropRegistry _instance = CropRegistry._();
  factory CropRegistry() => _instance;
  CropRegistry._();

  final Map<String, CropModule> _modules = {};

  Future<void> register(CropModule module) async {
    _modules[module.id] = module;
  }

  CropModule? getActive() {
    return _modules['cassava'];
  }

  List<CropModule> availableCrops() {
    return _modules.values.toList();
  }

  Future<void> switchCrop(String cropId) async {
    // TODO: Implement crop switching
  }
}
