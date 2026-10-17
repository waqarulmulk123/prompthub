import 'dart:async';

import '../../notifications/push_service.dart'; // onesignal:managed v1

import '../../creator/daily_drop_widgets.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/prompt_item.dart';
import 'feed_notifier.dart';
import 'prompt_image.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _failedImages = <String>{};
  Timer? _debounce;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(feedNotifierProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedNotifierProvider);
    final data = feed.asData?.value;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'PromptVault',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        // onesignal:managed v1 — permission only after a deliberate tap.
                        if (PushService.available)
                          IconButton(
                            tooltip: 'Enable daily drop reminders',
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () async {
                              try {
                                final allowed =
                                    await PushService.requestPermission();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        allowed
                                            ? 'Daily drop notifications enabled.'
                                            : 'Notifications are disabled in your browser or device settings.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Push is currently unavailable.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        IconButton(
                          tooltip: 'Turn an image into a prompt',
                          onPressed: () => context.push('/reverse'),
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const DailyDropBanner(),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.bolt),
                          label: const Text('Quick Inspire'),
                          onPressed: () => context.push('/inspire'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.auto_fix_high),
                          label: const Text('Prompt Booster'),
                          onPressed: () => context.push('/booster'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.palette_outlined),
                          label: const Text('My Brand DNA'),
                          onPressed: () => context.push('/brand'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Your next great idea\nstarts with a prompt.',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            height: 1.12,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Discover a look. Make it yours. Create something new.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Search a style, subject, or idea',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _debounce?.cancel();
                              _search.clear();
                              ref
                                  .read(feedNotifierProvider.notifier)
                                  .filter(query: '');
                            },
                          ),
                        ),
                        onChanged: (query) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () => ref
                                .read(feedNotifierProvider.notifier)
                                .filter(query: query),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final entry = categories.entries.elementAt(i);
                          return ChoiceChip(
                            label: Text(entry.value),
                            selected: (data?.category ?? 'all') == entry.key,
                            onSelected: (_) => ref
                                .read(feedNotifierProvider.notifier)
                                .filter(category: entry.key),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data?.query.isNotEmpty == true
                                ? 'Search results'
                                : categories[data?.category ?? 'all'] ??
                                      'Trending & featured',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DropdownButton<String>(
                          value: data?.model ?? 'all',
                          underline: const SizedBox.shrink(),
                          items: modelNames.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (model) => ref
                              .read(feedNotifierProvider.notifier)
                              .filter(model: model),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Popular first, then our fashion edit. Reference photos are illustrative.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                    if (data?.syncError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          data!.syncError!,
                          style: const TextStyle(color: Colors.amber),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            feed.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text('The catalog could not be loaded.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(feedNotifierProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (value) => value.items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: Text(
                            'No prompts match. Try another style or category.',
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final count = (constraints.crossAxisExtent / 240)
                              .floor()
                              .clamp(2, 6);
                          final visible = value.items
                              .where((p) => !_failedImages.contains(p.id))
                              .toList();
                          return SliverMasonryGrid.count(
                            crossAxisCount: count,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 16,
                            childCount: visible.length,
                            itemBuilder: (context, i) => _PromptCard(
                              key: ValueKey(visible[i].id),
                              prompt: visible[i],
                              onImageError: () {
                                if (mounted &&
                                    !_failedImages.contains(visible[i].id)) {
                                  setState(
                                    () => _failedImages.add(visible[i].id),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: data?.hasMore == true
                      ? OutlinedButton(
                          onPressed: data!.loadingMore
                              ? null
                              : () => ref
                                    .read(feedNotifierProvider.notifier)
                                    .loadMore(),
                          child: Text(
                            data.loadingMore ? 'Loading…' : 'Load 10 more',
                          ),
                        )
                      : const Text(
                          'A starting point for your imagination.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    super.key,
    required this.prompt,
    required this.onImageError,
  });
  final VoidCallback onImageError;
  final PromptItem prompt;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Customize ${prompt.title}',
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/prompt/${prompt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                PromptImage(
                  output: prompt.outputs.first,
                  onError: onImageError,
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        modelNames[prompt.outputs.first.model] ??
                            prompt.outputs.first.model,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                if (prompt.isProOnly)
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: Chip(label: Text('Pro')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            prompt.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            categories[prompt.category] ?? prompt.category,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
