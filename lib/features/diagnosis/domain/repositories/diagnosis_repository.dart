import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/diagnosis_result.dart';

abstract class DiagnosisRepository {
  Future<Either<Failure, DiagnosisResult>> analyzeImage(String imagePath);
}
