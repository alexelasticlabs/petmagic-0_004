import 'dart:io';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

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

    expect(uploadedFileName, 'photo.jpg');
    expect(uploadedFileName, isNot(contains('/private')));
    expect(uploadedFileName, isNot(contains('/')));
    expect(uploadedFileName, isNot(contains(r'\')));
  });

  test('bounds multipart attachment filename length before upload', () async {
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
      fileName: '${'private_user_pet_' * 20}.jpg',
      contentType: 'image/jpeg',
      localeTag: 'en',
    );

    expect(uploadedFileName, isNotNull);
    expect(uploadedFileName!.length, lessThanOrEqualTo(120));
    expect(uploadedFileName, endsWith('.jpg'));
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

  test('uploads support images from optimized temp payloads', () async {
    final source = await _createJpegFile(tempDir, 'source.jpg');
    final optimizedFile = await _createJpegFile(tempDir, 'optimized.jpg');

    String? uploadedFileName;
    String? uploadedContentType;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final formData = options.data as FormData;
            final file = formData.files.single.value;
            uploadedFileName = file.filename;
            uploadedContentType = file.contentType.toString();
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
      imageUploadOptimizer: _FakeImageUploadOptimizer(
        supportImage: optimizedFile,
      ),
    );

    await repository.sendAttachment(
      conversationId: 'conversation-1',
      filePath: source.path,
      fileName: 'source.bin',
      contentType: 'image/png',
      localeTag: 'en',
    );

    expect(uploadedFileName, 'optimized.jpg');
    expect(uploadedContentType, 'image/jpeg');
  });

  test(
    'rejects spoofed attachment before optimizer can replace payload',
    () async {
      final source = File('${tempDir.path}/source.jpg');
      await source.writeAsBytes('%PDF-1.7 not an image'.codeUnits, flush: true);
      final optimizedFile = await _createJpegFile(tempDir, 'optimized.jpg');
      final optimizer = _FakeImageUploadOptimizer(supportImage: optimizedFile);
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
        imageUploadOptimizer: optimizer,
      );

      await expectLater(
        repository.sendAttachment(
          conversationId: 'conversation-1',
          filePath: source.path,
          fileName: 'source.jpg',
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
      expect(optimizer.supportOptimizeCalls, 0);
    },
  );

  test(
    'encodes conversation and message IDs before using them as path segments',
    () async {
      final file = await _createJpegFile(tempDir, 'retry.jpg');
      const conversationId = 'conversation/../admin?x=1#frag';
      const messageId = 'message/../root?debug=true#frag';
      final encodedConversationId = Uri.encodeComponent(conversationId);
      final encodedMessageId = Uri.encodeComponent(messageId);
      final paths = <String>[];
      Object? feedbackPayload;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paths.add(options.path);
              if (options.path.endsWith('/feedback')) {
                feedbackPayload = options.data;
              }
              expect(
                options.headers[HttpHeaders.authorizationHeader],
                'Bearer access-token',
              );
              expect(options.path, isNot(contains(conversationId)));
              expect(options.path, isNot(contains(messageId)));
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.path.endsWith('/read')
                      ? const <String, dynamic>{}
                      : options.path.endsWith('/messages') ||
                            options.path.endsWith('/attachments') ||
                            options.path.endsWith('/messages/attachments') ||
                            options.path.endsWith('/attachment/retry')
                      ? _supportMessageJson()
                      : _supportConversationJson(),
                ),
              );
            },
          ),
        );
      final repository = SupportChatRepository(
        dio: dio,
        sessionStorage: _SessionStorage(_session()),
      );

      await repository.sendMessage(
        conversationId: conversationId,
        body: 'Need help',
        localeTag: 'en',
      );
      await repository.sendAttachment(
        conversationId: conversationId,
        filePath: file.path,
        fileName: 'retry.jpg',
        contentType: 'image/jpeg',
        localeTag: 'en',
      );
      await repository.sendAttachments(
        conversationId: conversationId,
        attachments: [
          SupportChatUploadAttachment(
            filePath: file.path,
            fileName: 'retry.jpg',
            contentType: 'image/jpeg',
          ),
        ],
        localeTag: 'en',
      );
      await repository.retryAttachment(
        conversationId: conversationId,
        messageId: messageId,
        filePath: file.path,
        fileName: 'retry.jpg',
        contentType: 'image/jpeg',
      );
      await repository.markConversationRead(conversationId);
      await repository.resolveConversation(conversationId);
      await repository.reopenConversation(conversationId);
      await repository.closeConversation(conversationId);
      await repository.submitFeedback(
        conversationId: conversationId,
        rating: 5,
        comment: '  Thanks for helping  ',
      );

      expect(paths, [
        '/api/support/conversation/$encodedConversationId/messages',
        '/api/support/conversation/$encodedConversationId/attachments',
        '/api/support/conversation/$encodedConversationId/messages/attachments',
        '/api/support/conversation/$encodedConversationId/messages/$encodedMessageId/attachment/retry',
        '/api/support/conversation/$encodedConversationId/read',
        '/api/support/conversation/$encodedConversationId/resolve',
        '/api/support/conversation/$encodedConversationId/reopen',
        '/api/support/conversation/$encodedConversationId/close',
        '/api/support/conversation/$encodedConversationId/feedback',
      ]);
      expect(feedbackPayload, {'rating': 5, 'comment': 'Thanks for helping'});
    },
  );

  test('conversation history page size is clamped before request', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            expect(
              options.headers[HttpHeaders.authorizationHeader],
              'Bearer access-token',
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: _supportConversationJson(),
              ),
            );
          },
        ),
      );
    final repository = SupportChatRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
    );

    await repository.getConversation(take: 1000);
    await repository.getConversation(take: 0);

    expect(requests, hasLength(2));
    expect(requests[0].queryParameters['take'], 100);
    expect(requests[1].queryParameters['take'], 1);
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

  test('sanitizes attachment content type before logging upload failures', () {
    final source = File(
      'lib/features/support/data/support_chat_repository.dart',
    ).readAsStringSync();

    expect(source, contains('_safeAttachmentContentTypeForLog(contentType)'));
    expect(source, contains('String _safeAttachmentContentTypeForLog('));
    expect(source, contains(r"RegExp(r'[\x00-\x1F\x7F]')"));
    expect(source, contains('normalized.substring(0, 80)'));
    expect(source, isNot(contains("context: {'contentType': contentType}")));
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

Map<String, dynamic> _supportConversationJson() {
  return {
    'conversationId': 'conversation-1',
    'status': 'Open',
    'priority': 'Normal',
    'source': 'MobileChat',
    'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'messages': const <Map<String, dynamic>>[],
    'adminUnreadCount': 0,
    'userUnreadCount': 0,
  };
}

class _SessionStorage extends AuthSessionStorage {
  _SessionStorage(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> read() async => _session;
}

class _FakeImageUploadOptimizer extends ImageUploadOptimizer {
  _FakeImageUploadOptimizer({this.supportImage});

  final File? supportImage;
  int supportOptimizeCalls = 0;

  @override
  Future<OptimizedUploadFile> optimizeForSupportImage(
    XFile source, {
    RequestCancellation? cancelToken,
  }) async {
    supportOptimizeCalls++;
    final file = supportImage;
    if (file == null) {
      return OptimizedUploadFile.original(source);
    }

    return OptimizedUploadFile.original(
      XFile(file.path, name: 'optimized.jpg', mimeType: 'image/jpeg'),
    );
  }
}
