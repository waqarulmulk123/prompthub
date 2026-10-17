// onesignal:managed v1 — all native SDK calls are centralized here.
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'push_verification.dart';

class PushService {
  static const appId = '35457a90-e34c-4e5a-92c7-78aec84ca238';
  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  static bool get available =>
      supported && const bool.fromEnvironment('ONESIGNAL_NATIVE_READY');
  static Future<void> initialize() async {
    if (!available) return;
    OneSignal.initialize(appId);
    if (kDebugMode) {
      installPushVerification();
    }
  }

  // User explicitly requested a production opt-in for daily drops.
  static Future<bool> requestPermission() =>
      OneSignal.Notifications.requestPermission(false);
}
