import 'dart:convert';

import 'package:go_router/go_router.dart';

import '../../creator/creator_service.dart';

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/prompt_parser.dart';
import '../../../core/database/app_database.dart';
import '../../auth/auth_service.dart';
import '../../collections/collections_repository.dart';
import '../../feed/data/prompt_repository.dart';
import '../../feed/domain/prompt_item.dart';
import '../../feed/presentation/prompt_image.dart';
import '../../subscription/pro_paywall_screen.dart';
import '../../subscription/subscription_service.dart';
import '../data/ai_launcher_service.dart';
import 'studio_notifier.dart';

class PromptStudioScreen extends ConsumerStatefulWidget {
  const PromptStudioScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PromptStudioScreen> createState() => _PromptStudioState();
}

class _PromptStudioState extends ConsumerState<PromptStudioScreen> {
  bool _brandEnabled = false;
  int _output = 0;
  bool _busy = false;
  final _shareKey = GlobalKey();
  String? _privatePrompt;
  List<PromptVariable>? _privateVariables;
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _unlock(PromptItem prompt) async {
    if (!(ref.read(entitlementProvider).asData?.value ?? false)) {
      await showProPaywall(context);
      return;
    }
    try {
      final result = await ref
          .read(supabaseProvider)!
          .rpc('get_premium_prompt', params: {'p_prompt_id': prompt.id});
      final row = Map<String, dynamic>.from(result as Map);
      if (mounted) {
        setState(() {
          _privatePrompt = row['raw_prompt'] as String;
          _privateVariables = (row['variables'] as List)
              .map(
                (v) => PromptVariable.fromJson(
                  Map<String, dynamic>.from(v as Map),
                ),
              )
              .toList();
        });
      }
    } catch (_) {
      _message('Could not unlock this prompt. Please try again.');
    }
  }

