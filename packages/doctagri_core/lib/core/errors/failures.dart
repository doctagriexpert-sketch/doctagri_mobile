import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final Object? originalError;

  const Failure(this.message, {this.originalError});

  @override
  List<Object?> get props => [message];
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.originalError});
}

class ModelFailure extends Failure {
  const ModelFailure(super.message, {super.originalError});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.originalError});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.originalError});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.originalError});
}

class ImageProcessingFailure extends Failure {
  const ImageProcessingFailure(super.message, {super.originalError});
}
