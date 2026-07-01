import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/profile/presentation/avatar_crop_viewport.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

@visibleForTesting
const profileAvatarCropViewportKey = ValueKey('profile-avatar-crop-viewport');

@visibleForTesting
const profileAvatarCropImageKey = ValueKey('profile-avatar-crop-image');

class ProfileAvatarCropperPage extends StatefulWidget {
  const ProfileAvatarCropperPage({
    required this.sourceImagePath,
    this.debugImageData,
    super.key,
  });

  final String sourceImagePath;
  final ProfileAvatarCropperDebugImageData? debugImageData;

  @override
  State<ProfileAvatarCropperPage> createState() =>
      _ProfileAvatarCropperPageState();
}

class _ProfileAvatarCropperPageState extends State<ProfileAvatarCropperPage> {
  Uint8List? _sourceImageBytes;
  Uint8List? _displayImageBytes;
  bool _isPreparing = true;
  bool _isSaving = false;
  Size _imageSize = Size.zero;
  AvatarCropViewport? _viewport;
  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    final debugImageData = widget.debugImageData;
    if (debugImageData != null) {
      _sourceImageBytes = debugImageData.sourceBytes;
      _displayImageBytes = debugImageData.previewBytes;
      _imageSize = debugImageData.imageSize;
      _isPreparing = false;
      return;
    }

