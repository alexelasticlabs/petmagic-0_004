import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_avatar_cropper_page.dart';

void main() {
  testWidgets('initial crop viewport centers image and covers circle', (
    tester,
  ) async {
    final imageData = _createTestImageData();

    await _withPhoneSurface(tester, () async {
      await _pumpCropper(tester, imageData);

      final geometry = _imageGeometry(tester);
      expect(geometry.left, closeTo(-60, 0.001));
      expect(geometry.top, closeTo(0, 0.001));
      expect(geometry.width, closeTo(480, 0.001));
      expect(geometry.height, closeTo(360, 0.001));
      expect(_coversViewport(geometry), isTrue);
    });
  });

  testWidgets('slider zoom survives rebuild without resetting crop state', (
    tester,
  ) async {
    final imageData = _createTestImageData();

    await _withPhoneSurface(tester, () async {
      await _pumpCropper(tester, imageData);

      _setSliderValue(tester, 2.2);
      await tester.pumpAndSettle();

      final beforeRebuild = _imageGeometry(tester);

      await tester.pumpWidget(_buildHarness(imageData));
      await tester.pump();
      await _pumpFrames(tester);

      final afterRebuild = _imageGeometry(tester);
      expect(afterRebuild.left, closeTo(beforeRebuild.left, 0.001));
      expect(afterRebuild.top, closeTo(beforeRebuild.top, 0.001));
      expect(afterRebuild.width, closeTo(beforeRebuild.width, 0.001));
      expect(afterRebuild.height, closeTo(beforeRebuild.height, 0.001));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(2.2, 0.001),
      );
      expect(_coversViewport(afterRebuild), isTrue);
    });
  });

  testWidgets('pinch zoom does not reset image to top-left', (tester) async {
    final imageData = _createTestImageData();

    await _withPhoneSurface(tester, () async {
      await _pumpCropper(tester, imageData);

      final initial = _imageGeometry(tester);
      await _pinchZoom(tester);

      final transformed = _imageGeometry(tester);
      expect(transformed.width, greaterThan(initial.width * 1.1));
      expect(transformed.left, lessThan(-1));
      expect(transformed.top, lessThanOrEqualTo(0));
      expect(transformed.left.isFinite, isTrue);
      expect(transformed.top.isFinite, isTrue);
      expect(_coversViewport(transformed), isTrue);
    });
  });

  testWidgets('pinch pan slider and rebuild keep valid crop geometry', (
    tester,
  ) async {
    final imageData = _createTestImageData();

    await _withPhoneSurface(tester, () async {
      await _pumpCropper(tester, imageData);

      await _pinchZoom(tester);
      await _pan(tester, const Offset(-48, -26));
      _setSliderValue(tester, 1.8);
      await tester.pumpAndSettle();
      await tester.pumpWidget(_buildHarness(imageData));
      await tester.pump();
      await _pumpFrames(tester);

      final geometry = _imageGeometry(tester);
      expect(geometry.width, closeTo(864, 0.001));
      expect(geometry.left.isFinite, isTrue);
      expect(geometry.top.isFinite, isTrue);
      expect(_coversViewport(geometry), isTrue);
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(1.8, 0.001),
      );
    });
  });

  testWidgets('reset returns crop viewport to initial fit and center', (
    tester,
  ) async {
    final imageData = _createTestImageData();

    await _withPhoneSurface(tester, () async {
      await _pumpCropper(tester, imageData);
      await _pinchZoom(tester);
      await _pan(tester, const Offset(-40, -20));

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      final geometry = _imageGeometry(tester);
      expect(geometry.left, closeTo(-60, 0.001));
      expect(geometry.top, closeTo(0, 0.001));
      expect(geometry.width, closeTo(480, 0.001));
      expect(geometry.height, closeTo(360, 0.001));
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        closeTo(1, 0.001),
      );
    });
  });

  testWidgets('fit restores covered centered geometry after edits', (
    tester,
  ) async {
    final imageData = _createTestImageData();

    await _withPhoneSurface(tester, () async {
      await _pumpCropper(tester, imageData);
      _setSliderValue(tester, 3);
      await tester.pumpAndSettle();
      await _pan(tester, const Offset(160, 120));

      await tester.tap(find.text('Fit'));
      await tester.pumpAndSettle();

      final geometry = _imageGeometry(tester);
      expect(geometry.left, closeTo(-60, 0.001));
      expect(geometry.top, closeTo(0, 0.001));
      expect(geometry.width, closeTo(480, 0.001));
      expect(geometry.height, closeTo(360, 0.001));
      expect(_coversViewport(geometry), isTrue);
    });
  });
}

Future<void> _withPhoneSurface(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await body();
}

Future<void> _pumpCropper(
  WidgetTester tester,
  ProfileAvatarCropperDebugImageData imageData,
) async {
  await tester.pumpWidget(_buildHarness(imageData));
  await tester.pump();
  await _pumpFrames(tester, count: 8);
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int count = 4,
  Duration step = const Duration(milliseconds: 32),
}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(step);
  }
}

Widget _buildHarness(ProfileAvatarCropperDebugImageData imageData) {
  return MaterialApp(
    theme: AppTheme.dark(),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProfileAvatarCropperPage(
      sourceImagePath: 'test-avatar.jpg',
      debugImageData: imageData,
    ),
  );
}

void _setSliderValue(WidgetTester tester, double value) {
  final slider = tester.widget<Slider>(find.byType(Slider));
  expect(slider.onChanged, isNotNull);
  slider.onChanged!(value);
}

Future<void> _pinchZoom(WidgetTester tester) async {
  final center = tester.getCenter(find.byKey(profileAvatarCropViewportKey));
  final firstPointer = await tester.startGesture(
    center - const Offset(40, 0),
    pointer: 1,
  );
  final secondPointer = await tester.startGesture(
    center + const Offset(40, 0),
    pointer: 2,
  );

  await tester.pump(const Duration(milliseconds: 16));
  await firstPointer.moveBy(const Offset(-35, -18));
  await secondPointer.moveBy(const Offset(35, 18));
  await tester.pump(const Duration(milliseconds: 16));
  await firstPointer.moveBy(const Offset(-20, -10));
  await secondPointer.moveBy(const Offset(20, 10));
  await tester.pump(const Duration(milliseconds: 16));
  await firstPointer.up();
  await secondPointer.up();
  await _pumpFrames(tester);
}

Future<void> _pan(WidgetTester tester, Offset delta) async {
  await tester.drag(find.byKey(profileAvatarCropViewportKey), delta);
  await _pumpFrames(tester);
}

_ImageGeometry _imageGeometry(WidgetTester tester) {
  final positioned = tester.widget<Positioned>(
    find.byKey(profileAvatarCropImageKey),
  );
  return _ImageGeometry(
    left: positioned.left!,
    top: positioned.top!,
    width: positioned.width!,
    height: positioned.height!,
  );
}

bool _coversViewport(_ImageGeometry geometry) {
  const viewport = 360.0;
  return geometry.left <= 0 &&
      geometry.top <= 0 &&
      geometry.right >= viewport &&
      geometry.bottom >= viewport;
}

ProfileAvatarCropperDebugImageData _createTestImageData() {
  final image = img.Image(width: 800, height: 600);
  img.fill(image, color: img.ColorRgb8(210, 160, 110));
  final sourceBytes = img.encodeJpg(image, quality: 92);
  return ProfileAvatarCropperDebugImageData(
    sourceBytes: sourceBytes,
    previewBytes: sourceBytes,
    imageSize: const Size(800, 600),
  );
}

class _ImageGeometry {
  const _ImageGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;

  double get bottom => top + height;
}
