import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/presentation/avatar_crop_viewport.dart';

void main() {
  const imageSize = Size(800, 600);
  const viewportSize = 360.0;

  test('initial viewport covers and centers image', () {
    final viewport = AvatarCropViewport.initial(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );

    expect(viewport.scale, closeTo(0.6, 0.001));
    expect(viewport.offset.dx, closeTo(-60, 0.001));
    expect(viewport.offset.dy, closeTo(0, 0.001));
    expect(viewport.zoom, closeTo(1, 0.001));
    expect(viewport.coversViewport, isTrue);
  });

  test('pan clamps offset inside viewport bounds', () {
    final viewport = AvatarCropViewport.initial(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );

    final leftClamped = viewport.panBy(const Offset(-1000, -1000));
    expect(leftClamped.offset.dx, closeTo(-120, 0.001));
    expect(leftClamped.offset.dy, closeTo(0, 0.001));
    expect(leftClamped.coversViewport, isTrue);

    final rightClamped = viewport.panBy(const Offset(1000, 1000));
    expect(rightClamped.offset.dx, closeTo(0, 0.001));
    expect(rightClamped.offset.dy, closeTo(0, 0.001));
    expect(rightClamped.coversViewport, isTrue);
  });

  test('zoom clamps to min and max zoom', () {
    final viewport = AvatarCropViewport.initial(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );

    expect(viewport.zoomTo(0.2).zoom, closeTo(avatarCropMinZoom, 0.001));
    expect(viewport.zoomTo(10).zoom, closeTo(avatarCropMaxZoom, 0.001));
  });

  test('zoom around focal point keeps image point under focus', () {
    final viewport = AvatarCropViewport.initial(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    const focalPoint = Offset(120, 180);
    final imagePointBefore = (focalPoint - viewport.offset) / viewport.scale;

    final zoomed = viewport.zoomAroundFocalPoint(
      startScale: viewport.scale,
      startOffset: viewport.offset,
      gestureScale: 2,
      focalPoint: focalPoint,
    );
    final imagePointAfter = (focalPoint - zoomed.offset) / zoomed.scale;

    expect(imagePointAfter.dx, closeTo(imagePointBefore.dx, 0.001));
    expect(imagePointAfter.dy, closeTo(imagePointBefore.dy, 0.001));
    expect(zoomed.zoom, closeTo(2, 0.001));
    expect(zoomed.coversViewport, isTrue);
  });

  test('crop rect maps viewport into image pixels', () {
    final viewport = AvatarCropViewport.initial(
      imageSize: imageSize,
      viewportSize: viewportSize,
    );

    final cropRect = viewport.cropRect;
    expect(cropRect.left, closeTo(100, 0.001));
    expect(cropRect.top, closeTo(0, 0.001));
    expect(cropRect.width, closeTo(600, 0.001));
    expect(cropRect.height, closeTo(600, 0.001));
  });
}
