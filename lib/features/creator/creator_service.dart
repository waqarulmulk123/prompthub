import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/prompt_parser.dart';
import '../auth/auth_service.dart';
import '../feed/domain/prompt_item.dart';

class BrandDna {
  const BrandDna(this.product, this.colors, this.vibe);
  final String product, colors, vibe;
  factory BrandDna.fromJson(Map<String, dynamic> row) => BrandDna(
    row['product'] as String,
    row['colors'] as String,
    row['vibe'] as String,
  );
  String apply(String template, Map<String, String> values) {
    final overrides = Map<String, String>.of(values);
    for (final variable in PromptParser.parse(template)) {
      final key = variable.key.toLowerCase();
      if (['product', 'subject', 'brand', 'brand name'].contains(key)) {
        overrides[variable.key] = product;
      }
      if ([
        'palette',
        'colors',
        'colour',
        'color',
        'brand colors',
      ].contains(key)) {
        overrides[variable.key] = colors;
      }
      if ([
        'vibe',
        'mood',
        'lighting',
        'lighting & mood',
        'style',
      ].contains(key)) {
        overrides[variable.key] = vibe;
      }
    }
    return '${PromptParser.compile(template, overrides)}\nBrand direction: $product. Colors: $colors. Visual mood: $vibe.';
  }
}

class DailyDrop {
  DailyDrop(Map<String, dynamic> row)
    : day = row['day'] as String,
      expiresAt = DateTime.parse(row['expires_at'] as String),
      serverTime = DateTime.parse(row['server_time'] as String),
      claimed = row['claimed'] == true,
      streak = row['streak'] as int,
      credits = row['reverse_credits'] as int,
      prompts = (row['prompts'] as List)
          .map((p) => PromptItem.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
  final String day;
  final DateTime expiresAt, serverTime;
  final bool claimed;
  final int streak, credits;
  final List<PromptItem> prompts;
  final clock = Stopwatch()..start();
  Duration get remaining => expiresAt.difference(serverTime.add(clock.elapsed));
}

class CreatorService {
  CreatorService(this.client);
  final SupabaseClient client;
  Future<DailyDrop?> daily() async {
    final result = await client.rpc('daily_drop');
    return result == null
        ? null
        : DailyDrop(Map<String, dynamic>.from(result as Map));
  }

  Future<int> claim(String day) async {
    final result = await client.rpc('claim_drop', params: {'p_day': day});
    return (result as Map)['reward_scans'] as int? ?? 0;
  }

  Future<List<Map<String, dynamic>>> vault(bool archive, int offset) async =>
      (await client.rpc(
        'drop_vault',
        params: {'p_archive': archive, 'p_offset': offset},
      ) as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  Future<BrandDna?> brand() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('brand_dna')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return row == null ? null : BrandDna.fromJson(row);
  }

  Future<void> saveBrand(BrandDna brand) => client.rpc(
    'save_brand',
    params: {
      'p_product': brand.product,
      'p_colors': brand.colors,
      'p_vibe': brand.vibe,
    },
  );
  Future<String> boost(String idea) async {
    final result = await client.functions.invoke(
      'boost-prompt',
      body: {'idea': idea},
    );
    return (result.data as Map)['prompt'] as String;
  }
}

final creatorServiceProvider = Provider<CreatorService?>((ref) {
  final client = ref.watch(supabaseProvider);
  return client == null ? null : CreatorService(client);
});
final dailyDropProvider = FutureProvider<DailyDrop?>((ref) {
  ref.watch(authProvider);
  return ref.watch(creatorServiceProvider)?.daily();
});
final brandDnaProvider = FutureProvider<BrandDna?>((ref) {
  ref.watch(authProvider);
  return ref.watch(creatorServiceProvider)?.brand();
});
