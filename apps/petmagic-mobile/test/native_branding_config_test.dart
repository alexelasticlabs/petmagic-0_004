import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launcher icon uses a dedicated adaptive foreground asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final foreground = File('assets/icons/app_icon_foreground.png');

    expect(
      pubspec,
      contains(
        'adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"',
      ),
    );
    expect(pubspec, contains('adaptive_icon_background: "#4B21D1"'));
    expect(foreground.existsSync(), isTrue);
    expect(foreground.lengthSync(), greaterThan(10 * 1024));
    expect(foreground.readAsBytesSync().take(8).toList(), <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
  });

  test('Android launch resources cover legacy, dark and Android 12', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final adaptiveIcon = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    final android12Styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    final android12DarkStyles = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    ).readAsStringSync();

    expect(pubspec, contains('flutter_native_splash:'));
    expect(pubspec, contains('color_dark: "#090A12"'));
    expect(adaptiveIcon, contains('@drawable/ic_launcher_foreground'));
    expect(adaptiveIcon, contains('@color/ic_launcher_background'));
    expect(android12Styles, contains('@drawable/android12splash'));
    expect(android12DarkStyles, contains('@drawable/android12splash'));
    expect(
      File(
        'android/app/src/main/res/drawable-night/launch_background.xml',
      ).existsSync(),
      isTrue,
    );
  });

  test('iOS launch storyboard references non-empty branded assets', () {
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();
    final launchImages = <String>[
      'LaunchImage.png',
      'LaunchImage@2x.png',
      'LaunchImage@3x.png',
    ];

    expect(storyboard, contains('image="LaunchBackground"'));
    expect(storyboard, contains('image="LaunchImage"'));
    for (final name in launchImages) {
      final image = File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/$name',
      );
      expect(image.existsSync(), isTrue, reason: '$name must exist');
      expect(
        image.lengthSync(),
        greaterThan(1024),
        reason: '$name must contain a real branded image',
      );
    }
  });
}
