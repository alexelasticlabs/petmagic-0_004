import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double avatarCropMinZoom = 1;

const double avatarCropMaxZoom = 3.2;

class AvatarCropViewport {
  const AvatarCropViewport({
    required this.imageSize,
    required this.viewportSize,
    required this.scale,
    required this.offset,
  });

  factory AvatarCropViewport.initial({
    required Size imageSize,
    required double viewportSize,
  }) {
    final minScale = _minScaleFor(imageSize, viewportSize);
    return AvatarCropViewport(
      imageSize: imageSize,
      viewportSize: viewportSize,
      scale: minScale,
      offset: _centerOffset(imageSize, viewportSize, minScale),
    )._clamped();
  }

  final Size imageSize;
  final double viewportSize;
  final double scale;
  final Offset offset;

  double get minScale => _minScaleFor(imageSize, viewportSize);

  double get maxScale => minScale * avatarCropMaxZoom;

  double get zoom {
    final minimum = minScale;
    if (!minimum.isFinite || minimum <= 0) {
      return avatarCropMinZoom;
    }

    return (scale / minimum).clamp(avatarCropMinZoom, avatarCropMaxZoom);
  }

  Rect get displayRect {
    return Rect.fromLTWH(
      offset.dx,
      offset.dy,
      imageSize.width * scale,
      imageSize.height * scale,
    );
  }

  Rect get cropRect {
    final left = (-offset.dx / scale).clamp(0.0, imageSize.width);
    final top = (-offset.dy / scale).clamp(0.0, imageSize.height);
    final size = (viewportSize / scale)
        .clamp(1.0, math.min(imageSize.width - left, imageSize.height - top))
        .toDouble();

    return Rect.fromLTWH(left, top, size, size);
  }

  bool get coversViewport {
    final rect = displayRect;
    return rect.left <= 0 &&
        rect.top <= 0 &&
        rect.right >= viewportSize &&
        rect.bottom >= viewportSize;
  }

  AvatarCropViewport reset() {
    return AvatarCropViewport.initial(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
  }

  AvatarCropViewport fitToViewport() => reset();

  AvatarCropViewport withViewportSize(double nextViewportSize) {
    if ((nextViewportSize - viewportSize).abs() < 0.5) {
      return this;
    }

    final currentCenter = Offset(viewportSize / 2, viewportSize / 2);
    final imageCenter = _imagePointFor(currentCenter);
    final nextMinScale = _minScaleFor(imageSize, nextViewportSize);
    final nextScale = (nextMinScale * zoom).clamp(
      nextMinScale * avatarCropMinZoom,
      nextMinScale * avatarCropMaxZoom,
    );
    final nextCenter = Offset(nextViewportSize / 2, nextViewportSize / 2);

    return AvatarCropViewport(
      imageSize: imageSize,
      viewportSize: nextViewportSize,
      scale: nextScale,
      offset: nextCenter - imageCenter * nextScale,
    )._clamped();
  }

  AvatarCropViewport panBy(Offset delta) {
    return AvatarCropViewport(
      imageSize: imageSize,
      viewportSize: viewportSize,
      scale: scale,
      offset: offset + delta,
    )._clamped();
  }

  AvatarCropViewport zoomTo(double nextZoom, {Offset? focalPoint}) {
    final nextScale =
        minScale * nextZoom.clamp(avatarCropMinZoom, avatarCropMaxZoom);
    return zoomToScale(nextScale, focalPoint: focalPoint);
  }

  AvatarCropViewport zoomToScale(double nextScale, {Offset? focalPoint}) {
    final focus = focalPoint ?? Offset(viewportSize / 2, viewportSize / 2);
    final imagePoint = _imagePointFor(focus);

    return AvatarCropViewport(
      imageSize: imageSize,
      viewportSize: viewportSize,
      scale: nextScale,
      offset: focus - imagePoint * nextScale,
    )._clamped();
  }

  AvatarCropViewport zoomAroundFocalPoint({
    required double startScale,
    required Offset startOffset,
    required double gestureScale,
    required Offset focalPoint,
  }) {
    final safeStartScale = startScale.isFinite && startScale > 0
        ? startScale
        : minScale;
    final imagePoint = (focalPoint - startOffset) / safeStartScale;
    final nextScale = safeStartScale * gestureScale;

    return AvatarCropViewport(
      imageSize: imageSize,
      viewportSize: viewportSize,
      scale: nextScale,
      offset: focalPoint - imagePoint * nextScale,
    )._clamped();
  }

  Offset _imagePointFor(Offset viewportPoint) {
    final safeScale = scale.isFinite && scale > 0 ? scale : minScale;
    return (viewportPoint - offset) / safeScale;
  }

  AvatarCropViewport _clamped() {
    final minimum = minScale;
    final safeScale = scale.isFinite && scale > 0
        ? scale.clamp(minimum, maxScale)
        : minimum;
    final scaledWidth = imageSize.width * safeScale;
    final scaledHeight = imageSize.height * safeScale;

    return AvatarCropViewport(
      imageSize: imageSize,
      viewportSize: viewportSize,
      scale: safeScale,
      offset: Offset(
        _clampOffset(offset.dx, scaledWidth),
        _clampOffset(offset.dy, scaledHeight),
      ),
    );
  }

  double _clampOffset(double value, double scaledSide) {
    if (!value.isFinite) {
      return scaledSide <= viewportSize ? (viewportSize - scaledSide) / 2 : 0;
    }

    if (scaledSide <= viewportSize) {
      return (viewportSize - scaledSide) / 2;
    }

    return value.clamp(viewportSize - scaledSide, 0.0);
  }

  static double _minScaleFor(Size imageSize, double viewportSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0 || viewportSize <= 0) {
      return 1;
    }

    return math.max(
      viewportSize / imageSize.width,
      viewportSize / imageSize.height,
    );
  }

  static Offset _centerOffset(
    Size imageSize,
    double viewportSize,
    double scale,
  ) {
    return Offset(
      (viewportSize - imageSize.width * scale) / 2,
      (viewportSize - imageSize.height * scale) / 2,
    );
  }
}