    _loadSourceImage();
  }

  Future<void> _loadSourceImage() async {
    try {
      final bytes = await File(widget.sourceImagePath).readAsBytes();
      final prepared = await compute(_prepareAvatarPreview, bytes);
      if (!mounted) {
        return;
      }

      if (prepared == null) {
        setState(() {
          _sourceImageBytes = null;
          _displayImageBytes = null;
          _isPreparing = false;
        });
        return;
      }

      setState(() {
        _sourceImageBytes = bytes;
        _displayImageBytes = prepared['previewBytes']! as Uint8List;
        _imageSize = Size(
          (prepared['width']! as int).toDouble(),
          (prepared['height']! as int).toDouble(),
        );
        _viewport = null;
        _isPreparing = false;
      });
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Profile.AvatarCropper',
        operation: 'load_source_image',
        message: 'Avatar cropper could not load source image',
        context: {'hasDebugImageData': widget.debugImageData != null},
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _sourceImageBytes = null;
        _displayImageBytes = null;
        _viewport = null;
        _isPreparing = false;
      });
    }
  }

  AvatarCropViewport _viewportFor(double cropSize) {
    final current = _viewport;
    if (current == null ||
        current.imageSize != _imageSize ||
        (current.viewportSize - cropSize).abs() >= 0.5) {
      _viewport = current == null || current.imageSize != _imageSize
          ? AvatarCropViewport.initial(
              imageSize: _imageSize,
              viewportSize: cropSize,
            )
          : current.withViewportSize(cropSize);
    }

    return _viewport!;
  }

  void _onScaleStart(ScaleStartDetails details) {
    final viewport = _viewport;
    if (viewport == null || _isSaving) {
      return;
    }

    _gestureStartScale = viewport.scale;
    _gestureStartOffset = viewport.offset;
    _gestureStartFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final viewport = _viewport;
    if (viewport == null || _isSaving) {
      return;
    }

    final focalDelta = details.localFocalPoint - _gestureStartFocalPoint;
    final pannedOffset = _gestureStartOffset + focalDelta;
    final nextViewport = viewport.zoomAroundFocalPoint(
      startScale: _gestureStartScale,
      startOffset: pannedOffset,
      gestureScale: details.scale,
      focalPoint: details.localFocalPoint,
    );

    setState(() => _viewport = nextViewport);
  }

  void _handleZoomChanged(double nextZoom) {
    final viewport = _viewport;
    if (viewport == null || _isSaving) {
      return;
    }

    setState(() {
      _viewport = viewport.zoomTo(
        nextZoom,
        focalPoint: Offset(
          viewport.viewportSize / 2,
          viewport.viewportSize / 2,
        ),
      );
    });
  }

  void _resetCrop() {
    final viewport = _viewport;
    if (viewport == null || _isSaving) {
      return;
    }

    setState(() => _viewport = viewport.reset());
  }

  void _fitCrop() {
    final viewport = _viewport;
    if (viewport == null || _isSaving) {
      return;
    }

    setState(() => _viewport = viewport.fitToViewport());
  }

  Future<void> _saveCrop() async {
    final text = AppLocalizations.of(context);
    final sourceImageBytes = _sourceImageBytes;
    final viewport = _viewport;
    if (sourceImageBytes == null ||
        viewport == null ||
        _imageSize == Size.zero) {
      _showError(text.profileAvatarCropError);
      return;
    }

    setState(() => _isSaving = true);

    File? outputFile;
    try {
      final cropRect = viewport.cropRect;
      final imageWidth = _imageSize.width.round();
      final imageHeight = _imageSize.height.round();
      final clampedLeft = cropRect.left.round().clamp(0, imageWidth - 1);
      final clampedTop = cropRect.top.round().clamp(0, imageHeight - 1);

      final maxWidth = imageWidth - clampedLeft;
      final maxHeight = imageHeight - clampedTop;
      final cropSizePx = math.max(
        1,
        math.min(cropRect.width.round(), math.min(maxWidth, maxHeight)),
      );

      final jpgBytes = await compute(optimizeAvatarCropBytes, <String, Object>{
        'bytes': sourceImageBytes,
        'x': clampedLeft,
        'y': clampedTop,
        'size': cropSizePx,
      });
      if (jpgBytes == null) {
        throw StateError('Avatar crop failed.');
      }

      final outputPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}petmagic_avatar_${DateTime.now().microsecondsSinceEpoch}.jpg';
      outputFile = File(outputPath);
      await outputFile.writeAsBytes(jpgBytes, flush: true);

      if (!mounted) {
        await TempMediaCleanup.deleteIfExists(outputFile);
        return;
      }

      Navigator.of(context).pop(outputFile.path);
    } catch (error, stackTrace) {
      if (outputFile != null) {
        await TempMediaCleanup.deleteIfExists(outputFile);
      }
      AppLogger.warn(
        feature: 'Profile.AvatarCropper',
        operation: 'save_cropped_avatar',
        message: 'Avatar cropper could not save cropped image',
        context: {
          'hasViewport': _viewport != null,
          'imageReady': _imageSize != Size.zero,
        },
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      _showError(text.profileAvatarCropError);
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    PetMagicToast.show(
      context,
      message: message,
      tone: PetMagicToastTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(text.profileAvatarCropTitle),
          leadingWidth: 96,
          leading: TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(text.profileAvatarCropCancelAction),
          ),
          actions: [
            TextButton(
              onPressed:
                  (_isSaving || _isPreparing || _displayImageBytes == null)
                  ? null
                  : _saveCrop,
              child: Text(text.profileAvatarCropSaveAction),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _isPreparing
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator.adaptive(),
                      const SizedBox(height: 12),
                      Text(
                        text.profileAvatarCropLoading,
                        style: TextStyle(color: colors.textSoft),
                      ),
                    ],
                  ),
                )
              : _displayImageBytes == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      text.profileAvatarCropError,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxCrop = math.min(constraints.maxWidth - 28, 360.0);
                    final cropSize = maxCrop.clamp(
                      220.0,
                      constraints.maxWidth - 20,
                    );
                    final viewport = _viewportFor(cropSize);

                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          text.profileAvatarCropHint,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AvatarCropViewportView(
                          cropSize: cropSize,
                          viewport: viewport,
                          imageBytes: _displayImageBytes!,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                        ),
                        const SizedBox(height: 16),
                        _AvatarCropActions(
                          isSaving: _isSaving,
                          resetLabel: text.profileAvatarCropResetAction,
                          fitLabel: text.profileAvatarCropFitAction,
                          onReset: _resetCrop,
                          onFit: _fitCrop,
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.border.withValues(alpha: 0.85),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.zoom_out_rounded,
                                    color: colors.textMuted,
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: viewport.zoom,
                                      min: avatarCropMinZoom,
                                      max: avatarCropMaxZoom,
                                      onChanged: _isSaving
                                          ? null
                                          : _handleZoomChanged,
                                    ),
                                  ),
                                  Icon(
                                    Icons.zoom_in_rounded,
                                    color: colors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isSaving) ...[
                          const SizedBox(height: 10),
                          const CircularProgressIndicator.adaptive(),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AvatarCropViewportView extends StatelessWidget {
  const _AvatarCropViewportView({
    required this.cropSize,
    required this.viewport,
    required this.imageBytes,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final double cropSize;
  final AvatarCropViewport viewport;
  final Uint8List imageBytes;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cropSize,
      height: cropSize,
      child: GestureDetector(
        key: profileAvatarCropViewportKey,
        behavior: HitTestBehavior.opaque,
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    key: profileAvatarCropImageKey,
                    left: viewport.offset.dx,
                    top: viewport.offset.dy,
                    width: viewport.imageSize.width * viewport.scale,
                    height: viewport.imageSize.height * viewport.scale,
                    child: Image.memory(imageBytes, fit: BoxFit.fill),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _AvatarCropOverlayPainter(
                  overlayColor: Colors.black.withValues(alpha: 0.46),
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.96),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCropActions extends StatelessWidget {
  const _AvatarCropActions({
    required this.isSaving,
    required this.resetLabel,
    required this.fitLabel,
    required this.onReset,
    required this.onFit,
  });

  final bool isSaving;
  final String resetLabel;
  final String fitLabel;
  final VoidCallback onReset;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: isSaving ? null : onReset,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: Text(resetLabel),
        ),
        OutlinedButton.icon(
          onPressed: isSaving ? null : onFit,
          icon: const Icon(Icons.fit_screen_rounded, size: 18),
          label: Text(fitLabel),
        ),
      ],
    );
  }
}

@visibleForTesting
class ProfileAvatarCropperDebugImageData {
  const ProfileAvatarCropperDebugImageData({
    required this.sourceBytes,
    required this.previewBytes,
    required this.imageSize,
  });

  final Uint8List sourceBytes;
  final Uint8List previewBytes;
  final Size imageSize;
}

class _AvatarCropOverlayPainter extends CustomPainter {
  const _AvatarCropOverlayPainter({required this.overlayColor});

  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final path = Path()
      ..addRect(fullRect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _AvatarCropOverlayPainter oldDelegate) {
    return oldDelegate.overlayColor != overlayColor;
  }
}

Map<String, Object>? _prepareAvatarPreview(Uint8List sourceBytes) {
  final decodedSource = img.decodeImage(sourceBytes);
  if (decodedSource == null) {
    return null;
  }

  final decoded = img.bakeOrientation(decodedSource);
  return {
    'width': decoded.width,
    'height': decoded.height,
    'previewBytes': Uint8List.fromList(img.encodeJpg(decoded, quality: 95)),
  };
}
