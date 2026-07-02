import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void configureGenerationGalleryStoreTestHarness() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
}

const tinyJpegOne = [
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
];

const tinyJpegTwo = [
  0xFF,
  0xD8,
  0xFF,
  0xE1,
  0x00,
  0x10,
  0x45,
  0x78,
  0x69,
  0x66,
  0x00,
  0x00,
  0xFF,
  0xD9,
];

const tinyMp4 = [
  0x00,
  0x00,
  0x00,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x69,
  0x73,
  0x6F,
  0x6D,
  0x00,
  0x00,
  0x00,
  0x00,
];

GenerationGalleryStore buildGenerationGalleryStore(
  Directory rootDirectory, {
  Dio? dio,
  SharedPreferencesAsync? preferences,
  AuthSession? session,
  bool useDefaultSession = true,
  int maxBackgroundMaterializationsPerSession = 12,
  int maxBackgroundVideoOutputsPerSession = 0,
  int maxBackgroundBytesPerSession = 64 * 1024 * 1024,
  int maxBackgroundFileBytes = 32 * 1024 * 1024,
  int maxGalleryCacheBytesPerScope = 256 * 1024 * 1024,
  int maxMaterializationRetryCount = 3,
  Duration materializationRetryBaseBackoff = const Duration(minutes: 15),
  DateTime Function()? clock,
}) {
  return GenerationGalleryStore(
    dio: dio ?? Dio(),
    preferences: preferences ?? SharedPreferencesAsync(),
    sessionStorage: _InMemoryAuthSessionStorage(
      useDefaultSession ? (session ?? sessionForUser()) : session,
    ),
    rootDirectoryResolver: () async => rootDirectory,
    maxBackgroundMaterializationsPerSession:
        maxBackgroundMaterializationsPerSession,
    maxBackgroundVideoOutputsPerSession: maxBackgroundVideoOutputsPerSession,
    maxBackgroundBytesPerSession: maxBackgroundBytesPerSession,
    maxBackgroundFileBytes: maxBackgroundFileBytes,
    maxGalleryCacheBytesPerScope: maxGalleryCacheBytesPerScope,
    maxMaterializationRetryCount: maxMaterializationRetryCount,
    materializationRetryBaseBackoff: materializationRetryBaseBackoff,
    clock: clock,
  );
}

Directory generationDirectoryForTest(
  Directory rootDirectory,
  String accountScope,
  String generationId,
) {
  final scopeSegment = sha256
      .convert(utf8.encode(accountScope.trim().toLowerCase()))
      .toString();
  return Directory(
    '${rootDirectory.path}${Platform.pathSeparator}'
    'generation_gallery${Platform.pathSeparator}'
    'scope_$scopeSegment${Platform.pathSeparator}$generationId',
  );
}

TemplateGenerationResult completedGenerationForTest({
  String generationId = 'generation-1',
  String userId = 'user-1',
  DateTime? updatedAtUtc,
  String? templateType,
  String? resultPreviewUrl,
  String? outputUrl,
}) {
  final timestamp = updatedAtUtc ?? DateTime.utc(2035);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: userId,
    templateId: 'template-1',
    status: TemplateGenerationStatus.completed,
    tokenCost: 1,
    attemptCount: 1,
    createdAtUtc: timestamp,
    updatedAtUtc: timestamp,
    userMediaExpired: false,
    templateTitle: 'Magic portrait',
    templateType: templateType ?? 'image',
    resultPreviewUrl: resultPreviewUrl,
    outputUrl: outputUrl ?? 'https://cdn.petmagic.example/$generationId.jpg',
  );
}

AuthSession sessionForUser([String userId = 'user-1']) {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.utc(2035),
    user: MobileUserProfile(
      userId: userId,
      email: 'pet@example.com',
      displayName: 'Pet Parent',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: '1',
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: '1',
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: '1',
        currentPrivacyPolicyVersion: '1',
        requiresAcceptance: false,
      ),
      roles: ['User'],
      avatar: null,
    ),
  );
}

class _InMemoryAuthSessionStorage extends AuthSessionStorage {
  _InMemoryAuthSessionStorage(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;
}
