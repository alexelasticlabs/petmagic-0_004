import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support video recording requests microphone permission', () async {
    final source = await File(
      'lib/features/support/presentation/widgets/support_chat_actions_attachment_flow.part.dart',
    ).readAsString();

    final videoMethod = RegExp(
      r'Future<void> _pickCameraVideoAttachmentImpl\(\) async \{([\s\S]*?)_imagePicker\.pickVideo',
    ).firstMatch(source);

    expect(videoMethod, isNotNull);
    expect(videoMethod!.group(1), contains('AppPermissionType.camera'));
    expect(videoMethod.group(1), contains('AppPermissionType.microphone'));
  });

  test(
    'support mixed media pickers request photo and video permissions on Android',
    () async {
      final source = await File(
        'lib/features/support/presentation/widgets/support_chat_actions_attachment_flow.part.dart',
      ).readAsString();
      final pickerSource = await File(
        'lib/features/support/presentation/widgets/support_chat_attachment_picker.part.dart',
      ).readAsString();

      final filePickerMethod = RegExp(
        r'Future<void> _pickFileAttachmentsImpl\(\) async \{([\s\S]*?)final pickedFiles =',
      ).firstMatch(source);
      expect(filePickerMethod, isNotNull);
      expect(
        filePickerMethod!.group(1),
        contains('_requestMixedMediaGalleryPermission()'),
      );

      final recentPickerMethod = RegExp(
        r'Future<void> _initializeAssets\(\) async \{([\s\S]*?)PhotoManager\.requestPermissionExtend',
      ).firstMatch(pickerSource);
      expect(recentPickerMethod, isNotNull);
      expect(
        recentPickerMethod!.group(1),
        contains('_requestMixedMediaGalleryPermission()'),
      );

      final actionsHelperMatches = RegExp(
        r'Future<bool> _requestMixedMediaGalleryPermission\(\) async \{([\s\S]*?)\n  \}',
      ).allMatches(source).toList();
      final pickerHelperMatches = RegExp(
        r'Future<bool> _requestMixedMediaGalleryPermission\(\) async \{([\s\S]*?)\n  \}',
      ).allMatches(pickerSource).toList();
      final helperMatches = [...actionsHelperMatches, ...pickerHelperMatches];
      expect(helperMatches.length, greaterThanOrEqualTo(2));
      for (final helper in helperMatches) {
        final body = helper.group(1)!;
        expect(body, contains('AppPermissionType.photos'));
        expect(body, contains('Platform.isAndroid'));
        expect(body, contains('AppPermissionType.videos'));
      }
    },
  );

  test(
    'platform manifests declare microphone access for video recording',
    () async {
      final androidManifest = await File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      final iosInfo = await File('ios/Runner/Info.plist').readAsString();

      expect(androidManifest, contains('android.permission.RECORD_AUDIO'));
      expect(iosInfo, contains('NSMicrophoneUsageDescription'));
    },
  );
}
