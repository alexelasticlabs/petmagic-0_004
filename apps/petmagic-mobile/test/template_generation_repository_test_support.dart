import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

Future<void> safeDeleteTempDir(Directory dir) async {
  if (!await dir.exists()) return;
  for (var i = 0; i < 3; i++) {
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}

Future<File> writeTinyJpeg(Directory directory, String name) async {
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

Future<File> writeFtypImage(
  Directory directory,
  String name,
  String brand,
) async {
  assert(brand.length == 4);
  final file = File('${directory.path}/$name');
  final brandBytes = brand.codeUnits;
  await file.writeAsBytes([
    0x00,
    0x00,
    0x00,
    0x18,
    0x66,
    0x74,
    0x79,
    0x70,
    brandBytes[0],
    brandBytes[1],
    brandBytes[2],
    brandBytes[3],
    0x00,
    0x00,
    0x00,
    0x00,
  ], flush: true);
  return file;
}

ResponseBody jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> petPhotoJson() {
  return {
    'id': 'photo-1',
    'petId': 'pet-1',
    'mediaAssetId': 'asset-1',
    'url': 'https://cdn.petmagic.test/photo-1.jpg',
    'thumbnailUrl': 'https://cdn.petmagic.test/photo-1-thumb.jpg',
    'fileName': 'pet.jpg',
    'contentType': 'image/jpeg',
    'fileSizeBytes': 14,
    'isFavorite': false,
    'isAvatar': false,
    'sortOrder': 0,
    'createdAtUtc': '2026-06-14T12:00:00Z',
  };
}

Map<String, dynamic> petJson({String id = 'pet-1'}) {
  return {
    'id': id,
    'name': 'Bella',
    'type': 'dog',
    'photosCount': 1,
    'generationsCount': 0,
    'createdAtUtc': '2026-06-14T12:00:00Z',
    'updatedAtUtc': '2026-06-14T12:00:00Z',
  };
}

Map<String, dynamic> generationJson({
  required String generationId,
  required String status,
  required String updatedAtUtc,
  bool isUnread = true,
}) {
  return {
    'generationId': generationId,
    'userId': 'user-1',
    'templateId': 'template-1',
    'status': status,
    'tokenCost': 6,
    'attemptCount': 1,
    'createdAtUtc': '2026-06-14T12:00:00Z',
    'updatedAtUtc': updatedAtUtc,
    'userMediaExpired': false,
    'templateTitle': 'Realtime Active',
    'templateType': 'image',
    'isUnread': isUnread,
  };
}

AuthSession sessionFixture() {
  return sessionFixtureFor('user-1');
}

AuthSession sessionFixtureFor(String userId) {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: MobileUserProfile(
      userId: userId,
      email: '$userId@example.com',
      displayName: 'Pet Parent',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: legalAcceptanceFixture,
      roles: const ['user'],
      avatar: null,
    ),
  );
}

const legalAcceptanceFixture = MobileLegalAcceptanceStatus(
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

class TestSessionStorage extends AuthSessionStorage {
  TestSessionStorage(this.sessionFixture);

  final AuthSession sessionFixture;

  @override
  Future<AuthSession?> read() async => sessionFixture;
}

class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class FakeImageUploadOptimizer extends ImageUploadOptimizer {
  const FakeImageUploadOptimizer({this.petPhoto});

  final File? petPhoto;

  @override
  Future<OptimizedUploadFile> optimizeForPetPhoto(
    XFile source, {
    CancelToken? cancelToken,
  }) async {
    final file = petPhoto;
    if (file == null) {
      return OptimizedUploadFile.original(source);
    }

    return OptimizedUploadFile.original(
      XFile(file.path, name: 'optimized.jpg', mimeType: 'image/jpeg'),
    );
  }
}

String methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:Future<[^>]+>|String)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = methodOpenBraceIndex(source, methodMatch);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}

int methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return index;
    }
  }

  return -1;
}
