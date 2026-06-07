import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec pins tested minimums for build-sensitive packages', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final dependency in const {
      'cupertino_icons': '^1.0.9',
      'go_router': '^17.3.0',
      'google_fonts': '^6.3.3',
      'image_picker': '^1.2.2',
      'photo_manager': '^3.9.0',
      'share_plus': '^11.1.0',
      'in_app_purchase': '^3.3.0',
      'firebase_core': '^4.10.0',
      'firebase_messaging': '^16.3.0',
      'video_player_platform_interface': '^6.7.0',
    }.entries) {
      expect(
        pubspec,
        contains('${dependency.key}: ${dependency.value}'),
        reason:
            '${dependency.key} should not drift below the version covered by release gates.',
      );
    }
  });

  test('dependency surface excludes stale notification plugin lock entries', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();

    expect(pubspec, isNot(contains('flutter_local_notifications:')));
    expect(lockfile, isNot(contains('flutter_local_notifications')));
    expect(lockfile, isNot(contains('timezone')));
    expect(pubspec, isNot(contains('image_cropper:')));
    expect(lockfile, isNot(contains('image_cropper')));
    expect(
      pubspec,
      contains(
        'Flutter material/adaptive widgets can reference Cupertino icon glyphs',
      ),
    );
  });
}
