import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

class TemplatePreviewImage extends StatefulWidget {
  const TemplatePreviewImage({
    required this.imageUrl,
    required this.placeholder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    super.key,
  });

  final String imageUrl;
  final Widget placeholder;
  final WidgetBuilder errorBuilder;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  @override
  State<TemplatePreviewImage> createState() => _TemplatePreviewImageState();
}

class _TemplatePreviewImageState extends State<TemplatePreviewImage> {
  late Future<File> _imageFileFuture;

  @override
  void initState() {
    super.initState();
    _imageFileFuture = TemplateMediaCache.fetchThumbnailFile(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant TemplatePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFileFuture = TemplateMediaCache.fetchThumbnailFile(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _imageFileFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) {
          if (snapshot.hasError) {
            return widget.errorBuilder(context);
          }
          return widget.placeholder;
        }

        return Image.file(
          file,
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: widget.cacheWidth,
          filterQuality: widget.filterQuality,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            final isReady = wasSynchronouslyLoaded || frame != null;
            return AnimatedOpacity(
              opacity: isReady ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            unawaited(TemplateMediaCache.removeThumbnailFile(widget.imageUrl));
            return widget.errorBuilder(context);
          },
        );
      },
    );
  }
}
