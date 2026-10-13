import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/entities/order.dart';

/// Écran de confirmation post-paiement réussi.
class PaymentSuccessPage extends StatelessWidget {
  final Order order;
  const PaymentSuccessPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('fr_FR');
    final orderRef = order.id != null
        ? order.id!.substring(0, 8).toUpperCase()
        : '—';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: Spacing.pagePadding,
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.healthy.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: AppColors.healthy,
                ),
              ),
              Gaps.v21,
              Text(
                'Commande enregistrée',
                style: AppTypography.display.copyWith(color: AppColors.bark),
              ),
              Gaps.v7,
              Text(
                'Le paiement sera confirmé après validation Mobile Money.',
                style: AppTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
              Gaps.v21,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadius.cardMain,
                  border: Border.all(color: AppColors.primary.withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Numéro', '#$orderRef'),
                    const Divider(),
                    _row('Produit', order.productName),
                    _row('Quantité', '${order.quantity}'),
                    _row('Méthode', order.paymentMethod.displayName),
                    const Divider(),
                    _row(
                      'Total payé',
                      '${fmt.format(order.totalXof)} FCFA',
                      bold: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(20),
                  borderRadius: AppRadius.small,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                    Gaps.h7,
                    Expanded(
                      child: Text(
                        'Le produit vous sera livré par DoctAgri Shop sous 48h.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gaps.v14,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_rounded, size: 20),
                  label: const Text(
                    "Retour à l'accueil",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.large,
                    ),
                  ),
                ),
              ),
              Gaps.v14,
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.bark.withAlpha(180),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              color: AppColors.bark,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
