import 'package:equatable/equatable.dart';

/// Méthodes de paiement Mobile Money disponibles au Togo.
enum PaymentMethod {
  /// Mixx By Yas — anciennement Tmoney (réseau Togocel/Yas)
  mixxByYas('mixx_by_yas', 'Mixx By Yas'),

  /// Moov Money Flooz — réseau Moov Africa Togo
  moovMoney('moov_money', 'Moov Money (Flooz)');

  final String apiValue;
  final String displayName;
  const PaymentMethod(this.apiValue, this.displayName);

  static PaymentMethod fromApi(String value) => values.firstWhere(
        (m) => m.apiValue == value,
        orElse: () => PaymentMethod.mixxByYas,
      );
}

/// Statut du paiement (cycle de vie de la commande).
enum OrderStatus {
  pending,
  processing,
  paid,
  failed,
  refunded;

  String get apiValue => name;

  static OrderStatus fromApi(String value) => values.firstWhere(
        (s) => s.name == value,
        orElse: () => OrderStatus.pending,
      );
}

/// Commande utilisateur (achat Mobile Money simulé).
class Order extends Equatable {
  final String? id;
  final String? userId;
  final String productSku;
  final String productName;
  final double priceXof;
  final int quantity;
  final String phoneNumber;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final DateTime createdAt;

  const Order({
    this.id,
    this.userId,
    required this.productSku,
    required this.productName,
    required this.priceXof,
    required this.quantity,
    required this.phoneNumber,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  double get totalXof => priceXof * quantity;

  Map<String, dynamic> toSupabaseJson() => {
        if (userId != null) 'user_id': userId,
        'product_sku': productSku,
        'product_name': productName,
        'price_xof': priceXof,
        'quantity': quantity,
        'phone_number': phoneNumber,
        'payment_method': paymentMethod.apiValue,
        'status': status.apiValue,
        'created_at': createdAt.toIso8601String(),
      };

  Order copyWith({
    String? id,
    String? userId,
    OrderStatus? status,
  }) =>
      Order(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        productSku: productSku,
        productName: productName,
        priceXof: priceXof,
        quantity: quantity,
        phoneNumber: phoneNumber,
        paymentMethod: paymentMethod,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        productSku,
        productName,
        priceXof,
        quantity,
        phoneNumber,
        paymentMethod,
        status,
        createdAt,
      ];
}
