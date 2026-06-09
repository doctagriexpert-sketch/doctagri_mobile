import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/typography.dart';
import '../../domain/entities/order.dart';
import '../providers/payment_provider.dart';

/// Écran de traitement : déclenche [PaymentProvider.startCheckout] puis
/// navigue automatiquement vers succès ou ré-affiche l'erreur.
class PaymentProcessingPage extends StatefulWidget {
  final Order order;
  const PaymentProcessingPage({super.key, required this.order});

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  late final PaymentProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = PaymentProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.startCheckout(widget.order);
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    if (_provider.state == PaymentState.success &&
        _provider.confirmedOrder != null) {
      context.pushReplacement(
        '/payment/success',
        extra: _provider.confirmedOrder,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Consumer<PaymentProvider>(
          builder: (context, provider, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onStateChange();
            });
            return SafeArea(
              child: Padding(
                padding: Spacing.pagePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    if (provider.state == PaymentState.error)
                      _buildError(provider)
                    else
                      _buildLoading(),
                    const Spacer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 36,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
        Gaps.v21,
        Text(
          'Traitement du paiement…',
          style: AppTypography.h2Dark.copyWith(color: AppColors.bark),
        ),
        Gaps.v11,
        Text(
          'Confirmez la transaction sur votre téléphone\n${widget.order.paymentMethod.displayName}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.bark.withAlpha(180),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildError(PaymentProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(15),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.danger.withAlpha(80)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 44),
          Gaps.v14,
          Text(
            'Paiement échoué',
            style: AppTypography.h2Dark.copyWith(color: AppColors.danger),
          ),
          Gaps.v7,
          Text(
            provider.errorMessage ?? 'Erreur inconnue',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.bark),
          ),
          Gaps.v14,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Retour'),
                ),
              ),
              Gaps.h11,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    provider.reset();
                    provider.startCheckout(widget.order);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
