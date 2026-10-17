import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

final supabaseProvider = Provider<SupabaseClient?>(
  (ref) => AppConfig.hasSupabase ? Supabase.instance.client : null,
);
final authProvider = StreamProvider<User?>((ref) async* {
  final client = ref.watch(supabaseProvider);
  if (client == null) {
    yield null;
    return;
  }
  yield client.auth.currentUser;
  yield* client.auth.onAuthStateChange.map((event) => event.session?.user);
});

class AuthService {
  AuthService(this.client);
  final SupabaseClient? client;
  String get redirect =>
      kIsWeb ? Uri.base.origin : 'promptvault://login-callback';
  SupabaseClient get requiredClient =>
      client ?? (throw StateError('Cloud sign-in is not configured yet.'));
  Future<void> sendMagicLink(String email) async {
    final normalized = email.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid email address.');
    }
    await requiredClient.auth.signInWithOtp(
      email: normalized,
      emailRedirectTo: redirect,
    );
  }

  Future<void> oauth(OAuthProvider provider) => requiredClient.auth
      .signInWithOAuth(provider, redirectTo: redirect)
      .then((_) {});
  Future<void> signOut() => requiredClient.auth.signOut();
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseProvider)),
);
