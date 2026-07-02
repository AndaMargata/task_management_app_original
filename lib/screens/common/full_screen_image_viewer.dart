import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Full-screen image viewer with zoom, pan, and close button.
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final imageWidget = InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (_, _) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (_, _, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded,
                  size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text('Failed to load image',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: heroTag != null
          ? Hero(tag: heroTag!, child: imageWidget)
          : imageWidget,
    );
  }
}
