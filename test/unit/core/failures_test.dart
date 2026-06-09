import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('Failure', () {
    test('CacheFailure has correct message', () {
      const failure = CacheFailure('Cache error occurred');
      expect(failure.message, 'Cache error occurred');
      expect(failure.props, ['Cache error occurred']);
    });

    test('ModelFailure has correct message', () {
      const failure = ModelFailure('Model not loaded');
      expect(failure.message, 'Model not loaded');
    });

    test('failures are equatable', () {
      const failure1 = CacheFailure('Same message');
      const failure2 = CacheFailure('Same message');
      const failure3 = CacheFailure('Different message');
      expect(failure1, equals(failure2));
      expect(failure1, isNot(equals(failure3)));
    });
  });
}
