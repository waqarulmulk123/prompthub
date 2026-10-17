import 'package:flutter_test/flutter_test.dart';
import 'package:prompthub/core/utils/prompt_parser.dart';
import 'package:prompthub/features/prompt_studio/data/ai_launcher_service.dart';

void main() {
  test('variables preserve punctuation, repeated tokens and defaults', () {
    const template =
        '[Subject: bottle], lit by [Lighting: soft: warm]. Again [Subject: bottle].';
    expect(PromptParser.parse(template).map((v) => v.key), [
      'Subject',
      'Lighting',
    ]);
    expect(
      PromptParser.compile(template, {'Subject': '茶 & roses', 'Lighting': ' '}),
      '茶 & roses, lit by soft: warm. Again 茶 & roses.',
    );
  });
  test('malformed tokens and plain brackets are preserved', () {
    expect(
      PromptParser.compile('[broken] [Subject: cat', {}),
      '[broken] [Subject: cat',
    );
  });
  test('AI launcher encodes a query exactly once', () {
    const prompt = 'A&B + C? # café 🌿';
    final service = AiLauncherService();
    expect(
      service.url(TargetAIPlatform.chatGpt, prompt).queryParameters['q'],
      prompt,
    );
    expect(service.url(TargetAIPlatform.gemini, prompt).query, isEmpty);
  });
}
