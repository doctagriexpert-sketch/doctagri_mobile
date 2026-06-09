import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order.dart';

enum PaymentState { idle, processing, success, error }

/// Provider gérant le flux de paiement.
///
/// État actuel : aucun PSP Mobile Money n'est intégré. `startCheckout`
/// insère la commande en base au statut `processing` et expose l'erreur
/// à l'UI si quelque chose échoue. Le passage à `paid` doit être pris
/// en charge par un webhook côté backend une fois le PSP branché.
class PaymentProvider extends ChangeNotifier {
  final OrderRepository _repo;

  PaymentProvider({OrderRepository? repository})
      : _repo = repository ?? OrderRepository();

  PaymentState _state = PaymentState.idle;
  Order? _confirmedOrder;
  String? _errorMessage;

  PaymentState get state => _state;
  Order? get confirmedOrder => _confirmedOrder;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _state == PaymentState.processing;

  Future<void> startCheckout(Order order) async {
    _state = PaymentState.processing;
    _errorMessage = null;
    _confirmedOrder = null;
    notifyListeners();

    try {
      // TODO(payment): brancher un PSP Mobile Money réel (Mixx By Yas /
      // Flooz). Le statut `paid` doit être positionné par un webhook
      // backend, jamais ici.
      _confirmedOrder = await _repo.createOrder(
        order.copyWith(status: OrderStatus.processing),
      );
      _state = PaymentState.success;
    } on PaymentFailure catch (f) {
      _errorMessage = f.message;
      _state = PaymentState.error;
      if (kDebugMode) {
        debugPrint('[PaymentProvider] PaymentFailure: ${f.message} '
            '(${f.originalError})');
      }
    } catch (e) {
      _errorMessage = 'Erreur inattendue. Réessaie.';
      _state = PaymentState.error;
      if (kDebugMode) {
        debugPrint('[PaymentProvider] unexpected error: $e');
      }
    }
    notifyListeners();
  }

  void reset() {
    _state = PaymentState.idle;
    _confirmedOrder = null;
    _errorMessage = null;
    notifyListeners();
  }
}
