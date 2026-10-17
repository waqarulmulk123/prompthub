import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../feed/data/prompt_repository.dart';
import 'collections_repository.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});
  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsState();
}

class _CollectionsState extends ConsumerState<CollectionsScreen> {
  String? _collectionId;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).asData?.value;
    final activeBoard =
        ref
                .watch(boardsProvider)
                .asData
                ?.value
                .any((b) => b['id'] == _collectionId) ==
            true
        ? _collectionId
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your collections'),
        actions: [
          IconButton(
            tooltip: 'Streak vault',
            onPressed: () => context.push('/daily-vault'),
            icon: const Icon(Icons.local_fire_department_outlined),
          ),
          if (user != null)
            IconButton(
              tooltip: 'New private board',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: () async {
                final controller = TextEditingController();
                final route = DialogRoute<String>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('New private board'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Board name',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, controller.text),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );
                final name = await Navigator.of(context).push(route);
                await route.completed;
                controller.dispose();
                if (name == null) return;
                try {
                  await ref
                      .read(collectionsRepositoryProvider)!
                      .createBoard(name);
                  ref.invalidate(boardsProvider);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not create the board. Try again.'),
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: user == null
          ? Center(
              child: FilledButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Sign in to save your ideas'),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(boardsProvider);
                ref.invalidate(bookmarksProvider);
                await ref.read(bookmarksProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ref
                      .watch(boardsProvider)
                      .when(
                        data: (boards) => Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              label: const Text('All saved'),
                              selected: activeBoard == null,
                              onSelected: (_) =>
                                  setState(() => _collectionId = null),
                            ),
                            ...boards.map(
                              (b) => ChoiceChip(
                                avatar: const Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                ),
                                label: Text(b['name'] as String),
                                selected: activeBoard == b['id'],
                                onSelected: (_) => setState(
                                  () => _collectionId = b['id'] as String,
                                ),
                              ),
                            ),
                          ],
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) =>
                            const Text('Boards are temporarily unavailable.'),
                      ),
                  const SizedBox(height: 24),
                  ref
                      .watch(bookmarksProvider)
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const Text(
                          'Could not sync your saved prompts. Pull down to retry.',
                        ),
                        data: (items) => items.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                  'Keep the ideas you love. Open a prompt and save it here.',
                                ),
                              )
                            : Column(
                                children: items
                                    .where(
                                      (item) =>
                                          activeBoard == null ||
                                          item.collectionId == activeBoard,
                                    )
                                    .map(
                                      (item) => FutureBuilder(
                                        future: ref
                                            .read(repositoryProvider)
                                            .find(item.promptId),
                                        builder: (context, snapshot) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.bookmark),
                                          title: Text(
                                            snapshot.data?.title ??
                                                item.promptId,
                                          ),
                                          subtitle: const Text('Saved prompt'),
                                          onTap: () => context.push(
                                            '/prompt/${item.promptId}',
                                          ),
                                          trailing: IconButton(
                                            tooltip: 'Remove bookmark',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () async {
                                              try {
                                                await ref
                                                    .read(
                                                      collectionsRepositoryProvider,
                                                    )!
                                                    .remove(item.promptId);
                                                ref.invalidate(
                                                  bookmarksProvider,
                                                );
                                              } catch (_) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Could not remove the bookmark.',
                                                          ),
                                                        ),
                                                      );
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                ],
              ),
            ),
    );
  }
}
