import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../domain/prompt_item.dart';

class PromptImage extends StatelessWidget {
  const PromptImage({
    super.key,
    required this.output,
    this.fit = BoxFit.cover,
    this.onError,
  });
  final PromptOutput output;
  final BoxFit fit;
  final VoidCallback? onError;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: output.aspectRatio,
    child: CachedNetworkImage(
      imageUrl: output.imageUrl,
      memCacheWidth: 600,
      fit: fit,
      errorListener: (_) {
        if (onError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onError!());
        }
      },
      placeholder: (_, _) => output.blurHash.length >= 6
          ? BlurHash(hash: output.blurHash)
          : const ColoredBox(color: Color(0xFF232433)),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Color(0xFF232433),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, size: 32),
        ),
      ),
    ),
  );
}
