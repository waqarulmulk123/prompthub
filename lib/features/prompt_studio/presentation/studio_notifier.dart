import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/prompt_parser.dart';

class StudioNotifier extends Notifier<Map<String, String>> {
  StudioNotifier(this.id);
  final String id;
  @override
  Map<String, String> build() => {};
  void setValue(String key, String value) => state = {...state, key: value};
  void restore(Map<String, String> values) => state = Map.of(values);
  String compile(String template) => PromptParser.compile(template, state);
}

final studioProvider = NotifierProvider.autoDispose
    .family<StudioNotifier, Map<String, String>, String>(StudioNotifier.new);
