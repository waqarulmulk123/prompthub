import 'package:material_ui/material_ui.dart';

import '../../features/creator/creator_screens.dart';
import '../../features/creator/daily_drop_widgets.dart';
import '../../features/community/community_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/feed/presentation/feed_screen.dart';
import '../../features/collections/collections_screen.dart';
import '../../features/auth/profile_screen.dart';
import '../../features/prompt_studio/presentation/prompt_studio_screen.dart';
import '../../features/reverse_prompt/reverse_prompt_screen.dart';
import '../theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    redirect: (_, state) {
      if (state.uri.scheme == 'promptvault') {
        if (state.uri.host == 'login-callback') return '/profile';
        if (state.uri.host == 'prompt') return '/prompt${state.uri.path}';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const FeedScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inspire',
                builder: (_, _) => const QuickInspireScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/collections',
                builder: (_, _) => const CollectionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/prompt/:id',
        builder: (_, state) =>
            PromptStudioScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/brand', builder: (_, _) => const BrandDnaScreen()),
      GoRoute(path: '/booster', builder: (_, _) => const PromptBoosterScreen()),
      GoRoute(
        path: '/daily-vault',
        builder: (_, _) => const DailyVaultScreen(),
      ),
      GoRoute(
        path: '/remixes/:id',
        builder: (_, state) =>
            CommunityScreen(promptId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/reverse', builder: (_, _) => const ReversePromptScreen()),
      GoRoute(path: '/login-callback', redirect: (_, _) => '/profile'),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Explore prompts'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      void navigate(int index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
      return Scaffold(
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                backgroundColor: AppTheme.background,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: navigate,
                extended: constraints.maxWidth >= 1200,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: Text('Discover'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bolt_outlined),
                    selectedIcon: Icon(Icons.bolt),
                    label: Text('Quick Inspire'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bookmarks_outlined),
                    selectedIcon: Icon(Icons.bookmarks_rounded),
                    label: Text('Collections'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Your account'),
                  ),
                ],
              ),
            Expanded(child: shell),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: navigate,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    label: 'Discover',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bolt_outlined),
                    label: 'Quick Inspire',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bookmarks_outlined),
                    label: 'Collections',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Account',
                  ),
                ],
              ),
      );
    },
  );
}
