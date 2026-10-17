import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../collections/collections_repository.dart';
import '../feed/data/prompt_repository.dart';
import '../feed/domain/prompt_item.dart';
import '../feed/presentation/prompt_image.dart';
import '../prompt_studio/data/ai_launcher_service.dart';
import 'creator_service.dart';
import '../../core/utils/prompt_parser.dart';

class BrandDnaScreen extends ConsumerStatefulWidget {
  const BrandDnaScreen({super.key});
  @override
  ConsumerState<BrandDnaScreen> createState() => _BrandDnaState();
}

class _BrandDnaState extends ConsumerState<BrandDnaScreen> {
  final _product = TextEditingController(),
      _colors = TextEditingController(),
      _vibe = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final brand = await ref.read(brandDnaProvider.future);
      if (brand != null && mounted) {
        _product.text = brand.product;
        _colors.text = brand.colors;
        _vibe.text = brand.vibe;
      }
    } catch (_) {
      _message = 'Could not load your brand. Retry when connected.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _product.dispose();
    _colors.dispose();
    _vibe.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(creatorServiceProvider);
      if (service == null) throw StateError('Unavailable');
      await service.saveBrand(
        BrandDna(_product.text.trim(), _colors.text.trim(), _vibe.text.trim()),
      );
      ref.invalidate(brandDnaProvider);
      if (mounted) {
        setState(
          () => _message = 'Brand saved. Apply it from any prompt studio.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _message = 'Sign in with Pro and connect to save your Brand DNA.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Brand DNA')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'One brand. Every prompt.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Pro · Your private brand profile syncs with your account. Turn it on in the studio to apply your product, colors and visual direction.',
              ),
              const SizedBox(height: 24),
              for (final entry in [
                (_product, 'Brand name / product', 200),
                (_colors, 'Brand colors', 200),
                (_vibe, 'Visual vibe / camera style', 300),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: entry.$1,
                    maxLength: entry.$3,
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter ${entry.$2.toLowerCase()}'
                        : null,
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_message!),
                ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Working…' : 'Save Brand DNA'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(supabaseProvider)!
                              .from('brand_dna')
                              .delete()
                              .eq(
                                'user_id',
                                ref
                                    .read(supabaseProvider)!
                                    .auth
                                    .currentUser!
                                    .id,
                              );
                          ref.invalidate(brandDnaProvider);
                          _product.clear();
                          _colors.clear();
                          _vibe.clear();
                          if (mounted) {
                            setState(() => _message = 'Brand profile deleted.');
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _message =
                                  'Could not delete. Check your connection.',
                            );
                          }
                        }
                      },
                child: const Text('Delete saved brand profile'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PromptBoosterScreen extends ConsumerStatefulWidget {
  const PromptBoosterScreen({super.key});
  @override
  ConsumerState<PromptBoosterScreen> createState() => _BoosterState();
}

class _BoosterState extends ConsumerState<PromptBoosterScreen> {
  final _idea = TextEditingController();
  String? _result, _error;
  bool _busy = false;
  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  Future<void> _boost() async {
    if (_idea.text.trim().length < 4) {
      setState(
        () => _error = 'Describe your idea in at least four characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(creatorServiceProvider);
      if (service == null) throw StateError('Unavailable');
      final result = await service.boost(_idea.text.trim());
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not boost. Sign in, check your connection, or try again after your daily allowance resets.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Magic Prompt Booster')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'A small idea. A sharper prompt.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Describe your concept. Gemini adds composition, materials and lighting. Five boosts per day on Free; 50 on Pro. Provider costs and availability apply.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idea,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Your idea',
                hintText: 'A coffee shop logo with a botanical feel',
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _boost,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(_busy ? 'Enhancing…' : 'Boost my idea'),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
            if (_result != null) ...[
              const SizedBox(height: 24),
              SelectableText(_result!),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _result!)),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy prompt'),
                  ),
                  for (final target in [
                    TargetAIPlatform.chatGpt,
                    TargetAIPlatform.gemini,
                  ])
                    FilledButton(
                      onPressed: () async {
                        try {
                          await AiLauncherService().launchWithPrompt(
                            target,
                            _result!,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Copy the prompt and open your AI app manually.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Open in ${target == TargetAIPlatform.chatGpt ? 'ChatGPT' : 'Gemini'}',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class QuickInspireScreen extends ConsumerStatefulWidget {
  const QuickInspireScreen({super.key});
  @override
  ConsumerState<QuickInspireScreen> createState() => _QuickState();
}

class _QuickState extends ConsumerState<QuickInspireScreen> {
  final List<PromptItem> _items = [];
  final _failed = <String>{};
  int _index = 0, _offset = 0;
  bool _busy = false, _more = true;
  TargetAIPlatform _target = TargetAIPlatform.chatGpt;
  Offset _drag = Offset.zero;
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await ref.read(repositoryProvider).search(offset: _offset);
      if (mounted) {
        setState(() {
          _items.addAll(next);
          _offset += next.length;
          _more = next.length == discoveryPageSize;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load inspiration.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(String action) async {
    if (_busy || _index >= _items.length) return;
    final item = _items[_index];
    if (action == 'launch' && item.isProOnly) {
      context.push('/prompt/${item.id}');
      return;
    }
    if (action == 'skip') {
      setState(() {
        _index++;
        _drag = Offset.zero;
      });
      if (_index >= _items.length && _more) await _load();
      return;
    }
    setState(() => _busy = true);
    try {
      if (action == 'save') {
        final repo = ref.read(collectionsRepositoryProvider);
        if (repo == null) throw StateError('Sign in to save');
        await repo.save(item.id, {});
        ref.invalidate(bookmarksProvider);
        if (mounted) {
          setState(() {
            _index++;
            _drag = Offset.zero;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved to your vault.')));
        }
      } else {
        await AiLauncherService().launchWithPrompt(
          _target,
          PromptParser.compile(item.rawPrompt, {}),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not complete that action. Sign in to save, or check your plan and connection.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (_index >= _items.length && _more) await _load();
  }

  @override
  Widget build(BuildContext context) {
    while (_index < _items.length && _failed.contains(_items[_index].id)) {
      _index++;
    }
    final item = _index < _items.length ? _items[_index] : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Inspire')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('← Skip · Save → · ↑ Open in your AI app'),
                DropdownButton<TargetAIPlatform>(
                  value: _target,
                  items: const [
                    DropdownMenuItem(
                      value: TargetAIPlatform.chatGpt,
                      child: Text('ChatGPT'),
                    ),
                    DropdownMenuItem(
                      value: TargetAIPlatform.gemini,
                      child: Text('Gemini'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _target = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: item == null
                      ? Center(
                          child: _busy
                              ? const CircularProgressIndicator()
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _error ??
                                          'You’ve explored this collection.',
                                    ),
                                    TextButton(
                                      onPressed: _load,
                                      child: const Text('Load more'),
                                    ),
                                  ],
                                ),
                        )
                      : GestureDetector(
                          onPanUpdate: _busy
                              ? null
                              : (details) =>
                                    setState(() => _drag += details.delta),
                          onPanEnd: _busy
                              ? null
                              : (_) {
                                  final direction = _drag;
                                  setState(() => _drag = Offset.zero);
                                  if (direction.dy < -80 &&
                                      direction.dy.abs() > direction.dx.abs()) {
                                    _act('launch');
                                  } else if (direction.dx.abs() > 80) {
                                    _act(direction.dx > 0 ? 'save' : 'skip');
                                  }
                                },
                          child: Transform.translate(
                            offset: Offset(
                              _drag.dx.clamp(-80, 80),
                              _drag.dy.clamp(-80, 80),
                            ),
                            child: Transform.rotate(
                              angle: (_drag.dx / 1000).clamp(
                                -math.pi / 12,
                                math.pi / 12,
                              ),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    PromptImage(
                                      output: item.outputs.first,
                                      onError: () {
                                        if (mounted) {
                                          setState(() => _failed.add(item.id));
                                          if (_index + 1 >= _items.length &&
                                              _more) {
                                            _load();
                                          }
                                        }
                                      },
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: ColoredBox(
                                        color: Colors.black.withValues(
                                          alpha: .8,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge,
                                              ),
                                              const Text(
                                                'Illustrative reference · Original template',
                                              ),
                                              TextButton(
                                                onPressed: () => context.push(
                                                  '/prompt/${item.id}',
                                                ),
                                                child: const Text(
                                                  'Customize in studio',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _busy || item == null
                          ? null
                          : () => _act('skip'),
                      child: const Text('Skip'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || item == null
                          ? null
                          : () => _act('save'),
                      icon: const Icon(Icons.bookmark_add),
                      label: const Text('Save'),
                    ),
                    OutlinedButton(
                      onPressed: _busy || item == null
                          ? null
                          : () => _act('launch'),
                      child: Text(
                        'Open in ${_target == TargetAIPlatform.chatGpt ? 'ChatGPT' : 'Gemini'}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
