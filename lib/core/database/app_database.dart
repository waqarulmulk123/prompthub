import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/domain/prompt_item.dart';

part 'app_database.g.dart';

class CachedPromptsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get rawPrompt => text()();
  TextColumn get category => text()();
  TextColumn get payload => text()();
  IntColumn get rank => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class LocalBookmarks extends Table {
  TextColumn get userId => text()();
  TextColumn get promptId => text()();
  TextColumn get variables => text().withDefault(const Constant('{}'))();
  TextColumn get collectionId => text().nullable()();
  @override
  Set<Column> get primaryKey => {userId, promptId};
}

@DriftDatabase(tables: [CachedPromptsTable, LocalBookmarks])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'promptvault',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          ),
        ),
      );
  AppDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Rebuild only the public catalog; private bookmarks stay intact.
        await delete(cachedPromptsTable).go();
        await customStatement('DELETE FROM prompt_search');
      }
    },
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE VIRTUAL TABLE prompt_search USING fts5(id UNINDEXED, title, body, category)',
      );
      await customStatement(
        'CREATE TABLE local_usage(day TEXT PRIMARY KEY, customizations INTEGER NOT NULL DEFAULT 0)',
      );
    },
  );

  Future<void> cachePrompts(List<PromptItem> items, {bool replace = false}) =>
      transaction(() async {
        items = uniquePrompts(items);
        if (replace) {
          await delete(cachedPromptsTable).go();
          await customStatement('DELETE FROM prompt_search');
        }
        for (var i = 0; i < items.length; i++) {
          final p = items[i];
          // Paid text never enters a public cache, even if a CDN shard is misconfigured.
          final json = p.toJson();
          if (p.isProOnly) {
            json['raw_prompt'] = '';
            json['variables'] = [];
          }
          await into(cachedPromptsTable).insertOnConflictUpdate(
            CachedPromptsTableCompanion.insert(
              id: p.id,
              title: p.title,
              rawPrompt: p.isProOnly ? '' : p.rawPrompt,
              category: p.category,
              payload: jsonEncode(json),
              rank: i,
            ),
          );
          await customStatement('DELETE FROM prompt_search WHERE id = ?', [
            p.id,
          ]);
          await customStatement(
            'INSERT INTO prompt_search(id, title, body, category) VALUES (?, ?, ?, ?)',
            [
              p.id,
              p.title,
              p.isProOnly ? '' : p.rawPrompt,
              '${p.category} ${p.tags.join(' ')}',
            ],
          );
        }
      });

  Future<List<PromptItem>> search({
    String query = '',
    String category = 'all',
    String model = 'all',
    int limit = discoveryPageSize,
    int offset = 0,
  }) async {
    final terms = RegExp(
      r'[\p{L}\p{N}_]+',
      unicode: true,
    ).allMatches(query).map((m) => '"${m[0]}"*').join(' AND ');
    final conditions = <String>[];
    final parameters = <Variable>[];
    if (terms.isNotEmpty) {
      conditions.add(
        'id IN (SELECT id FROM prompt_search WHERE prompt_search MATCH ?)',
      );
      parameters.add(Variable.withString(terms));
    }
    if (category != 'all') {
      conditions.add('category = ?');
      parameters.add(Variable.withString(category));
    }
    if (model != 'all') {
      conditions.add(
        "EXISTS (SELECT 1 FROM json_each(payload, '\$.outputs') WHERE json_extract(value, '\$.model') = ?)",
      );
      parameters.add(Variable.withString(model));
    }
    parameters.addAll([
      Variable.withInt(limit.clamp(1, 100)),
      Variable.withInt(offset < 0 ? 0 : offset),
    ]);
    final rows = await customSelect(
      '''SELECT payload FROM cached_prompts_table ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'} ORDER BY CAST(COALESCE(json_extract(payload, '\$.likes_count'), 0) AS INTEGER) DESC, CAST(COALESCE(json_extract(payload, '\$.featured'), 0) AS INTEGER) DESC, CASE category WHEN 'fashion' THEN 0 WHEN 'men' THEN 1 WHEN 'women' THEN 2 ELSE 3 END, rank, id LIMIT ? OFFSET ?''',
      variables: parameters,
    ).get();
    return rows
        .map(
          (r) => PromptItem.fromJson(
            jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> consumeGuestCustomization() => transaction(() async {
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    await customStatement(
      'INSERT INTO local_usage(day,customizations) VALUES (?,0) ON CONFLICT DO NOTHING',
      [day],
    );
    final changed = await customUpdate(
      'UPDATE local_usage SET customizations=customizations+1 WHERE day=? AND customizations<3',
      variables: [Variable.withString(day)],
    );
    if (changed != 1) throw StateError('Daily customization allowance reached');
    await customStatement('DELETE FROM local_usage WHERE day < ?', [day]);
  });

  Future<PromptItem?> findPrompt(String id) async {
    final row = await (select(
      cachedPromptsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null
        ? null
        : PromptItem.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
