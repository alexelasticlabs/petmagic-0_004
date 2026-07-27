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
        .where((file) => file.path.endsWith('Contents.json'))
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

  test('iOS deployment target stays compatible with Firebase SPM plugins', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    final debugConfig = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
    final releaseConfig = File(
      'ios/Flutter/Release.xcconfig',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(podfile, contains("platform :ios, '15.0'"));
    expect(debugConfig, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0'));
    expect(releaseConfig, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0'));
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 13\.0;').hasMatch(project),
      isFalse,
    );
  });

  test('iOS release path injects Firebase config instead of tracking it', () {
    final trackedFirebaseConfig = Process.runSync('git', [
      'ls-files',
      '--error-unmatch',
      'ios/Runner/GoogleService-Info.plist',
    ]);
    expect(trackedFirebaseConfig.exitCode, isNot(0));
    expect(
      File('ios/Runner/GoogleService-Info.plist.example').existsSync(),
      isTrue,
    );
    expect(File('tool/configure_firebase_smoke.dart').existsSync(), isTrue);

    for (final flavor in const ['staging', 'production']) {
      final scheme = File(
        'ios/Runner.xcodeproj/xcshareddata/xcschemes/$flavor.xcscheme',
      ).readAsStringSync();
      expect(scheme, contains('Placeholder Firebase plist is forbidden'));
      expect(scheme, contains('PETMAGIC_ALLOW_PLACEHOLDER_FIREBASE'));
      expect(scheme, contains('/usr/libexec/PlistBuddy'));
      final expectedBundleId = flavor == 'staging'
          ? 'com.petmagic.app.staging'
          : 'com.petmagic.app';
      expect(
        scheme,
        contains(
          'if [ &quot;\$BUNDLE_ID&quot; != &quot;$expectedBundleId&quot; ]',
        ),
      );
    }
  });

  test('iOS Runner bundles a valid privacy manifest contract', () {
    final manifest = File('ios/Runner/PrivacyInfo.xcprivacy');
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(manifest.existsSync(), isTrue);
    final plist = manifest.readAsStringSync();
    expect(plist, contains('<key>NSPrivacyTracking</key>'));
    expect(plist, contains('<false/>'));
    expect(plist, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    expect(plist, contains('<string>C617.1</string>'));
    expect(plist, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    expect(plist, contains('<string>CA92.1</string>'));
    expect(plist, contains('NSPrivacyCollectedDataTypePhotosorVideos'));
    expect(plist, contains('NSPrivacyCollectedDataTypeCustomerSupport'));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
  });

  test('mobile release configuration allows portrait and landscape', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(mainSource, isNot(contains('setPreferredOrientations')));
    expect(androidManifest, isNot(contains('screenOrientation')));
    expect(infoPlist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(infoPlist, contains('UIInterfaceOrientationLandscapeRight'));
  });

  test(
    'native deep-link schemes are isolated by staging and production flavor',
    () {
      final androidGradle = File(
        'android/app/build.gradle.kts',
      ).readAsStringSync();
      final androidManifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(
        androidManifest,
        contains(r'android:scheme="${appDeepLinkScheme}"'),
      );
      expect(
        androidManifest,
        contains(r'android:scheme="${stripeRedirectScheme}"'),
      );
      expect(
        androidGradle,
        contains('"appDeepLinkScheme"] = "petmagic-staging"'),
      );
      expect(androidGradle, contains('"appDeepLinkScheme"] = "petmagic"'));
      expect(
        androidGradle,
        contains('"stripeRedirectScheme"] = "petmagicstripe-staging"'),
      );
      expect(infoPlist, contains(r'<string>$(APP_DEEP_LINK_SCHEME)</string>'));
      expect(
        infoPlist,
        contains(r'<string>$(STRIPE_REDIRECT_SCHEME)</string>'),
      );
      expect(project, contains('APP_DEEP_LINK_SCHEME = "petmagic-staging";'));
      expect(project, contains('APP_DEEP_LINK_SCHEME = petmagic;'));
      expect(
        project,
        contains('STRIPE_REDIRECT_SCHEME = "petmagicstripe-staging";'),
      );
      expect(project, contains('STRIPE_REDIRECT_SCHEME = petmagicstripe;'));
    },
  );
}
