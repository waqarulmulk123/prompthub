// onesignal:managed v1 — bridge to the web/push.js wrapper.
import 'dart:js_interop';

@JS('promptVaultPushReady')
external bool get _ready;
@JS('promptVaultPushRequest')
external JSPromise<JSBoolean> _request();

class PushService {
  static bool get available {
    try {
      return _ready;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initialize() async {}
  static Future<bool> requestPermission() async =>
      (await _request().toDart).toDart;
}
