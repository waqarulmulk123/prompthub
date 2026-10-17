import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prompthub/main.dart';
import 'package:prompthub/features/feed/presentation/feed_notifier.dart';

class TestFeed extends FeedNotifier {
  @override
  Future<FeedState> build() async => const FeedState(items: [], hasMore: false);
  @override
  Future<void> refresh({bool preservePages = false}) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Discovery shell adapts at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [feedNotifierProvider.overrideWith(TestFeed.new)],
          child: const PromptVaultApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PromptVault'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
