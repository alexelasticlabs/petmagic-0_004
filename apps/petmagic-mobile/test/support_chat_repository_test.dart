import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';

void main() {
  late Directory tempDir;
  late SupportChatRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('petmagic-support-test-');
    repository = SupportChatRepository(
      dio: Dio(),
      sessionStorage: AuthSessionStorage(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('rejects unsupported attachment content type before upload', () async {
    final file = await _createFile(tempDir, 'document.pdf', sizeBytes: 128);

    await expectLater(
      repository.sendAttachment(
        conversationId: 'conversation-1',
        filePath: file.path,
        fileName: 'document.pdf',
        contentType: 'application/pdf',
        localeTag: 'en',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'support.attachment_content_type_not_allowed',
        ),
      ),
    );
  });

  test('rejects oversized image before upload', () async {
    final file = await _createFile(
      tempDir,
      'photo.jpg',
      sizeBytes: 10 * 1024 * 1024 + 1,
    );

    await expectLater(
      repository.sendAttachment(
        conversationId: 'conversation-1',
        filePath: file.path,
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
        localeTag: 'en',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'support.attachment_file_too_large',
        ),
      ),
    );
  });

  test('rejects missing attachment file before upload', () async {
    await expectLater(
      repository.sendAttachment(
        conversationId: 'conversation-1',
        filePath: '${tempDir.path}/missing.jpg',
        fileName: 'missing.jpg',
        contentType: 'image/jpeg',
        localeTag: 'en',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'support.attachment_invalid_upload',
        ),
      ),
    );
  });

  test('rejects too many attachments before upload', () async {
    final attachments = List<SupportChatUploadAttachment>.generate(
      6,
      (index) => SupportChatUploadAttachment(
        filePath: '${tempDir.path}/photo-$index.jpg',
        fileName: 'photo-$index.jpg',
        contentType: 'image/jpeg',
      ),
    );

    await expectLater(
      repository.sendAttachments(
        conversationId: 'conversation-1',
        attachments: attachments,
        localeTag: 'en',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'support.attachment_too_many',
        ),
      ),
    );
  });

  test('sanitizes multipart attachment filename before upload', () async {
    final file = await _createJpegFile(tempDir, 'photo.jpg');
    String? uploadedFileName;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final formData = options.data as FormData;
            uploadedFileName = formData.files.single.value.filename;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: _supportMessageJson(),
              ),
            );
          },
        ),
      );
    final repository = SupportChatRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
    );

    await repository.sendAttachment(
      conversationId: 'conversation-1',
      filePath: file.path,
      fileName: '/private/user/pet photo.jpg',
      contentType: 'image/jpeg',
      localeTag: 'en',
    );

    expect(uploadedFileName, 'pet_photo.jpg');
    expect(uploadedFileName, isNot(contains('/private')));
    expect(uploadedFileName, isNot(contains('/')));
    expect(uploadedFileName, isNot(contains(r'\')));
  });

  test('rejects spoofed attachment content before upload', () async {
    final file = File('${tempDir.path}/spoofed-photo.jpg');
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
    final repository = SupportChatRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
    );

    await expectLater(
      repository.sendAttachment(
        conversationId: 'conversation-1',
        filePath: file.path,
        fileName: 'spoofed-photo.jpg',
        contentType: 'image/jpeg',
        localeTag: 'en',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'support.attachment_content_type_not_allowed',
        ),
      ),
    );

    expect(didAttemptUpload, isFalse);
  });

  test(
    'uses async file APIs for attachment upload validation and multipart',
    () {
      final source = File(
        'lib/features/support/data/support_chat_repository.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('lengthSync(')));
      expect(source, isNot(contains('MultipartFile.fromFileSync')));
      expect(source, contains('await File(filePath).length()'));
      expect(source, contains('await MultipartFile.fromFile('));
      expect(source, contains('authenticatedMultipartRequestOptions'));
      expect(
        source,
        contains("query['beforeMessageId'] = beforeMessageId!.trim();"),
      );
    },
  );
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

Future<File> _createJpegFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(const [
    0xFF,
    0xD8,
    0xFF,
    0xE0,
    0x00,
    0x10,
    0x4A,
    0x46,
    0x49,
    0x46,
    0x00,
    0x01,
    0xFF,
    0xD9,
  ], flush: true);
  return file;
}

AuthSession _session() {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: const MobileUserProfile(
      userId: 'user-1',
      email: 'pet@example.com',
      displayName: 'Pet Parent',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: _legalAcceptance,
      roles: ['user'],
      avatar: null,
    ),
  );
}

const _legalAcceptance = MobileLegalAcceptanceStatus(
  termsOfUseAccepted: true,
  termsOfUseAcceptedVersion: '2026-05-20',
  termsOfUseAcceptedAtUtc: null,
  privacyPolicyAccepted: true,
  privacyPolicyAcceptedVersion: '2026-05-20',
  privacyPolicyAcceptedAtUtc: null,
  currentTermsOfUseVersion: '2026-05-20',
  currentPrivacyPolicyVersion: '2026-05-20',
  requiresAcceptance: false,
);

Map<String, dynamic> _supportMessageJson() {
  return {
    'messageId': 'message-1',
    'conversationId': 'conversation-1',
    'senderUserId': 'user-1',
    'senderDisplayName': 'Pet Parent',
    'isFromAdmin': false,
    'senderType': 'User',
    'body': '',
    'isRead': false,
    'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    'attachments': const <Map<String, dynamic>>[],
  };
}

class _SessionStorage extends AuthSessionStorage {
  _SessionStorage(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> read() async => _session;
}
