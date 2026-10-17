import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';

Uint8List prepareRemix(Uint8List bytes) {
  final info = image.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null || info.width * info.height > 25000000) {
    throw const FormatException('Image dimensions too large');
  }
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  final resized = image.copyResize(
    image.bakeOrientation(decoded),
    width: decoded.width >= decoded.height ? 1024 : null,
    height: decoded.height > decoded.width ? 1024 : null,
  );
  // A fresh canvas excludes EXIF/location metadata from the submitted JPEG.
  final clean = image.Image(width: resized.width, height: resized.height);
  image.compositeImage(clean, resized);
  return Uint8List.fromList(image.encodeJpg(clean, quality: 85));
}

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.promptId});
  final String promptId;
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityState();
}

class _CommunityState extends ConsumerState<CommunityScreen> {
  final _caption = TextEditingController();
  final _failed = <String>{};
  List<Map<String, dynamic>> _items = [], _submissions = [];
  int _offset = 0;
  bool _busy = false, _rights = false, _more = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(true));
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _load(bool reset) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final client = ref.read(supabaseProvider);
      if (client == null) throw StateError('Unavailable');
      final result = await client.functions.invoke(
        'community-remixes',
        body: {
          'action': 'list',
          'prompt_id': widget.promptId,
          'offset': reset ? 0 : _offset,
        },
      );
      final rows = (result.data['items'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final user = client.auth.currentUser;
      final submissions = user == null
          ? <Map<String, dynamic>>[]
          : await client
                .from('community_remixes')
                .select('id,caption,status')
                .eq('user_id', user.id)
                .eq('prompt_id', widget.promptId)
                .order('created_at', ascending: false)
                .limit(10);
      if (mounted) {
        setState(() {
          _items = reset ? rows : [..._items, ...rows];
          _offset = reset ? rows.length : _offset + rows.length;
          _more = rows.length == 10;
          _submissions = submissions;
          if (reset) _failed.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'The remix gallery is unavailable. Please retry later.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (!_rights || _busy) return;
    final client = ref.read(supabaseProvider);
    if (client?.auth.currentUser == null) {
      setState(() => _message = 'Sign in to submit an original remix.');
      return;
    }
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (await picked.length() > 12000000) throw StateError('Image too large');
      final bytes = await compute(prepareRemix, await picked.readAsBytes());
      if (bytes.length > 2000000) throw StateError('Image too large');
      await client!.functions.invoke(
        'community-remixes',
        body: {
          'action': 'submit',
          'prompt_id': widget.promptId,
          'caption': _caption.text.trim(),
          'rights_confirmed': true,
          'image_base64': base64Encode(bytes),
        },
      );
      if (mounted) {
        _caption.clear();
        setState(() {
          _rights = false;
          _message =
              'Submitted privately for review. Approved remixes appear here.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not submit. Use a supported image under 12 MB, and check your connection or daily limit (3 submissions).',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(String rpc, Map<String, dynamic> params) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(supabaseProvider);
      if (client?.auth.currentUser == null) throw StateError('Sign in');
      if (rpc == 'delete_remix') {
        await client!.functions.invoke(
          'community-remixes',
          body: {'action': 'delete', 'id': params['p_id']},
        );
      } else {
        await client!.rpc(rpc, params: params);
      }
      if (mounted) {
        setState(
          () => _message = rpc == 'vote_remix'
              ? 'Vote recorded. Verified accounts older than one day can vote.'
              : 'Thank you. Your preference has been saved.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not complete the action. Sign in with a verified account and check your connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Community remixes'),
      actions: [
        IconButton(
          tooltip: 'Refresh gallery',
          onPressed: _busy ? null : () => _load(true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'A new take starts with you.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Share your result, with permission to publish it. Every submission is reviewed. The approved weekly winner with at least 3 verified votes earns a Creator of the Week badge and 7 days of Pro. Self-votes do not count.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _caption,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Describe your remix (optional)',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _rights,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _rights = v ?? false),
              title: const Text(
                'I own this image or have permission to publish it, and consent to community display. No private information or unlicensed content.',
              ),
            ),
            FilledButton.icon(
              onPressed: _rights && !_busy ? _upload : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Choose image & submit for review'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_message!),
              ),
            if (_submissions.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Your recent submissions'),
              for (final row in _submissions)
                ListTile(
                  title: Text(
                    (row['caption'] as String).isEmpty
                        ? 'Your remix'
                        : row['caption'] as String,
                  ),
                  subtitle: Text(row['status'] as String),
                  trailing: IconButton(
                    tooltip: 'Delete submission',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy
                        ? null
                        : () async {
                            await _action('delete_remix', {'p_id': row['id']});
                            await _load(true);
                          },
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'Approved remixes (${_items.length}${_more ? '+' : ''})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_busy && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No approved remixes yet. Be the first to submit a new take.',
                ),
              ),
            for (final row in _items.where((r) => !_failed.contains(r['id'])))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 600),
                        child: Image.network(
                          row['image_url'] as String,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_failed.contains(row['id'])) {
                                setState(
                                  () => _failed.add(row['id'] as String),
                                );
                              }
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(row['caption'] as String),
                      if (row['creator_of_week'] == true)
                        const Chip(label: Text('Creator of the Week')),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await _action('vote_remix', {
                                      'p_id': row['id'],
                                    });
                                    await _load(true);
                                  },
                            icon: const Icon(Icons.thumb_up_outlined),
                            label: Text('${row['votes']} votes'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await _action('report_remix', {
                                      'p_id': row['id'],
                                    });
                                    await _load(true);
                                  },
                            child: const Text('Report'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await _action('block_remix_creator', {
                                      'p_id': row['id'],
                                    });
                                    await _load(true);
                                  },
                            child: const Text('Hide this creator'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_more && !_busy)
              TextButton(
                onPressed: () => _load(false),
                child: const Text('Load 10 more remixes'),
              ),
          ],
        ),
      ),
    ),
  );
}
