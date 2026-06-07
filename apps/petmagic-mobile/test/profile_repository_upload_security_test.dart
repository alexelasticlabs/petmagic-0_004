import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

void main() {
  late Directory tempDir;
  late ProfileRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('petmagic-profile-test-');
    repository = ProfileRepository(
      dio: Dio(),
      sessionStorage: AuthSessionStorage(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('rejects missing avatar file without exposing local path', () async {
    final missingPath = '${tempDir.path}/missing-avatar.jpg';

    await expectLater(
      repository.uploadAvatar(missingPath),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.message,
              'message',
              'profile.action_failed',
            )
            .having(
              (error) => error.toString(),
              'toString',
              isNot(contains(tempDir.path)),
            ),
      ),
    );
  });

  test('rejects unsupported avatar extension before upload', () async {
    final file = await _createFile(tempDir, 'avatar.gif', sizeBytes: 128);

    await expectLater(
      repository.uploadAvatar(file.path),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'profile.action_failed',
        ),
      ),
    );
  });

  test('rejects oversized avatar before upload', () async {
    final file = await _createFile(
      tempDir,
      'avatar.jpg',
      sizeBytes: 8 * 1024 * 1024 + 1,
    );

    await expectLater(
      repository.uploadAvatar(file.path),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'profile.action_failed',
        ),
      ),
    );
  });

  test('rejects spoofed avatar content before upload', () async {
    final file = File('${tempDir.path}/spoofed-avatar.jpg');
    await file.writeAsBytes('%PDF-1.7 not an image'.codeUnits, flush: true);
    var didAttemptUpload = false;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            didAttemptUpload = true;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final repository = ProfileRepository(
      dio: dio,
      sessionStorage: AuthSessionStorage(),
    );

    await expectLater(
      repository.uploadAvatar(file.path),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'profile.action_failed',
        ),
      ),
    );

    expect(didAttemptUpload, isFalse);
  });

  test('uses async file size validation for avatar uploads', () {
    final source = File(
      'lib/features/profile/data/profile_repository.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('lengthSync(')));
    expect(source, contains('await File(filePath).length()'));
    expect(source, contains('await _detectAvatarMediaType(filePath)'));
    expect(source, contains('return detectedMediaType;'));
    expect(source, contains('await _validateAvatarForUpload('));
    expect(source, contains('authenticatedMultipartRequestOptions'));
  });
}

Future<File> _createFile(
  Directory directory,
  String name, {
  required int sizeBytes,
}) async {
  final file = File('${directory.path}/$name');
  final handle = await file.open(mode: FileMode.write);
  try {
    await handle.truncate(sizeBytes);
  } finally {
    await handle.close();
  }
  return file;
}
