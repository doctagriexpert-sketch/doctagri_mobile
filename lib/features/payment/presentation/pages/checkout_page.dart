import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/typography.dart';
import '../../../diagnosis/domain/entities/disease_info.dart';
import '../../domain/entities/order.dart';

/// Écran de récapitulatif d'achat avant déclenchement du paiement Mobile Money.
///
/// Reçoit un [TreatmentProduct] en extra via go_router.
class CheckoutPage extends StatefulWidget {
  final TreatmentProduct product;
  const CheckoutPage({super.key, required this.product});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  PaymentMethod _method = PaymentMethod.mixxByYas;
  int _quantity = 1;

  static final _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  double get _total => (widget.product.priceXof ?? 0) * _quantity;

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Numéro invalide';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final order = Order(
      productSku: widget.product.sku ?? 'UNKNOWN',
      productName: widget.product.name,
      priceXof: widget.product.priceXof ?? 0,
      quantity: _quantity,
      phoneNumber: _phoneController.text.trim(),
      paymentMethod: _method,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );

    context.push('/payment/processing', extra: order);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.bark,
        elevation: 0,
        title: const Text('Valider la commande'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: Spacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductCard(p),
                Gaps.v21,
                _buildQuantitySelector(),
                Gaps.v21,
                Text('Méthode de paiement', style: AppTypography.h3),
                Gaps.v11,
                ...PaymentMethod.values.map(_buildMethodTile),
                Gaps.v21,
                Text('Numéro Mobile Money', style: AppTypography.h3),
                Gaps.v7,
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                  ],
                  validator: _validatePhone,
                  decoration: InputDecoration(
                    hintText: '+228 90 00 00 00',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                      borderSide: BorderSide(color: AppColors.fog),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.medium,
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Gaps.v21,
                _buildTotal(),
                Gaps.v14,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.lock_rounded, size: 20),
                    label: Text(
                      'Payer ${_fmt.format(_total)} FCFA',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.large,
                      ),
                    ),
                  ),
                ),
                Gaps.v11,
                Center(
                  child: Text(
                    'Paiement sécurisé · DoctAgri Shop',
                    style: TextStyle(fontSize: 11, color: AppColors.fog),
                  ),
                ),
                Gaps.v21,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(TreatmentProduct p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardMain,
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(30),
              borderRadius: AppRadius.medium,
            ),
            child: Icon(
              Icons.local_pharmacy_rounded,
              color: AppColors.secondary,
              size: 28,
            ),
          ),
          Gaps.h14,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: AppTypography.h3.copyWith(color: AppColors.bark),
                ),
                Gaps.v3,
                Text(
                  p.dosage,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.bark.withAlpha(180),
                  ),
                ),
                Gaps.v3,
                if (p.vendor != null)
                  Text(
                    p.vendor!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${_fmt.format(p.priceXof ?? 0)} F',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text('Quantité', style: AppTypography.h3),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.medium,
            border: Border.all(color: AppColors.primary.withAlpha(60)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                color: AppColors.primary,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: _quantity < 10
                    ? () => setState(() => _quantity++)
                    : null,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Couleurs de marque des opérateurs Togo ──────────────────────────────
  static const _colorMixx = Color(0xFF6B21A8); // Violet Yas
  static const _colorMoov = Color(0xFF0056B3); // Bleu Moov Africa

  static Color _brandColor(PaymentMethod m) {
    return switch (m) {
      PaymentMethod.mixxByYas => _colorMixx,
      PaymentMethod.moovMoney => _colorMoov,
    };
  }

  static String _brandSubtitle(PaymentMethod m) {
    return switch (m) {
      PaymentMethod.mixxByYas => 'Réseau Togocel · anciennement Tmoney',
      PaymentMethod.moovMoney => 'Réseau Moov Africa Togo · Flooz',
    };
  }

  Widget _buildMethodTile(PaymentMethod m) {
    final selected = _method == m;
    final brand = _brandColor(m);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _method = m),
        borderRadius: AppRadius.medium,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? brand.withAlpha(18) : AppColors.card,
            borderRadius: AppRadius.medium,
            border: Border.all(
              color: selected ? brand : AppColors.fog,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icône avec fond coloré
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: brand.withAlpha(selected ? 40 : 22),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: brand,
                  size: 22,
                ),
              ),
              Gaps.h11,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AppColors.bark,
                      ),
                    ),
                    Gaps.v3,
                    Text(
                      _brandSubtitle(m),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.bark.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? brand : AppColors.fog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(15),
        borderRadius: AppRadius.medium,
        border: Border.all(color: AppColors.secondary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Text(
            'Total à payer',
            style: AppTypography.h3.copyWith(color: AppColors.bark),
          ),
          const Spacer(),
          Text(
            '${_fmt.format(_total)} FCFA',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
