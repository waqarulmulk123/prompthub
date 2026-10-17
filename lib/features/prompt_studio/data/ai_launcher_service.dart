import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum TargetAIPlatform { chatGpt, gemini, claude, perplexity }

class AiLauncherService {
  Uri url(TargetAIPlatform platform, String prompt) => switch (platform) {
    TargetAIPlatform.chatGpt => Uri.https('chatgpt.com', '/', {'q': prompt}),
    TargetAIPlatform.gemini => Uri.https('gemini.google.com', '/app'),
    TargetAIPlatform.claude => Uri.https('claude.ai', '/new', {'q': prompt}),
    TargetAIPlatform.perplexity => Uri.https('www.perplexity.ai', '/search', {
      'q': prompt,
    }),
  };
  Future<bool> launchWithPrompt(
    TargetAIPlatform platform,
    String prompt,
  ) async {
    if (prompt.trim().isEmpty) throw ArgumentError('Prompt is empty');
    // Copy first so unsupported external autofill still has a usable fallback.
    await Clipboard.setData(ClipboardData(text: prompt));
    return launchUrl(
      url(platform, prompt),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }
}
