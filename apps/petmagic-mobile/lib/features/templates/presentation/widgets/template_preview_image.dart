import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

typedef TemplatePreviewImageFileLoader =
    Future<File> Function(String imageUrl, {int? mediaVersion});
typedef TemplatePreviewImageFileRemover =
    Future<void> Function(String imageUrl, {int? mediaVersion});

class _ResolvedTemplatePreviewImage {
  const _ResolvedTemplatePreviewImage({
    required this.file,
    required this.imageUrl,
    required this.mediaVersion,
    required this.remover,
  });

  final File file;
  final String imageUrl;
  final int? mediaVersion;
  final TemplatePreviewImageFileRemover remover;
}

class TemplatePreviewImage extends StatefulWidget {
  const TemplatePreviewImage({
    required this.imageUrl,
    required this.placeholder,
    required this.errorBuilder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.mediaVersion,
    this.fileLoader,
    this.fileRemover,
    this.preserveOldImageOnUrlChange = false,
    super.key,
  });

  final String imageUrl;
  final Widget placeholder;
  final WidgetBuilder errorBuilder;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final int? mediaVersion;
  final TemplatePreviewImageFileLoader? fileLoader;
  final TemplatePreviewImageFileRemover? fileRemover;
  final bool preserveOldImageOnUrlChange;

  @override
  State<TemplatePreviewImage> createState() => _TemplatePreviewImageState();
}

class _TemplatePreviewImageState extends State<TemplatePreviewImage> {
  late Future<_ResolvedTemplatePreviewImage> _imageFileFuture;
  _ResolvedTemplatePreviewImage? _lastResolvedImage;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    _imageFileFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant TemplatePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.mediaVersion != widget.mediaVersion ||
        oldWidget.fileLoader != widget.fileLoader ||
        oldWidget.fileRemover != widget.fileRemover) {
      if (!widget.preserveOldImageOnUrlChange) {
        _lastResolvedImage = null;
      }
      _imageFileFuture = _loadImage();
    }
  }

  Future<_ResolvedTemplatePreviewImage> _loadImage() {
    final revision = ++_loadRevision;
    final imageUrl = widget.imageUrl;
    final mediaVersion = widget.mediaVersion;
    final loader = widget.fileLoader ?? TemplateMediaCache.fetchThumbnailFile;
    final remover =
        widget.fileRemover ?? TemplateMediaCache.removeThumbnailFile;
    return loader(imageUrl, mediaVersion: mediaVersion).then((file) {
      final resolved = _ResolvedTemplatePreviewImage(
        file: file,
        imageUrl: imageUrl,
        mediaVersion: mediaVersion,
        remover: remover,
      );
      if (revision == _loadRevision) {
        _lastResolvedImage = resolved;
      }
      return resolved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedTemplatePreviewImage>(
      future: _imageFileFuture,
      builder: (context, snapshot) {
        final resolved =
            snapshot.data ??
            (widget.preserveOldImageOnUrlChange ? _lastResolvedImage : null);
        if (resolved == null) {
          if (snapshot.hasError) {
            return widget.errorBuilder(context);
          }
          return widget.placeholder;
        }

        final mediaQuery = MediaQuery.maybeOf(context);
        final reduceMotion =
            mediaQuery?.disableAnimations == true ||
            mediaQuery?.accessibleNavigation == true;
        return Image.file(
          resolved.file,
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: widget.cacheWidth,
          filterQuality: widget.filterQuality,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            final isReady = wasSynchronouslyLoaded || frame != null;
            return AnimatedOpacity(
              opacity: isReady ? 1 : 0,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            unawaited(
              resolved.remover(
                resolved.imageUrl,
                mediaVersion: resolved.mediaVersion,
              ),
            );
            return widget.errorBuilder(context);
          },
        );
      },
    );
  }
}
