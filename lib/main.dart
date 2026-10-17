import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/notifications/push_service.dart'; // onesignal:managed v1
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;
  SupabaseClient? client;
  if (AppConfig.hasSupabase) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseKey,
      );
      client = Supabase.instance.client;
    } catch (_) {
      // Catalog access remains available when account startup fails offline.
    }
  }
  // onesignal:managed v1 — push never blocks catalog startup.
  try {
    await PushService.initialize();
  } catch (_) {}
  runApp(
    ProviderScope(
      overrides: [supabaseProvider.overrideWithValue(client)],
      child: const PromptVaultApp(),
    ),
  );
}

class PromptVaultApp extends ConsumerWidget {
  const PromptVaultApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'PromptVault AI',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    routerConfig: ref.watch(routerProvider),
  );
}
