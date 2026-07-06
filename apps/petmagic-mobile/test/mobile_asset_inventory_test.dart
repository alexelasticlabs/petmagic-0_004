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
    expect(pubspec, contains('- assets/fonts/'));
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
    'offline Comfortaa font assets cover every GoogleFonts weight in use',
    () {
      final source = _readDartSources();

      expect(
        source,
        contains('GoogleFonts.config.allowRuntimeFetching = false;'),
      );
      expect(source, contains('GoogleFonts.comfortaaTextTheme(base)'));
      expect(source, contains('GoogleFonts.comfortaa('));

      for (final path in _comfortaaFontAssets) {
        expect(File(path).existsSync(), isTrue, reason: '$path must exist');
      }
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

const _comfortaaFontAssets = [
  'assets/fonts/Comfortaa-Light.ttf',
  'assets/fonts/Comfortaa-Regular.ttf',
  'assets/fonts/Comfortaa-Medium.ttf',
  'assets/fonts/Comfortaa-SemiBold.ttf',
  'assets/fonts/Comfortaa-Bold.ttf',
];

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
