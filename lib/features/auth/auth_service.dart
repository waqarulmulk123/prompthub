import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/database/app_database.dart';

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
  AuthService(this.client, this.database);
  final SupabaseClient? client;
  final AppDatabase database;
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
  Future<void> _clearLocalAccount() async {
    final id = requiredClient.auth.currentUser?.id;
    if (id != null) {
      await (database.delete(
        database.localBookmarks,
      )..where((t) => t.userId.equals(id))).go();
    }
  }

  Future<void> signOut() async {
    await _clearLocalAccount();
    await requiredClient.auth.signOut();
  }

  Future<void> deleteAccount() async {
    final result = await requiredClient.functions.invoke(
      'delete-account',
      body: {'confirmation': 'DELETE'},
    );
    if (result.status != 200 || result.data['deleted'] != true) {
      throw StateError('Deletion failed');
    }
    await _clearLocalAccount();
    await requiredClient.auth.signOut(scope: SignOutScope.local);
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) =>
      AuthService(ref.watch(supabaseProvider), ref.watch(databaseProvider)),
);
