import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/app_database.dart';
import '../auth/auth_service.dart';

class CollectionsRepository {
  CollectionsRepository(this.client, this.db, this.userId);
  final SupabaseClient client;
  final AppDatabase db;
  final String userId;
  Future<List<Map<String, dynamic>>> boards() async => client
      .from('collections')
      .select()
      .eq('user_id', userId)
      .order('created_at');
  Future<void> createBoard(String name) async {
    final value = name.trim();
    if (value.isEmpty || value.length > 80) {
      throw const FormatException('Board name must be 1–80 characters.');
    }
    await client.from('collections').insert({'user_id': userId, 'name': value});
  }

  Future<List<LocalBookmark>> bookmarks() async {
    try {
      final rows = await client
          .from('saved_prompts')
          .select('prompt_id, custom_variables, collection_id')
          .eq('user_id', userId);
      await db.transaction(() async {
        await (db.delete(
          db.localBookmarks,
        )..where((t) => t.userId.equals(userId))).go();
        for (final row in rows) {
          await db
              .into(db.localBookmarks)
              .insert(
                LocalBookmarksCompanion.insert(
                  userId: userId,
                  promptId: row['prompt_id'] as String,
                  variables: Value(jsonEncode(row['custom_variables'])),
                  collectionId: Value(row['collection_id'] as String?),
                ),
              );
        }
      });
    } catch (_) {
      final cached = await (db.select(
        db.localBookmarks,
      )..where((t) => t.userId.equals(userId))).get();
      if (cached.isEmpty) rethrow;
    }
    return (db.select(
      db.localBookmarks,
    )..where((t) => t.userId.equals(userId))).get();
  }

  Future<void> save(
    String promptId,
    Map<String, String> variables, {
    String? collectionId,
  }) async {
    await client.rpc(
      'save_prompt',
      params: {
        'p_prompt_id': promptId,
        'p_variables': variables,
        'p_collection_id': collectionId,
      },
    );
    await db
        .into(db.localBookmarks)
        .insertOnConflictUpdate(
          LocalBookmarksCompanion.insert(
            userId: userId,
            promptId: promptId,
            variables: Value(jsonEncode(variables)),
            collectionId: Value(collectionId),
          ),
        );
  }

  Future<void> remove(String promptId) async {
    await client
        .from('saved_prompts')
        .delete()
        .eq('user_id', userId)
        .eq('prompt_id', promptId);
    await (db.delete(db.localBookmarks)
          ..where((t) => t.userId.equals(userId) & t.promptId.equals(promptId)))
        .go();
  }
}

final collectionsRepositoryProvider = Provider<CollectionsRepository?>((ref) {
  final client = ref.watch(supabaseProvider);
  final user = ref.watch(authProvider).asData?.value;
  return client == null || user == null
      ? null
      : CollectionsRepository(client, ref.watch(databaseProvider), user.id);
});
final bookmarksProvider = FutureProvider<List<LocalBookmark>>(
  (ref) async => ref.watch(collectionsRepositoryProvider)?.bookmarks() ?? [],
);
final boardsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async => ref.watch(collectionsRepositoryProvider)?.boards() ?? [],
);
