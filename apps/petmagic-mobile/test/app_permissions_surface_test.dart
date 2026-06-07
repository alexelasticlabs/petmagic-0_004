import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'permission coordinator does not expose unused storage permission',
    () async {
      final source = await File(
        'lib/core/permissions/app_permission_coordinator.dart',
      ).readAsString();

      expect(source, isNot(contains('AppPermissionType.files')));
      expect(source, isNot(contains('Permission.storage')));
      expect(source, contains('AppPermissionType.videos'));
      expect(source, contains('Permission.videos'));
      expect(
        source,
        contains(
          'await check(AppPermissionType.microphone),\n'
          '      await check(AppPermissionType.photos),\n'
          '      await check(AppPermissionType.videos),',
        ),
      );
    },
  );

  test(
    'android manifest keeps permission surface scoped to app flows',
    () async {
      final manifest = await File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsString();

      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.CAMERA'));
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
      expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
      expect(manifest, contains('android.permission.READ_MEDIA_VIDEO'));
      expect(manifest, contains('android:maxSdkVersion="32"'));
      expect(
        manifest,
        contains(
          '<uses-feature\n'
          '        android:name="android.hardware.camera"\n'
          '        android:required="false"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-feature\n'
          '        android:name="android.hardware.microphone"\n'
          '        android:required="false"/>',
        ),
      );

      expect(
        manifest,
        isNot(contains('android.permission.WRITE_EXTERNAL_STORAGE')),
      );
      expect(
        manifest,
        isNot(contains('android.permission.ACCESS_FINE_LOCATION')),
      );
      expect(
        manifest,
        isNot(contains('android.permission.ACCESS_COARSE_LOCATION')),
      );
      expect(manifest, isNot(contains('android.permission.READ_CONTACTS')));
      expect(manifest, isNot(contains('android.permission.READ_CALENDAR')));
      expect(manifest, isNot(contains('com.yalantis.ucrop.UCropActivity')));
    },
  );
}
