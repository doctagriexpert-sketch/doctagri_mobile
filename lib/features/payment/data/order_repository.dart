import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../domain/entities/order.dart';

/// Persiste la commande côté Supabase. La confirmation `paid` n'est PAS
/// faite ici : elle doit venir d'un webhook PSP côté backend. Ce dépôt
/// se contente d'insérer la commande au statut `processing` et de
/// retourner l'ordre enrichi de son `id` serveur.
///
/// En cas d'absence d'auth ou d'échec d'insert, lève [PaymentFailure] —
/// l'UI doit afficher une vraie erreur. **Aucun fallback mock ne doit
/// retourner `paid` côté client.**
class OrderRepository {
  Future<Order> createOrder(Order order) async {
    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (e) {
      throw PaymentFailure(
        'Service de paiement indisponible. Réessaie plus tard.',
        originalError: e,
      );
    }

    final user = client.auth.currentUser;
    if (user == null) {
      throw const PaymentFailure(
        'Connecte-toi pour valider la commande.',
      );
    }

    final payload = order
        .copyWith(userId: user.id, status: OrderStatus.processing)
        .toSupabaseJson();

    try {
      final row = await client
          .from('orders')
          .insert(payload)
          .select('id')
          .single();

      return order.copyWith(
        id: row['id'] as String?,
        userId: user.id,
        status: OrderStatus.processing,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OrderRepository] insert error: $e');
      }
      throw PaymentFailure(
        'Impossible d\'enregistrer la commande. Vérifie ta connexion.',
        originalError: e,
      );
    }
  }
}
