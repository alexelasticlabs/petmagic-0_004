import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS asset catalog build settings use valid boolean values', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final values =
        RegExp(
              r'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS\s*=\s*([^;]+);',
            )
            .allMatches(project)
            .map((match) => match.group(1)?.trim())
            .whereType<String>()
            .toList();
    final invalidValues = values
        .where((value) => value != 'YES' && value != 'NO')
        .toList();

    expect(values, isNotEmpty);
    expect(invalidValues, isEmpty);
    expect(
      project,
      isNot(
        contains(
          'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;',
        ),
      ),
    );
  });

  test('iOS asset catalog json files remain valid', () {
    final contentsFiles = Directory('ios/Runner/Assets.xcassets')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('/Contents.json'))
        .toList();

    expect(contentsFiles, isNotEmpty);
    for (final file in contentsFiles) {
      expect(() => jsonDecode(file.readAsStringSync()), returnsNormally);
    }
  });

  test('iOS Runner target enables required app entitlements', () {
    final entitlements = File('ios/Runner/Runner.entitlements');
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(entitlements.existsSync(), isTrue);
    final plist = entitlements.readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('aps-environment'));
    expect(plist, contains('<string>\$(APS_ENVIRONMENT)</string>'));
    expect(plist, contains('com.apple.developer.applesignin'));
    expect(plist, contains('<string>Default</string>'));
    expect(infoPlist, contains('<key>UIBackgroundModes</key>'));
    expect(infoPlist, contains('<string>remote-notification</string>'));
    expect(
      project,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
    expect(
      File('ios/Flutter/Debug.xcconfig').readAsStringSync(),
      contains('APS_ENVIRONMENT = development'),
    );
    expect(
      File('ios/Flutter/Release.xcconfig').readAsStringSync(),
      contains('APS_ENVIRONMENT = production'),
    );
  });
}
