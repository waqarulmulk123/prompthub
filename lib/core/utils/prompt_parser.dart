import '../../features/feed/domain/prompt_item.dart';

abstract final class PromptParser {
  static final token = RegExp(r'\[([^:\[\]\r\n]+):\s*([^\[\]\r\n]*)\]');
  static List<PromptVariable> parse(String template) {
    final variables = <String, PromptVariable>{};
    for (final match in token.allMatches(template)) {
      final key = match[1]!.trim();
      if (key.isNotEmpty) {
        variables.putIfAbsent(
          key,
          () => PromptVariable(key: key, defaultValue: match[2]!.trim()),
        );
      }
    }
    return variables.values.toList();
  }

  static String compile(String template, Map<String, String> values) =>
      template.replaceAllMapped(token, (match) {
        final key = match[1]!.trim();
        final value = values[key]?.trim();
        return value == null || value.isEmpty ? match[2]!.trim() : value;
      });
}
