import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prompthub/core/database/app_database.dart';
import 'package:prompthub/features/auth/auth_service.dart';
import 'package:prompthub/features/collections/collections_repository.dart';
import 'package:prompthub/features/collections/collections_screen.dart';
import 'package:prompthub/features/feed/data/prompt_repository.dart';
import 'package:prompthub/features/subscription/pro_paywall_screen.dart';
import 'package:prompthub/features/subscription/subscription_service.dart';

class ReadyStore extends SubscriptionService {
  @override
  bool get supported => true;
  @override
  Future<List<Package>> packages(String userId) async => [];
  @override
  Future<void> restore(String userId) async {}
}

final account = User(
  id: 'test-account',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-17T00:00:00Z',
);

void main() {
  testWidgets('restore waits for trusted entitlement verification', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => Stream.value(account)),
          subscriptionServiceProvider.overrideWithValue(ReadyStore()),
          entitlementProvider.overrideWith((_) async => ++checks >= 3),
        ],
        child: const MaterialApp(home: Scaffold(body: ProPaywallScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore purchases'));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
    expect(checks, greaterThanOrEqualTo(3));
    expect(find.textContaining('Store request complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('private board chips filter their saved bookmarks', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = PromptRepository(
      database,
      PromptRemoteDatasource(Dio()),
    );
    await repository.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => Stream.value(account)),
          repositoryProvider.overrideWithValue(repository),
          boardsProvider.overrideWith(
            (_) async => [
              {'id': 'one', 'name': 'Campaign'},
              {'id': 'two', 'name': 'Portraits'},
            ],
          ),
          bookmarksProvider.overrideWith(
            (_) async => [
              const LocalBookmark(
                userId: 'test-account',
                promptId: 'pv_001',
                variables: '{}',
                collectionId: 'one',
              ),
              const LocalBookmark(
                userId: 'test-account',
                promptId: 'pv_002',
                variables: '{}',
                collectionId: 'two',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: CollectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.text('All saved'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}
