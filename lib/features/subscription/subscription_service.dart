import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config/app_config.dart';
import '../auth/auth_service.dart';

final entitlementProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authProvider).asData?.value;
  final client = ref.watch(supabaseProvider);
  if (user == null || client == null) return false;
  return await client.rpc('effective_pro') == true;
});

class SubscriptionService {
  String? _userId;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  Future<void> configure(String userId) async {
    if (!supported) throw StateError('Use web checkout on this platform.');
    final key = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConfig.iosPurchaseKey
        : AppConfig.androidPurchaseKey;
    if (key.isEmpty) {
      throw StateError('Subscriptions are not configured for this store yet.');
    }
    if (_userId == null) {
      await Purchases.configure(
        PurchasesConfiguration(key)..appUserID = userId,
      );
    } else if (_userId != userId) {
      await Purchases.logIn(userId);
    }
    _userId = userId;
  }

  Future<List<Package>> packages(String userId) async {
    await configure(userId);
    return (await Purchases.getOfferings()).current?.availablePackages ?? [];
  }

  Future<void> purchase(Package package) async {
    await Purchases.purchase(PurchaseParams.package(package));
  }

  Future<void> restore(String userId) async {
    await configure(userId);
    await Purchases.restorePurchases();
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>(
  (ref) => SubscriptionService(),
);