  Future<void> _edit(PromptVariable variable, String current) async {
    final controller = TextEditingController(text: current);
    final route = ModalBottomSheetRoute<String>(
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(sheet).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make ${variable.key.toLowerCase()} yours',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              if (variable.suggestions.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: variable.suggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(s),
                          onPressed: () => controller.text = s,
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 500,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: variable.key),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, controller.text),
                child: const Text('Apply to prompt'),
              ),
            ],
          ),
        ),
      ),
    );
    final value = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      final client = ref.read(supabaseProvider);
      final user = ref.read(authProvider).asData?.value;
      if (client != null && user != null) {
        await client.rpc(
          'consume_usage',
          params: {'p_feature': 'customization'},
        );
      } else {
        await ref.read(databaseProvider).consumeGuestCustomization();
      }
      if (mounted) {
        ref
            .read(studioProvider(widget.id).notifier)
            .setValue(variable.key, value);
      }
    } catch (_) {
      _message(
        'Daily customization limit reached, or account service unavailable.',
      );
    }
  }

  Future<void> _save(Map<String, String> values) async {
    final repo = ref.read(collectionsRepositoryProvider);
    if (repo == null) {
      _message('Sign in from your account to save prompts.');
      return;
    }
    setState(() => _busy = true);
    try {
      final boards = await repo.boards();
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Save to a collection')),
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('All saved prompts'),
                onTap: () => Navigator.pop(sheet, ''),
              ),
              ...boards.map(
                (b) => ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(b['name'] as String),
                  onTap: () => Navigator.pop(sheet, b['id'] as String),
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      final pro = ref.read(entitlementProvider).asData?.value ?? false;
      await repo.save(
        widget.id,
        pro ? values : {},
        collectionId: selected.isEmpty ? null : selected,
      );
      ref.invalidate(bookmarksProvider);
      _message(
        !pro && values.isNotEmpty
            ? 'Prompt saved. Custom presets are included with Pro.'
            : 'Saved to your private collection.',
      );
    } catch (_) {
      _message('Could not save. Check your connection and plan limits.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreSaved() async {
    try {
      final bookmarks = await ref.read(bookmarksProvider.future);
      final matches = bookmarks.where((b) => b.promptId == widget.id);
      if (matches.isNotEmpty && mounted) {
        ref
            .read(studioProvider(widget.id).notifier)
            .restore(
              (jsonDecode(matches.first.variables) as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, v as String),
              ),
            );
      }
    } catch (_) {
      _message('Saved values are temporarily unavailable.');
    }
  }

  Future<void> _share(String prompt) async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _shareKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not render');
      if (!mounted) return;
      final box = context.findRenderObject()! as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          text: prompt,
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'promptvault-card.png',
            ),
          ],
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      _message(
        'Could not share the image card. You can still copy the prompt.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(promptProvider(widget.id));
    final values = ref.watch(studioProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt studio'),
        actions: [
          IconButton(
            tooltip: 'Restore saved variables',
            onPressed: _restoreSaved,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(promptProvider(widget.id)),
            child: const Text('Try loading again'),
          ),
        ),
        data: (prompt) {
          if (prompt == null) {
            return const Center(
              child: Text('This prompt is no longer in the catalog.'),
            );
          }
          final pro = ref.watch(entitlementProvider).asData?.value ?? false;
          final locked = prompt.isProOnly && (_privatePrompt == null || !pro);
          final template = _privatePrompt ?? prompt.rawPrompt;
          final variables =
              _privateVariables ??
              (prompt.variables.isEmpty
                  ? PromptParser.parse(template)
                  : prompt.variables);
          final brand = ref.watch(brandDnaProvider).asData?.value;
          final compiled = _brandEnabled && pro && brand != null
              ? brand.apply(template, values)
              : PromptParser.compile(template, values);
          final selected = prompt.outputs.isEmpty
              ? null
              : prompt.outputs[_output.clamp(0, prompt.outputs.length - 1)];
          final preview = RepaintBoundary(
            key: _shareKey,
            child: ColoredBox(
              color: const Color(0xFF14151E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selected != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: PromptImage(output: selected),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prompt.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selected == null
                              ? 'Original daily prompt · Text edition'
                              : modelNames[selected.model] ?? selected.model,
                        ),
                        if (!locked) ...[
                          const SizedBox(height: 14),
                          Text(
                            compiled,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Create your next idea with PromptVault AI',
                          style: TextStyle(
                            color: Color(0xFF9B9DFD),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Apply my Brand DNA'),
                subtitle: Text(
                  brand?.product ??
                      'Save your product, colors and visual style',
                ),
                value: _brandEnabled && pro && brand != null,
                onChanged: locked
                    ? null
                    : (value) {
                        if (!pro) {
                          showProPaywall(context);
                          return;
                        }
                        if (brand == null) {
                          context.push('/brand');
                          return;
                        }
                        setState(() => _brandEnabled = value);
                      },
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => context.push('/brand'),
                    child: const Text('Edit Brand DNA'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/remixes/${prompt.id}'),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Community remixes'),
                  ),
                ],
              ),
              if (prompt.outputs.length > 1)
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    prompt.outputs.length,
                    (i) => ChoiceChip(
                      label: Text(
                        modelNames[prompt.outputs[i].model] ??
                            prompt.outputs[i].model,
                      ),
                      selected: i == _output,
                      onSelected: (_) => setState(() => _output = i),
                    ),
                  ),
                ),
              Text(
                locked
                    ? 'A little more possibility.'
                    : 'One prompt. Your point of view.',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (locked) ...[
                const Text(
                  'This commercial template is part of PromptVault Pro.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _unlock(prompt),
                  child: const Text('Unlock Pro template'),
                ),
              ] else ...[
                const Text(
                  'Tap a variable to change the details. Your prompt updates as you go.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: variables
                      .map(
                        (v) => ActionChip(
                          avatar: const Icon(Icons.tune, size: 16),
                          label: Text(
                            '${v.key}: ${values[v.key] ?? v.defaultValue}',
                          ),
                          onPressed: () =>
                              _edit(v, values[v.key] ?? v.defaultValue),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14151E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Your ready-to-use prompt',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy prompt',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: compiled),
                              );
                              _message('Prompt copied.');
                            },
                          ),
                        ],
                      ),
                      SelectableText(
                        compiled,
                        style: const TextStyle(height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final platform in [
                      TargetAIPlatform.chatGpt,
                      TargetAIPlatform.gemini,
                      TargetAIPlatform.claude,
                    ])
                      FilledButton.tonal(
                        onPressed: () async {
                          try {
                            final opened = await AiLauncherService()
                                .launchWithPrompt(platform, compiled);
                            _message(
                              opened
                                  ? (platform == TargetAIPlatform.gemini
                                        ? 'Prompt copied! Paste in Gemini.'
                                        : 'Prompt copied. Paste it if autofill is unavailable.')
                                  : 'Prompt copied. Open your AI app and paste it.',
                            );
                          } catch (_) {
                            _message(
                              'Could not open the AI app. Use Copy prompt and paste it manually.',
                            );
                          }
                        },
                        child: Text(
                          'Open in ${switch (platform) {
                            TargetAIPlatform.chatGpt => 'ChatGPT',
                            TargetAIPlatform.gemini => 'Gemini',
                            _ => 'Claude',
                          }}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _save(values),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save to collection'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _share(compiled),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share recipe card'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text(
                prompt.attribution,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          );
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  child: constraints.maxWidth >= 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: preview),
                            const SizedBox(width: 40),
                            Expanded(child: editor),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            preview,
                            const SizedBox(height: 28),
                            editor,
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
