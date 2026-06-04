import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:image/image.dart' as img;

class ProfileAvatarCropperPage extends StatefulWidget {
  const ProfileAvatarCropperPage({required this.sourceImagePath, super.key});

  final String sourceImagePath;

  @override
  State<ProfileAvatarCropperPage> createState() =>
      _ProfileAvatarCropperPageState();
}

class _ProfileAvatarCropperPageState extends State<ProfileAvatarCropperPage> {
  static const double _minZoom = 1;
  static const double _maxZoom = 3.2;

  final TransformationController _transformationController =
      TransformationController();

  img.Image? _decodedImage;
  Uint8List? _displayImageBytes;
  bool _isPreparing = true;
  bool _isSaving = false;
  double _zoom = _minZoom;
  double _cropSize = 0;
  Size _imageSize = Size.zero;
  double _baseScale = 1;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadSourceImage() async {
    try {
      final bytes = await File(widget.sourceImagePath).readAsBytes();
      final decodedSource = img.decodeImage(bytes);
      if (!mounted) {
        return;
      }

      if (decodedSource == null) {
        setState(() {
          _decodedImage = null;
          _displayImageBytes = null;
          _isPreparing = false;
        });
        return;
      }

      final decoded = img.bakeOrientation(decodedSource);
      final previewBytes = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 95),
      );

