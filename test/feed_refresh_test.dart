import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompthub/core/database/app_database.dart';
import 'package:prompthub/features/feed/data/prompt_repository.dart';
import 'package:prompthub/features/feed/domain/prompt_item.dart';
import 'package:prompthub/features/feed/presentation/feed_notifier.dart';

class SlowCatalog extends PromptRemoteDatasource {
  SlowCatalog() : super(Dio());
  final response = Completer<List<PromptItem>>();
  @override
  Future<List<PromptItem>> fetch({CancelToken? cancelToken}) => response.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'initial background sync preserves pages the user already loaded',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final remote = SlowCatalog();
      final repository = PromptRepository(database, remote);
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repository)],
      );
      final subscription = container.listen(feedNotifierProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await database.close();
      });
      await container.read(feedNotifierProvider.future);
      final feed = container.read(feedNotifierProvider.notifier);
      final sync = feed.refresh(preservePages: true);
      await feed.loadMore();
      expect(
        container.read(feedNotifierProvider).asData!.value.items,
        hasLength(20),
      );
      remote.response.complete(await remote.bundled());
      await sync;
      expect(
        container.read(feedNotifierProvider).asData!.value.items,
        hasLength(20),
      );
      await feed.loadMore();
      expect(
        container.read(feedNotifierProvider).asData!.value.items,
        hasLength(30),
      );
    },
  );
}
