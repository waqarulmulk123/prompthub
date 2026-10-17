const discoveryPageSize = 10;

class PromptVariable {
  const PromptVariable({
    required this.key,
    required this.defaultValue,
    this.suggestions = const [],
  });
  final String key;
  final String defaultValue;
  final List<String> suggestions;
  factory PromptVariable.fromJson(Map<String, dynamic> json) => PromptVariable(
    key: json['key'] as String,
    defaultValue: json['default_value'] as String,
    suggestions: (json['suggestions'] as List? ?? []).cast<String>(),
  );
  Map<String, dynamic> toJson() => {
    'key': key,
    'default_value': defaultValue,
    'suggestions': suggestions,
  };
}

class PromptOutput {
  const PromptOutput({
    required this.model,
    required this.imageUrl,
    required this.aspectRatio,
    required this.blurHash,
  });
  final String model;
  final String imageUrl;
  final double aspectRatio;
  final String blurHash;
  factory PromptOutput.fromJson(Map<String, dynamic> json) {
    final ratio = (json['aspect_ratio'] as num).toDouble();
    final url = Uri.parse(json['image_url'] as String);
    if (ratio < 0.25 ||
        ratio > 4 ||
        !ratio.isFinite ||
        url.scheme != 'https' ||
        url.host != 'images.unsplash.com' ||
        url.userInfo.isNotEmpty ||
        url.hasPort) {
      throw const FormatException('Invalid catalog image');
    }
    return PromptOutput(
      model: json['model'] as String,
      imageUrl: url.toString(),
      aspectRatio: ratio,
      blurHash: _safeBlurHash(json['blur_hash'] as String? ?? ''),
    );
  }
  static String _safeBlurHash(String hash) {
    const alphabet =
        r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~';
    if (hash.isEmpty || hash.split('').any((c) => !alphabet.contains(c))) {
      return '';
    }
    final flag = alphabet.indexOf(hash[0]);
    final length = 4 + 2 * ((flag % 9) + 1) * ((flag ~/ 9) + 1);
    return flag <= 80 && hash.length == length ? hash : '';
  }

  Map<String, dynamic> toJson() => {
    'model': model,
    'image_url': imageUrl,
    'aspect_ratio': aspectRatio,
    'blur_hash': blurHash,
  };
}

// Ignore delivery transforms when comparing the same source photograph.
List<PromptItem> uniquePrompts(Iterable<PromptItem> items) {
  final ids = <String>{}, prompts = <String>{}, images = <String>{};
  final result = <PromptItem>[];
  for (final item in items) {
    final text = item.rawPrompt
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final keys = item.outputs.map((o) {
      final url = Uri.parse(o.imageUrl);
      return '${url.origin}${url.path.replaceFirst(RegExp(r'/+$'), '')}';
    }).toList();
    if (ids.contains(item.id) ||
        (text.isNotEmpty && prompts.contains(text)) ||
        keys.toSet().length != keys.length ||
        keys.any(images.contains)) {
      continue;
    }
    ids.add(item.id);
    if (text.isNotEmpty) prompts.add(text);
    images.addAll(keys);
    result.add(item);
  }
  return result;
}

class PromptItem {
  const PromptItem({
    required this.id,
    required this.title,
    required this.rawPrompt,
    required this.category,
    required this.outputs,
    required this.variables,
    this.isProOnly = false,
    this.likesCount = 0,
    this.tags = const [],
    this.attribution = '',
    this.verified = false,
  });
  final String id;
  final String title;
  final String rawPrompt;
  final String category;
  final List<PromptOutput> outputs;
  final List<PromptVariable> variables;
  final bool isProOnly;
  final int likesCount;
  final List<String> tags;
  final String attribution;
  final bool verified;

  factory PromptItem.fromJson(Map<String, dynamic> json) {
    final outputs = (json['outputs'] as List)
        .map((e) => PromptOutput.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final id = json['id'] as String;
    if (id.isEmpty ||
        (outputs.isEmpty && !RegExp(r'^drop_[0-9]{8}_[1-3]$').hasMatch(id))) {
      throw const FormatException('Invalid prompt');
    }
    return PromptItem(
      id: id,
      title: json['title'] as String,
      rawPrompt: json['raw_prompt'] as String? ?? '',
      category: json['category'] as String,
      outputs: outputs,
      variables: (json['variables'] as List? ?? [])
          .map(
            (e) => PromptVariable.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      isProOnly: json['is_pro_only'] as bool? ?? false,
      likesCount: json['likes_count'] as int? ?? 0,
      tags: (json['tags'] as List? ?? []).cast<String>(),
      attribution: json['attribution'] as String? ?? '',
      verified: json['verified'] as bool? ?? false,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'raw_prompt': rawPrompt,
    'category': category,
    'outputs': outputs.map((e) => e.toJson()).toList(),
    'variables': variables.map((e) => e.toJson()).toList(),
    'is_pro_only': isProOnly,
    'likes_count': likesCount,
    'tags': tags,
    'attribution': attribution,
    'verified': verified,
  };
}

const categories = <String, String>{
  'all': 'Trending & featured',
  'fashion': 'Fashion',
  'men': 'Men',
  'women': 'Women',
  'product_ads': 'Product ads',
  'thumbnails': 'Thumbnails',
  'ui_design': 'UI / Web',
  'typography': 'Typography',
  '3d_icons': '3D icons',
  'logos': 'Brand logos',
  'portraits': 'Portraits',
};
const modelNames = <String, String>{
  'all': 'All models',
  'chatgpt_4o': 'ChatGPT',
  'gemini_nano_banana': 'Gemini',
  'midjourney': 'Midjourney',
  'flux': 'Flux',
};