      setState(() {
        _decodedImage = decoded;
        _displayImageBytes = previewBytes;
        _isPreparing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _decodedImage = null;
        _displayImageBytes = null;
        _isPreparing = false;
      });
    }
  }

  void _configureBaseTransformIfNeeded(double cropSize) {
    if (_decodedImage == null) {
      return;
    }

    if ((_cropSize - cropSize).abs() < 0.5 && _imageSize != Size.zero) {
      return;
    }

    _cropSize = cropSize;

    final imageWidth = _decodedImage!.width.toDouble();
    final imageHeight = _decodedImage!.height.toDouble();
    _imageSize = Size(imageWidth, imageHeight);
    _baseScale = math.max(cropSize / imageWidth, cropSize / imageHeight);

    final displayWidth = imageWidth * _baseScale;
    final displayHeight = imageHeight * _baseScale;

    final initialTranslateX = (cropSize - displayWidth) / 2;
    final initialTranslateY = (cropSize - displayHeight) / 2;

    final matrix = Matrix4.identity()
      ..setEntry(0, 0, _baseScale)
      ..setEntry(1, 1, _baseScale)
      ..setEntry(2, 2, 1)
      ..setTranslationRaw(initialTranslateX, initialTranslateY, 0);

    _applyClampedMatrix(matrix, updateZoom: false);
    _zoom = _currentScale;
  }

  void _handleScaleChanged(double nextScale) {
    final currentScale = _currentScale;
    if ((nextScale - currentScale).abs() < 0.001 || _cropSize <= 0) {
      return;
    }

    final matrix = _transformationController.value;
    final currentAbsoluteScale = matrix.getMaxScaleOnAxis();
    final currentTx = matrix.storage[12];
    final currentTy = matrix.storage[13];
    final targetAbsoluteScale = _baseScale * nextScale;

    if (currentAbsoluteScale <= 0 || currentAbsoluteScale.isNaN) {
      return;
    }

    final focalPoint = Offset(_cropSize / 2, _cropSize / 2);
    final imagePointX = (focalPoint.dx - currentTx) / currentAbsoluteScale;
    final imagePointY = (focalPoint.dy - currentTy) / currentAbsoluteScale;

    final nextTx = focalPoint.dx - imagePointX * targetAbsoluteScale;
    final nextTy = focalPoint.dy - imagePointY * targetAbsoluteScale;

    final nextMatrix = _matrixWithScaleAndTranslation(
      targetAbsoluteScale,
      nextTx,
      nextTy,
    );

    _applyClampedMatrix(nextMatrix, updateZoom: true);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (!mounted) {
      return;
    }

    final liveZoom = _currentScale;
    if ((_zoom - liveZoom).abs() < 0.001) {
      return;
    }

    setState(() => _zoom = liveZoom);
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _applyClampedMatrix(
      Matrix4.copy(_transformationController.value),
      updateZoom: true,
    );
  }

  double get _currentScale {
    final absoluteScale = _transformationController.value.getMaxScaleOnAxis();
    if (absoluteScale.isNaN || absoluteScale.isInfinite || _baseScale <= 0) {
      return _minZoom;
    }

    final zoom = absoluteScale / _baseScale;
    return zoom.clamp(_minZoom, _maxZoom);
  }

  void _applyClampedMatrix(Matrix4 input, {required bool updateZoom}) {
    if (_cropSize <= 0 || _imageSize == Size.zero || _baseScale <= 0) {
      _transformationController.value = input;
      if (updateZoom) {
        setState(() => _zoom = _currentScale);
      }
      return;
    }

    final absoluteScale = input.getMaxScaleOnAxis().clamp(
      _baseScale * _minZoom,
      _baseScale * _maxZoom,
    );
    final zoom = (absoluteScale / _baseScale).clamp(_minZoom, _maxZoom);
    final clampedScale = _baseScale * zoom;

    var tx = input.storage[12];
    var ty = input.storage[13];

    final scaledWidth = _imageSize.width * clampedScale;
    final scaledHeight = _imageSize.height * clampedScale;

    final minTx = scaledWidth <= _cropSize
        ? (_cropSize - scaledWidth) / 2
        : _cropSize - scaledWidth;
    final maxTx = scaledWidth <= _cropSize ? minTx : 0.0;
    final minTy = scaledHeight <= _cropSize
        ? (_cropSize - scaledHeight) / 2
        : _cropSize - scaledHeight;
    final maxTy = scaledHeight <= _cropSize ? minTy : 0.0;

    tx = tx.clamp(minTx, maxTx);
    ty = ty.clamp(minTy, maxTy);

    _transformationController.value = _matrixWithScaleAndTranslation(
      clampedScale,
      tx,
      ty,
    );

    if (updateZoom && mounted) {
      setState(() => _zoom = zoom);
    }
  }

  Matrix4 _matrixWithScaleAndTranslation(double scale, double tx, double ty) {
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  Future<void> _saveCrop() async {
    final text = AppLocalizations.of(context);
    final decoded = _decodedImage;
    if (decoded == null || _cropSize <= 0 || _imageSize == Size.zero) {
      _showError(text.profileAvatarCropError);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final matrix = _transformationController.value;
      final scale = matrix.getMaxScaleOnAxis().clamp(
        _baseScale * _minZoom,
        _baseScale * _maxZoom,
      );
      final tx = matrix.storage[12];
      final ty = matrix.storage[13];

      final leftPx = ((-tx) / scale).round();
      final topPx = ((-ty) / scale).round();
      final sizePx = (_cropSize / scale).round();

      final clampedLeft = leftPx.clamp(0, decoded.width - 1);
      final clampedTop = topPx.clamp(0, decoded.height - 1);

      final maxWidth = decoded.width - clampedLeft;
      final maxHeight = decoded.height - clampedTop;
      final cropSizePx = math.max(
        1,
        math.min(sizePx, math.min(maxWidth, maxHeight)),
      );

      final cropped = img.copyCrop(
        decoded,
        x: clampedLeft,
        y: clampedTop,
        width: cropSizePx,
        height: cropSizePx,
      );
      final resized = img.copyResize(
        cropped,
        width: 1200,
        height: 1200,
        interpolation: img.Interpolation.cubic,
      );
      final jpgBytes = img.encodeJpg(resized, quality: 92);

      final outputPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}petmagic_avatar_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(jpgBytes, flush: true);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(outputFile.path);
    } catch (_) {
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
              onPressed: (_isSaving || _isPreparing || _decodedImage == null)
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
              : _decodedImage == null
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
                    _configureBaseTransformIfNeeded(cropSize);

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
                        SizedBox(
                          width: cropSize,
                          height: cropSize,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRect(
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  constrained: false,
                                  minScale: 0.01,
                                  maxScale: 100,
                                  boundaryMargin: EdgeInsets.zero,
                                  clipBehavior: Clip.none,
                                  onInteractionUpdate: _onInteractionUpdate,
                                  onInteractionEnd: _onInteractionEnd,
                                  child: SizedBox(
                                    width: _imageSize.width,
                                    height: _imageSize.height,
                                    child: _displayImageBytes == null
                                        ? const SizedBox.shrink()
                                        : Image.memory(
                                            _displayImageBytes!,
                                            fit: BoxFit.fill,
                                          ),
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _AvatarCropOverlayPainter(
                                    overlayColor: Colors.black.withValues(
                                      alpha: 0.46,
                                    ),
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.96,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
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
                                      value: _zoom,
                                      min: _minZoom,
                                      max: _maxZoom,
                                      onChanged: _isSaving
                                          ? null
                                          : _handleScaleChanged,
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
