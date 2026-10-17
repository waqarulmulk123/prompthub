import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prompt_repository.dart';
import '../domain/prompt_item.dart';

class FeedState {
  const FeedState({
    required this.items,
    this.query = '',
    this.category = 'all',
    this.model = 'all',
    this.hasMore = true,
    this.loadingMore = false,
    this.syncError,
  });
  final List<PromptItem> items;
  final String query;
  final String category;
  final String model;
  final bool hasMore;
  final bool loadingMore;
  final String? syncError;
}

final feedNotifierProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

class FeedNotifier extends AsyncNotifier<FeedState> {
  CancelToken? _cancel;
  int _generation = 0;

  @override
  Future<FeedState> build() async {
    ref.onDispose(() => _cancel?.cancel());
    final items = await ref.watch(repositoryProvider).search();
    return FeedState(items: items, hasMore: items.length == discoveryPageSize);
  }

  Future<void> filter({String? query, String? category, String? model}) async {
    final previous = state.asData?.value ?? const FeedState(items: []);
    final generation = ++_generation;
    _cancel?.cancel();
    final q = query ?? previous.query;
    final c = category ?? previous.category;
    final m = model ?? previous.model;
    try {
      final items = await ref
          .read(repositoryProvider)
          .search(query: q, category: c, model: m);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        FeedState(
          items: items,
          query: q,
          category: c,
          model: m,
          hasMore: items.length == discoveryPageSize,
        ),
      );
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> refresh() async {
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    try {
      await ref.read(repositoryProvider).sync(cancelToken: token);
      if (ref.mounted && !token.isCancelled) await filter();
    } catch (_) {
      if (!ref.mounted || token.isCancelled) return;
      final value = state.asData?.value;
      if (value != null) {
        state = AsyncData(
          FeedState(
            items: value.items,
            query: value.query,
            category: value.category,
            model: value.model,
            hasMore: value.hasMore,
            syncError:
                'Could not refresh. Your saved catalog is still available.',
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    final value = state.asData?.value;
    if (value == null || !value.hasMore || value.loadingMore) return;
    final generation = _generation;
    state = AsyncData(
      FeedState(
        items: value.items,
        query: value.query,
        category: value.category,
        model: value.model,
        loadingMore: true,
      ),
    );
    try {
      final next = await ref
          .read(repositoryProvider)
          .search(
            query: value.query,
            category: value.category,
            model: value.model,
            offset: value.items.length,
          );
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        FeedState(
          items: [...value.items, ...next],
          query: value.query,
          category: value.category,
          model: value.model,
          hasMore: next.length == discoveryPageSize,
        ),
      );
    } catch (_) {
      if (ref.mounted && generation == _generation) state = AsyncData(value);
    }
  }
}
