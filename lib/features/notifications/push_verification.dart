// onesignal:managed v1 — debug-only helper, installed by push_native.dart initialize(). Safe to keep.
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

bool _installed = false, _logged = false;
void installPushVerification() {
  if (!kDebugMode || _installed) return;
  _installed = true;
  void inspect(String? id) {
    if (!_logged && id != null && id.isNotEmpty && !id.startsWith('local-')) {
      _logged = true;
      debugPrint('OneSignal test subscription: $id');
    }
  }

  OneSignal.User.pushSubscription.addObserver(
    (state) => inspect(state.current.id),
  );
  inspect(OneSignal.User.pushSubscription.id);
  if (const bool.fromEnvironment('ONESIGNAL_VERIFY_PUSH')) {
    OneSignal.Notifications.requestPermission(false);
  }
}
