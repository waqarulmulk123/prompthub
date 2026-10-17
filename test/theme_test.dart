import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prompthub/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  test('primary action text has at least 4.5 to 1 contrast', () {
    final theme = AppTheme.dark;
    final style = theme.filledButtonTheme.style!;
    final foreground =
        (style.foregroundColor?.resolve({}) ?? theme.colorScheme.onPrimary)
            .computeLuminance();
    final background =
        (style.backgroundColor?.resolve({}) ?? theme.colorScheme.primary)
            .computeLuminance();
    final lighter = foreground > background ? foreground : background;
    final darker = foreground < background ? foreground : background;
    expect((lighter + .05) / (darker + .05), greaterThanOrEqualTo(4.5));
  });
}
