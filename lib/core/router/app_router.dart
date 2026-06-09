import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/camera/presentation/pages/camera_page.dart';
import '../../features/diagnosis/presentation/pages/result_page.dart';
import '../../features/diagnosis/presentation/pages/history_page.dart';
import '../../features/diagnosis/domain/entities/disease_info.dart';
import '../../features/advice/presentation/pages/crop_advice_list_page.dart';
import '../../features/advice/presentation/pages/crop_detail_page.dart';
import '../../features/payment/domain/entities/order.dart';
import '../../features/payment/presentation/pages/checkout_page.dart';
import '../../features/payment/presentation/pages/payment_processing_page.dart';
import '../../features/payment/presentation/pages/payment_success_page.dart';
import '../presentation/app_shell.dart';
import '../presentation/splash_screen.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HistoryPage()),
          ),
        ],
      ),

      GoRoute(
        path: '/camera',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CameraPage(),
      ),
      GoRoute(
        path: '/result',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final imagePath = state.extra as String?;
          if (imagePath == null) {
            return const Scaffold(
              body: Center(child: Text('Image non trouvée')),
            );
          }
          return ResultPage(imagePath: imagePath);
        },
      ),

      // ─── Conseils par culture ────────────────────────────────────────
      GoRoute(
        path: '/advice',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CropAdviceListPage(),
      ),
      GoRoute(
        path: '/advice/:cropId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final cropId = state.pathParameters['cropId'] ?? '';
          return CropDetailPage(cropId: cropId);
        },
      ),

      // ─── Paiement ────────────────────────────────────────────────────
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final product = state.extra;
          if (product is! TreatmentProduct) {
            return const Scaffold(
              body: Center(child: Text('Produit non spécifié')),
            );
          }
          return CheckoutPage(product: product);
        },
      ),
      GoRoute(
        path: '/payment/processing',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final order = state.extra;
          if (order is! Order) {
            return const Scaffold(
              body: Center(child: Text('Commande invalide')),
            );
          }
          return PaymentProcessingPage(order: order);
        },
      ),
      GoRoute(
        path: '/payment/success',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final order = state.extra;
          if (order is! Order) {
            return const Scaffold(
              body: Center(child: Text('Commande invalide')),
            );
          }
          return PaymentSuccessPage(order: order);
        },
      ),
    ],
  );
}
