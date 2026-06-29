import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec pins tested minimums for build-sensitive packages', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final dependency in const {
      'cupertino_icons': '^1.0.9',
      'go_router': '^17.3.0',
      'google_fonts': '^8.1.0',
      'image_picker': '^1.2.2',
      'share_plus': '^13.2.0',
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

    expect(pubspec, contains('photo_manager:'));
    expect(
      pubspec,
      contains('path: third_party/flutter_plugins/photo_manager'),
    );
  });

  test('dependency surface excludes stale notification plugin lock entries', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();

    for (final package in const {
      'flutter_local_notifications',
      'timezone',
      'image_cropper',
      'camera',
      'webview_flutter',
      'flutter_inappwebview',
      'geolocator',
      'location',
      'contacts_service',
      'flutter_contacts',
      'device_info_plus',
      'package_info_plus',
      'sensors_plus',
      'flutter_blue_plus',
    }) {
      expect(
        pubspec,
        isNot(contains('$package:')),
        reason: '$package should not be a direct dependency.',
      );
      expect(
        lockfile,
        isNot(contains('name: $package')),
        reason: '$package should not enter the resolved dependency graph.',
      );
    }

    expect(
      pubspec,
      contains(
        'Flutter material/adaptive widgets can reference Cupertino icon glyphs',
      ),
    );
  });

  test('runtime dependencies are used by app code or explicitly justified', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final runtimeDependencies = _directRuntimeDependencies(pubspec);
    final appSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    const sdkDependencies = {'flutter', 'flutter_localizations'};
    const justifiedWithoutDirectImport = {
      'cupertino_icons':
          'Material/adaptive widgets can reference Cupertino glyphs in release builds.',
    };

    final staleDependencies = <String>[];
    for (final dependency in runtimeDependencies) {
      if (sdkDependencies.contains(dependency) ||
          justifiedWithoutDirectImport.containsKey(dependency)) {
        continue;
      }

      if (!appSource.contains('package:$dependency/')) {
        staleDependencies.add(dependency);
      }
    }

    expect(
      staleDependencies,
      isEmpty,
      reason:
          'Direct runtime dependencies must be imported by lib/ code or have an explicit justification.',
    );
  });
}

Set<String> _directRuntimeDependencies(String pubspec) {
  final dependenciesHeader = RegExp(
    r'^dependencies:\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  final devDependenciesHeader = RegExp(
    r'^dev_dependencies:\s*$',
    multiLine: true,
  ).firstMatch(pubspec);

  if (dependenciesHeader == null || devDependenciesHeader == null) {
    fail('pubspec.yaml must contain dependencies and dev_dependencies blocks.');
  }

  final dependenciesBlock = pubspec.substring(
    dependenciesHeader.end,
    devDependenciesHeader.start,
  );

  return RegExp(
    r'^  ([A-Za-z0-9_]+):',
    multiLine: true,
  ).allMatches(dependenciesBlock).map((match) => match.group(1)!).toSet();
}
