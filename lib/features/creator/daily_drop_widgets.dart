import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import 'creator_service.dart';
import '../subscription/pro_paywall_screen.dart';

class DailyDropBanner extends ConsumerStatefulWidget {
  const DailyDropBanner({super.key});
  @override
  ConsumerState<DailyDropBanner> createState() => _DailyDropBannerState();
}

class _DailyDropBannerState extends ConsumerState<DailyDropBanner>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
  String? _expiredDay;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(supabaseProvider) == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final drop = ref.read(dailyDropProvider).asData?.value;
      if (drop != null &&
          drop.remaining.isNegative &&
          _expiredDay != drop.day) {
        _expiredDay = drop.day;
        ref.invalidate(dailyDropProvider);
      }
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(dailyDropProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(dailyDropProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (drop) {
          if (drop == null) return const SizedBox.shrink();
          final seconds = drop.remaining.inSeconds.clamp(0, 100000);
          final timer =
              '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Daily Drop",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('🔥 ${drop.streak} days · $timer left'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Three original prompts. Claim today, keep forever. Refreshes at 9am New York time.',
                  ),
                  for (final prompt in drop.prompts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFFFC66D),
                      ),
                      title: Text(prompt.title),
                      trailing: const Icon(Icons.arrow_outward),
                      onTap: () => context.push('/prompt/${prompt.id}'),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: Text(
                          drop.claimed
                              ? 'Claimed to your vault'
                              : 'Claim all 3 to my vault',
                        ),
                        onPressed: _busy || drop.claimed || seconds == 0
                            ? null
                            : () async {
                                if (ref.read(authProvider).asData?.value ==
                                    null) {
                                  context.go('/profile');
                                  return;
                                }
                                setState(() => _busy = true);
                                try {
                                  final reward = await ref
                                      .read(creatorServiceProvider)!
                                      .claim(drop.day);
                                  ref.invalidate(dailyDropProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          reward > 0
                                              ? 'Seven-day streak! Three bonus image scans unlocked.'
                                              : 'All three prompts are yours permanently.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not claim. Check your connection or refresh the drop.',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                      ),
                      TextButton(
                        onPressed: () => context.push('/daily-vault'),
                        child: const Text('Streak vault & Pro archive'),
                      ),
                      Text(
                        '${drop.credits} bonus scans · Every 7-day streak earns 3 more',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class DailyVaultScreen extends ConsumerStatefulWidget {
  const DailyVaultScreen({super.key});
  @override
  ConsumerState<DailyVaultScreen> createState() => _DailyVaultState();
}

class _DailyVaultState extends ConsumerState<DailyVaultScreen> {
  bool _archive = false, _busy = false, _more = true;
  List<Map<String, dynamic>> _days = [];
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(true));
  }

  Future<void> _load(bool reset) async {
    if (_busy && !reset) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) _days = [];
    });
    try {
      final service = ref.read(creatorServiceProvider);
      if (service == null ||
          ref.read(supabaseProvider)?.auth.currentUser == null) {
        throw StateError('Sign in');
      }
      final rows = await service.vault(_archive, _days.length);
      if (mounted && generation == _generation) {
        setState(() {
          _days = [..._days, ...rows];
          _more = rows.length == 10;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Sign in and connect to load your drop vault.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Streak vault')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Claimed daily drops remain yours. Unclaimed past drops require Pro.',
            ),
            SwitchListTile(
              title: const Text('Browse Pro archive'),
              value: _archive,
              onChanged: (value) {
                setState(() => _archive = value);
                _load(true);
              },
            ),
            if (_error != null) Text(_error!),
            if (!_busy && _error == null && _days.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No drops here yet. Claim today’s collection to start your streak.',
                ),
              ),
            for (final day in _days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  day['day'] as String,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final item in day['prompts'] as List)
                ListTile(
                  leading: Icon(
                    item['is_pro_only'] == true
                        ? Icons.lock_outline
                        : Icons.bookmark_added,
                  ),
                  title: Text(item['title'] as String),
                  subtitle: Text(
                    day['claimed'] == true ? 'Yours forever' : 'Pro archive',
                  ),
                  onTap: () {
                    if (item['is_pro_only'] == true) {
                      showProPaywall(context);
                    } else {
                      context.push('/prompt/${item['id']}');
                    }
                  },
                ),
            ],
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (!_busy)
              TextButton(
                onPressed: () => _load(_error != null || !_more),
                child: Text(
                  _error != null
                      ? 'Retry'
                      : _more
                      ? 'Load more drops'
                      : 'Refresh',
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
