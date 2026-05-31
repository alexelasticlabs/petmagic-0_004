import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:image/image.dart' as img;

class ProfileAvatarCropperPage extends StatefulWidget {
  const ProfileAvatarCropperPage({required this.sourceImagePath, super.key});

  final String sourceImagePath;

  @override
  State<ProfileAvatarCropperPage> createState() =>
      _ProfileAvatarCropperPageState();
}

class _ProfileAvatarCropperPageState extends State<ProfileAvatarCropperPage> {
  static const double _minScale = 1;
  static const double _maxScale = 4;

  final TransformationController _transformationController =
      TransformationController();

  img.Image? _decodedImage;
  bool _isPreparing = true;
  bool _isSaving = false;
  double _zoom = _minScale;
  double _cropSize = 0;
  Size _baseDisplaySize = Size.zero;

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
      final decoded = img.decodeImage(bytes);
      if (!mounted) {
        return;
      }

      setState(() {
        _decodedImage = decoded;
        _isPreparing = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _decodedImage = null;
        _isPreparing = false;
      });
    }
  }

  void _configureBaseTransformIfNeeded(double cropSize) {
    if (_decodedImage == null) {
      return;
    }

    if ((_cropSize - cropSize).abs() < 0.5 && _baseDisplaySize != Size.zero) {
      return;
    }

    _cropSize = cropSize;

    final imageWidth = _decodedImage!.width.toDouble();
    final imageHeight = _decodedImage!.height.toDouble();
    final baseScale = math.max(cropSize / imageWidth, cropSize / imageHeight);

    final displayWidth = imageWidth * baseScale;
    final displayHeight = imageHeight * baseScale;
    _baseDisplaySize = Size(displayWidth, displayHeight);

    final initialTranslateX = (cropSize - displayWidth) / 2;
    final initialTranslateY = (cropSize - displayHeight) / 2;

    final matrix = Matrix4.identity()
      ..translateByDouble(initialTranslateX, initialTranslateY, 0, 1)
      ..scaleByDouble(_minScale, _minScale, 1, 1);

    _applyClampedMatrix(matrix, updateZoom: false);
    _zoom = _currentScale;
  }

  void _handleScaleChanged(double nextScale) {
    final currentScale = _currentScale;
    if ((nextScale - currentScale).abs() < 0.001 || _cropSize <= 0) {
      return;
    }

    final factor = nextScale / currentScale;
    final focalPoint = Offset(_cropSize / 2, _cropSize / 2);

    final matrix = Matrix4.copy(_transformationController.value)
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);

    _applyClampedMatrix(matrix, updateZoom: true);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _applyClampedMatrix(
      Matrix4.copy(_transformationController.value),
      updateZoom: true,
    );
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _applyClampedMatrix(
      Matrix4.copy(_transformationController.value),
      updateZoom: true,
    );
  }

  double get _currentScale {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale.isNaN || scale.isInfinite) {
      return _minScale;
    }

    return scale.clamp(_minScale, _maxScale);
  }

  void _applyClampedMatrix(Matrix4 input, {required bool updateZoom}) {
    if (_cropSize <= 0 || _baseDisplaySize == Size.zero) {
      _transformationController.value = input;
      if (updateZoom) {
        setState(() => _zoom = _currentScale);
      }
      return;
    }

    final scale = input.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
    input.setEntry(0, 0, scale);
    input.setEntry(1, 1, scale);

    var tx = input.storage[12];
    var ty = input.storage[13];

    final scaledWidth = _baseDisplaySize.width * scale;
    final scaledHeight = _baseDisplaySize.height * scale;

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

    input.storage[12] = tx;
    input.storage[13] = ty;

    _transformationController.value = input;

    if (updateZoom && mounted) {
      setState(() => _zoom = scale);
    }
  }

  Future<void> _saveCrop() async {
    final text = AppLocalizations.of(context);
    final decoded = _decodedImage;
    if (decoded == null || _cropSize <= 0 || _baseDisplaySize == Size.zero) {
      _showError(text.profileAvatarCropError);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final matrix = _transformationController.value;
      final scale = matrix.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
      final tx = matrix.storage[12];
      final ty = matrix.storage[13];

      final leftOnBase = (-tx) / scale;
      final topOnBase = (-ty) / scale;
      final sizeOnBase = _cropSize / scale;

      final ratioX = decoded.width / _baseDisplaySize.width;
      final ratioY = decoded.height / _baseDisplaySize.height;

      final leftPx = (leftOnBase * ratioX).round();
      final topPx = (topOnBase * ratioY).round();
      final sizePx = (sizeOnBase * ratioX).round();

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                                  minScale: _minScale,
                                  maxScale: _maxScale,
                                  boundaryMargin: EdgeInsets.zero,
                                  clipBehavior: Clip.none,
                                  onInteractionUpdate: _onInteractionUpdate,
                                  onInteractionEnd: _onInteractionEnd,
                                  child: SizedBox(
                                    width: _baseDisplaySize.width,
                                    height: _baseDisplaySize.height,
                                    child: Image.file(
                                      File(widget.sourceImagePath),
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
                                      min: _minScale,
                                      max: _maxScale,
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
