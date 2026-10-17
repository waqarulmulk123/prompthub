import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prompthub/features/feed/presentation/feed_notifier.dart';
import 'package:prompthub/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android public discovery, pagination, inspiration and account routes',
    (tester) async {
      await app.main();
      Future<void> until(bool Function() ready) async {
        for (var i = 0; i < 150 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(ready(), isTrue);
      }

      await until(() => find.byType(app.PromptVaultApp).evaluate().isNotEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.PromptVaultApp)),
      );
      await until(
        () =>
            container.read(feedNotifierProvider).asData?.value.items.length ==
            10,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await binding.takeScreenshot('android-home');
      }
      for (final count in [20, 30]) {
        await tester.scrollUntilVisible(
          find.text('Load 10 more'),
          600,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 30,
        );
        await tester.tap(find.text('Load 10 more'));
        await until(
          () =>
              container.read(feedNotifierProvider).asData?.value.items.length ==
              count,
        );
      }
      final prompts = container.read(feedNotifierProvider).asData!.value.items;
      expect(prompts.map((p) => p.id).toSet(), hasLength(30));
      expect(
        prompts.map((p) => p.outputs.first.imageUrl.split('?').first).toSet(),
        hasLength(30),
      );
      Future<void> tab(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tab('Quick Inspire');
      expect(
        find.text('← Skip · Save → · ↑ Open in your AI app'),
        findsOneWidget,
      );
      await tab('Collections');
      expect(find.text('Sign in to save your ideas'), findsOneWidget);
      await tab('Account');
      expect(find.text('Email me a sign-in link'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
