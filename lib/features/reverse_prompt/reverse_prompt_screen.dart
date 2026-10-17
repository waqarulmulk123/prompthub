import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';
import '../subscription/pro_paywall_screen.dart';

Uint8List resizeReference(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Unsupported image');
  final resized = image.width > 1024 || image.height > 1024
      ? img.copyResize(
          image,
          width: image.width >= image.height ? 1024 : null,
          height: image.height > image.width ? 1024 : null,
        )
      : image;
  // PNG is supported across the image package, browsers and Gemini; no fake WebP encoding.
  return Uint8List.fromList(img.encodePng(resized));
}

class ReversePromptScreen extends ConsumerStatefulWidget {
  const ReversePromptScreen({super.key});
  @override
  ConsumerState<ReversePromptScreen> createState() => _ReversePromptState();
}

class _ReversePromptState extends ConsumerState<ReversePromptScreen> {
  bool _busy = false;
  Uint8List? _image;
  Map<String, dynamic>? _result;
  String? _error;
  Future<void> _select() async {
    final client = ref.read(supabaseProvider);
    final user = ref.read(authProvider).asData?.value;
    if (client == null || user == null) {
      setState(
        () => _error = 'Sign in from your account to use image-to-prompt.',
      );
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 12 * 1024 * 1024) {
        throw const FormatException('Choose an image smaller than 12 MB.');
      }
      final encoded = await compute(resizeReference, bytes);
      if (mounted) setState(() => _image = encoded);
      final response = await client.functions.invoke(
        'reverse-prompt',
        body: {'image_base64': base64Encode(encoded), 'mime_type': 'image/png'},
      );
      if (response.status != 200) {
        throw StateError('Image analysis unavailable');
      }
      if (mounted) {
        setState(
          () => _result = Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not analyze this image. Check your connection and daily scan allowance.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Image to inspiration')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Find the recipe\nbehind a reference.',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose a reference to create a reusable prompt with editable subjects, lighting and camera details. Only upload images you have permission to use.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Two scans per day on Free. Images are sent to the AI provider for analysis.',
            ),
            const SizedBox(height: 24),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_image!, height: 280, fit: BoxFit.contain),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _select,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _busy ? 'Finding your prompt…' : 'Choose a reference image',
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(_error!),
              ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              SelectableText(
                _result!['base_prompt'] as String? ?? '',
                style: const TextStyle(height: 1.7),
              ),
              const SizedBox(height: 16),
              for (final field in [
                'lighting_style',
                'camera_settings',
                'recommended_model',
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(field.replaceAll('_', ' ')),
                  subtitle: Text('${_result![field] ?? ''}'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: _result!['base_prompt'] as String? ?? '',
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Prompt copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy extracted prompt'),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => showProPaywall(context),
              child: const Text('Explore Pro scans'),
            ),
          ],
        ),
      ),
    ),
  );
}
