import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/dio_client.dart';
import '../domain/prompt_item.dart';
import '../../auth/auth_service.dart';

class PromptRemoteDatasource {
  PromptRemoteDatasource(this.dio);
  final Dio dio;
  Future<List<PromptItem>> fetch({CancelToken? cancelToken}) async {
    if (AppConfig.catalogUrl.isEmpty) return bundled();
    final base = Uri.parse(
      '${AppConfig.catalogUrl.replaceFirst(RegExp(r'/+$'), '')}/',
    );
    if (base.scheme != 'https') {
      throw const FormatException('Catalog must use HTTPS');
    }
    final manifest = await dio.getUri(
      base.resolve('manifest.json'),
      cancelToken: cancelToken,
    );
    final pages = (manifest.data['pages'] as List).cast<String>();
    if (pages.isEmpty ||
        pages.length > 100 ||
        pages.any(
          (p) => !RegExp(r'^feed_page_[1-9][0-9]*\.json$').hasMatch(p),
        )) {
      throw const FormatException('Invalid catalog manifest');
    }
    final items = <PromptItem>[];
    for (var i = 0; i < pages.length; i += 4) {
      final batch = pages.skip(i).take(4);
      final shards = await Future.wait(
        batch.map((p) => dio.getUri(base.resolve(p), cancelToken: cancelToken)),
      );
      for (final shard in shards) {
        items.addAll(decode(shard.data));
      }
    }
    return items;
  }

  Future<List<PromptItem>> bundled() async => decode(
    jsonDecode(await rootBundle.loadString('assets/catalog/feed_page_1.json')),
  );
  List<PromptItem> decode(dynamic data) {
    final list = data is Map ? data['prompts'] as List : data as List;
    final items = <PromptItem>[];
    for (final record in list) {
      try {
        items.add(
          PromptItem.fromJson(Map<String, dynamic>.from(record as Map)),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return items;
  }
}

class PromptRepository {
  PromptRepository(this.database, this.remote);
  final AppDatabase database;
  final PromptRemoteDatasource remote;
  Future<void>? _initialization;
  Future<void> initialize() async {
    try {
      await (_initialization ??= _seed());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _seed() async {
    if ((await database.search(limit: 1)).isEmpty) {
      await database.cachePrompts(await remote.bundled());
    }
  }

  Future<void> sync({CancelToken? cancelToken}) async {
    await initialize();
    final prompts = await remote.fetch(cancelToken: cancelToken);
    await database.cachePrompts(prompts, replace: true);
  }

  Future<List<PromptItem>> search({
    String query = '',
    String category = 'all',
    String model = 'all',
    int offset = 0,
  }) async {
    await initialize();
    return database.search(
      query: query,
      category: category,
      model: model,
      offset: offset,
    );
  }

  Future<PromptItem?> find(String id) async {
    await initialize();
    return database.findPrompt(id);
  }
}

final repositoryProvider = Provider<PromptRepository>(
  (ref) => PromptRepository(
    ref.watch(databaseProvider),
    PromptRemoteDatasource(ref.watch(dioProvider)),
  ),
);
final promptProvider = FutureProvider.family<PromptItem?, String>((
  ref,
  id,
) async {
  if (id.startsWith('drop_')) {
    ref.watch(authProvider);
    final client = ref.watch(supabaseProvider);
    if (client == null) return null;
    final row = await client.rpc('drop_prompt', params: {'p_id': id});
    return row == null
        ? null
        : PromptItem.fromJson(Map<String, dynamic>.from(row as Map));
  }
  return ref.watch(repositoryProvider).find(id);
});
