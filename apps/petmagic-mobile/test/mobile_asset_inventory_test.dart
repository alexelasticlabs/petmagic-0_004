import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile runtime asset declarations stay intentional', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pubspecLines = pubspec.split('\n').map((line) => line.trim());

    expect(pubspec, contains('- assets/auth/'));
    expect(pubspec, contains('- assets/branding/premium-hero-dark.png'));
    expect(pubspec, contains('- assets/branding/premium-hero-light.png'));
    expect(pubspecLines, isNot(contains('- assets/branding/')));
    expect(pubspec, contains('family: Comfortaa'));
    expect(pubspec, contains('- assets/rewards/'));
    expect(pubspec, contains('image_path: "assets/icons/app_icon.png"'));

    for (final path in _expectedRuntimeAssets) {
      expect(File(path).existsSync(), isTrue, reason: '$path must exist');
    }

    expect(
      File('assets/branding/petmagic-app-icon-1024.png').existsSync(),
      isTrue,
      reason: 'brand source icon is retained for icon generation scripts',
    );
  });

  test(
    'bundled Comfortaa family covers every application typography weight',
    () {
      final source = _readDartSources();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(source, isNot(contains('GoogleFonts.')));
      expect(source, contains("static const fontFamily = 'Comfortaa';"));
      expect(source, contains('fontFamily: resolvedFontFamily'));
      expect(pubspec, isNot(contains('google_fonts:')));

      for (final path in _comfortaaFontAssets) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
      expect(pubspec, contains('- asset: assets/fonts/Comfortaa-Regular.ttf'));
      expect(
        RegExp(r'^\s+weight:', multiLine: true).allMatches(pubspec),
        isEmpty,
        reason: 'Comfortaa is bundled as one variable font.',
      );
    },
  );

  test(
    'image assets have explicit runtime references or documented tooling use',
    () {
      final source = _readDartSources();
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final iconScript = File(
        '../../scripts/generate-brand-icons.ps1',
      ).readAsStringSync();

      for (final assetPath in _referencedImageAssets) {
        expect(source, contains(assetPath), reason: '$assetPath is referenced');
      }

      expect(pubspec, contains('assets/icons/app_icon.png'));
      expect(iconScript, contains('assets/icons/app_icon.png'));
      expect(
        iconScript,
        contains('assets/branding/petmagic-app-icon-1024.png'),
      );
    },
  );
}

const _comfortaaFontAssets = ['assets/fonts/Comfortaa-Regular.ttf'];

const _referencedImageAssets = [
  'assets/auth/petmagic-auth-hero.png',
  'assets/branding/premium-hero-dark.png',
  'assets/branding/premium-hero-light.png',
  'assets/rewards/invite-friend.png',
  'assets/rewards/powspark-empty-cat.png',
  'assets/rewards/premium-crown.png',
  'assets/rewards/premium-upsell-dog.png',
  'assets/rewards/profile-premium-dog.png',
  'assets/rewards/wallet-hero-logo.png',
  'assets/rewards/wallet-pack-chest.png',
  'assets/rewards/wallet-pack-coffee.png',
  'assets/rewards/wallet-pack-suitcase.png',
];

const _expectedRuntimeAssets = [
  ..._comfortaaFontAssets,
  ..._referencedImageAssets,
];

String _readDartSources() {
  final buffer = StringBuffer();
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      buffer.writeln(entity.readAsStringSync());
    }
  }
  return buffer.toString();
}
