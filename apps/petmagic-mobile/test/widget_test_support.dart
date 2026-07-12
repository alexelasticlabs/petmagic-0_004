import 'dart:convert';
import 'dart:io';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

void configureWidgetTestHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await _loadMaterialIconsForGoldenTests();
  });
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() {
    PetMagicNotificationCenter.instance.clearQueue();
  });
}

Future<void> _loadMaterialIconsForGoldenTests() async {
  var flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.trim().isEmpty) {
    var directory = File(Platform.resolvedExecutable).parent;
    for (var index = 0; index < 4; index++) {
      directory = directory.parent;
    }
    flutterRoot = directory.path;
  }

  final font = File(
    '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
    '${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts'
    '${Platform.pathSeparator}MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) {
    return;
  }
  final bytes = await font.readAsBytes();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

GoRouter testRouter(Widget home) {
  return GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
}

Future<void> pumpTestApp(
  WidgetTester tester, {
  Map<String, Object> sharedPrefs = const {},
  TemplatesRepository? repository,
  ProfileRepository? profileRepository,
  ExternalAuthRepository? externalAuthRepository,
  AppLaunchController Function()? appLaunchController,
  Size surfaceSize = const Size(1080, 1920),
  double textScaleFactor = 1.0,
}) async {
  final view = tester.view;
  view.physicalSize = surfaceSize;
  view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;

  final sharedPrefsWithoutSession = Map<String, Object>.from(sharedPrefs)
    ..remove(sessionKey);
  SharedPreferences.setMockInitialValues(sharedPrefsWithoutSession);

  final authStorage = TestAuthSessionStorage(
    rawSessionJson: sharedPrefs[sessionKey] is String
        ? sharedPrefs[sessionKey] as String
        : null,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWith(
          (ref) => Dio(BaseOptions(baseUrl: 'https://petmagic.test')),
        ),
        authSessionStorageProvider.overrideWith((ref) => authStorage),
        templatesRepositoryProvider.overrideWith(
          (ref) => repository ?? FakeTemplatesRepository(),
        ),
        templateGenerationControllerProvider.overrideWith(
          IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          IdleGenerationHistoryController.new,
        ),
        templateGenerationRepositoryProvider.overrideWith(
          (ref) => RouterTemplateGenerationRepository(),
        ),
        supportChatRepositoryProvider.overrideWith(
          (ref) => ref.watch(dioSupportRepositoryProvider),
        ),
        walletRepositoryProvider.overrideWith(
          (ref) => ref.watch(dioWalletRepositoryProvider),
        ),
        walletControllerProvider.overrideWith(IdleWidgetWalletController.new),
        profileRepositoryProvider.overrideWith(
          (ref) => profileRepository ?? FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => externalAuthRepository ?? FakeExternalAuthRepository(),
        ),
        if (appLaunchController != null)
          appLaunchControllerProvider.overrideWith(appLaunchController),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
      ],
      child: const PetMagicApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));

  addTearDown(() async {
    await PetMagicNotificationCenter.instance.clearQueue();
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> pumpTestFrames(
  WidgetTester tester, {
  int count = 8,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(step);
  }
}

class IdleTemplateGenerationController extends TemplateGenerationController {
  @override
  TemplateGenerationState build() {
    return const TemplateGenerationState();
  }
}

class IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {}

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {}

  @override
  Future<void> markRead(String generationId) async {}
}

class TrackingGenerationHistoryController
    extends IdleGenerationHistoryController {
  final List<bool> screenVisibilityCalls = [];
  final List<({GenerationHistoryFilter? filter, bool refresh})> loadCalls = [];

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {
    screenVisibilityCalls.add(visible);
  }

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    loadCalls.add((filter: filter, refresh: refresh));
  }
}

class ThrowingGuestLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: false,
      guestSessionReady: false,
    );
  }

  @override
  Future<void> continueAsGuest() async {
    throw StateError('guest launch failed');
  }

  @override
  Future<void> markOnboardingSeen() async {
    throw StateError('onboarding save failed');
  }
}

class AuthenticatedWidgetAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class IdleWidgetWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

String buildSessionJson() {
  return jsonEncode(
    AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: const MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet Parent',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: sampleLegalAcceptance,
        roles: ['user'],
        avatar: null,
      ),
    ).toJson(),
  );
}

class TestAuthSessionStorage extends AuthSessionStorage {
  TestAuthSessionStorage({String? rawSessionJson})
    : _session = _deserialize(rawSessionJson);

  AuthSession? _session;

  static AuthSession? _deserialize(String? rawSessionJson) {
    if (rawSessionJson == null || rawSessionJson.isEmpty) {
      return null;
    }

    try {
      return AuthSession.fromJson(
        jsonDecode(rawSessionJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

const sampleLegalAcceptance = MobileLegalAcceptanceStatus(
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

const sampleLegalDocuments = MobileLegalDocuments(
  termsOfUse: MobileLegalDocument(
    kind: 'terms-of-use',
    title: 'Terms',
    version: '2026-05-20',
    publishedAtUtc: null,
    summary: 'Terms summary',
    sections: [
      MobileLegalDocumentSection(
        heading: 'General',
        paragraphs: ['Terms paragraph'],
      ),
    ],
  ),
  privacyPolicy: MobileLegalDocument(
    kind: 'privacy-policy',
    title: 'Privacy',
    version: '2026-05-20',
    publishedAtUtc: null,
    summary: 'Privacy summary',
    sections: [
      MobileLegalDocumentSection(
        heading: 'Privacy',
        paragraphs: ['Privacy paragraph'],
      ),
    ],
  ),
);

const sessionKey = AuthSessionStorage.sessionKey;
const onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';

const sampleTemplate = TemplateItem(
  templateId: 'template-1',
  templateType: TemplateType.image,
  title: 'Magic Studio',
  shortDescription: 'Turn your pet into a star.',
  petPhotoRequirements: ['One pet in the photo', 'Clear face'],
  category: 'Magic',
  tags: ['funny', 'sparkle'],
  isPremium: false,
  tokenCost: 12,
);

class FakeTemplatesRepository implements TemplatesRepository {
  const FakeTemplatesRepository({this.items = const []});

  final List<TemplateItem> items;

  @override
  Future<List<String>> fetchCategories() async => const ['Magic'];

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async =>
      null;

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async =>
      TemplatesFeedPage(items: items, nextCursor: null, hasMore: false);

  @override
  void cancelPendingFeedRequest() {}

  @override
  void cancelPendingRandomTemplateRequest() {}

  @override
  void cancelPendingMetadataRequests() {}

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
  }) async {
    return items.firstWhere((item) => item.templateId == templateId);
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    return items.isEmpty ? null : items.first;
  }

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async => items;

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async => null;

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {}

  @override
  Future<int> fetchCatalogVersion() async => 1;

  @override
  Future<int> readLocalCatalogVersion() async => 1;

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: 1,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    return knownRemoteVersion ?? 1;
  }
}

class RouterTemplateGenerationRepository extends TemplateGenerationRepository {
  RouterTemplateGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final List<String> fetchGenerationCalls = [];
  final List<String> fetchCompatibleTemplateCalls = [];
  int fetchPetsCalls = 0;
  int fetchPetPhotosCalls = 0;
  int fetchPetGenerationsCalls = 0;

  @override
  Future<List<PetProfile>> fetchPets({RequestCancellation? cancelToken}) async {
    fetchPetsCalls++;
    return [
      PetProfile(
        id: 'pet-router',
        name: 'Router Pet',
        type: 'dog',
        breed: 'Corgi',
        avatarUrl: 'https://cdn.petmagic.app/router-pet.jpg',
        photosCount: 1,
        generationsCount: 1,
        createdAtUtc: DateTime.utc(2035),
        updatedAtUtc: DateTime.utc(2035),
      ),
    ];
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    RequestCancellation? cancelToken,
  }) async {
    fetchPetPhotosCalls++;
    return const [];
  }

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    RequestCancellation? cancelToken,
  }) async {
    fetchPetGenerationsCalls++;
    return const [];
  }

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    RequestCancellation? cancelToken,
  }) async {
    fetchGenerationCalls.add(generationId);
    final now = DateTime.utc(2035, 1, 1, 12);
    return TemplateGenerationResult(
      generationId: generationId,
      userId: 'user-1',
      templateId: 'template-router',
      status: TemplateGenerationStatus.completed,
      tokenCost: 1,
      attemptCount: 1,
      createdAtUtc: now,
      updatedAtUtc: now,
      completedAtUtc: now,
      userMediaExpired: false,
      templateTitle: 'Router generation',
      templateType: 'image',
      outputUrl: 'https://cdn.petmagic.app/router-generation.jpg',
      resultPreviewUrl: 'https://cdn.petmagic.app/router-generation-thumb.jpg',
    );
  }

  @override
  Future<CompatibleGenerationTemplates> fetchCompatibleTemplates(
    String resultId, {
    RequestCancellation? cancelToken,
  }) async {
    fetchCompatibleTemplateCalls.add(resultId);
    return CompatibleGenerationTemplates(
      resultId: resultId,
      inputMediaType: TemplateType.image,
      templates: const [],
    );
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    RequestCancellation? cancelToken,
  }) async {}
}

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  AuthSession? storedSession;
  String? passwordResetRequestedFor;
  String? passwordResetConfirmedFor;
  bool? lastTermsOfUseAccepted;
  bool? lastMarketingEmailsEnabled;
  String? lastTermsOfUseVersion;
  String? lastPrivacyPolicyVersion;

  MobileUserProfile get _profile => const MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: 'Pet Parent',
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: sampleLegalAcceptance,
    roles: ['user'],
    avatar: null,
  );

  @override
  Future<AuthSession?> readSession() async => storedSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    RequestCancellation? cancelToken,
  }) async {
    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: MobileUserProfile(
        userId: _profile.userId,
        email: email,
        displayName: _profile.displayName,
        isPremium: _profile.isPremium,
        emailConfirmed: _profile.emailConfirmed,
        termsOfUseAccepted: _profile.termsOfUseAccepted,
        privacyPolicyAccepted: _profile.privacyPolicyAccepted,
        marketingEmailsEnabled: _profile.marketingEmailsEnabled,
        legalAcceptance: _profile.legalAcceptance,
        roles: _profile.roles,
        avatar: _profile.avatar,
      ),
    );
    storedSession = session;
    return session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required bool termsOfUseAccepted,
    required bool privacyPolicyAccepted,
    required String termsOfUseVersion,
    required String privacyPolicyVersion,
    required bool marketingEmailsEnabled,
    String? displayName,
    RequestCancellation? cancelToken,
  }) async {
    lastTermsOfUseAccepted = termsOfUseAccepted;
    lastMarketingEmailsEnabled = marketingEmailsEnabled;
    lastTermsOfUseVersion = termsOfUseVersion;
    lastPrivacyPolicyVersion = privacyPolicyVersion;

    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: MobileUserProfile(
        userId: _profile.userId,
        email: email,
        displayName: displayName?.isEmpty ?? true
            ? _profile.displayName
            : displayName,
        isPremium: _profile.isPremium,
        emailConfirmed: _profile.emailConfirmed,
        termsOfUseAccepted: termsOfUseAccepted,
        privacyPolicyAccepted: privacyPolicyAccepted,
        marketingEmailsEnabled: marketingEmailsEnabled,
        legalAcceptance: const MobileLegalAcceptanceStatus(
          termsOfUseAccepted: true,
          termsOfUseAcceptedVersion: '2026-05-20',
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: true,
          privacyPolicyAcceptedVersion: '2026-05-20',
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '2026-05-20',
          currentPrivacyPolicyVersion: '2026-05-20',
          requiresAcceptance: false,
        ),
        roles: _profile.roles,
        avatar: _profile.avatar,
      ),
    );
    storedSession = session;
    return session;
  }

  @override
  Future<MobileUserProfile> fetchProfile({
    RequestCancellation? cancelToken,
  }) async {
    final session = storedSession;
    if (session == null) {
      throw const AppException('Unauthorized', statusCode: 401);
    }

    return MobileUserProfile(
      userId: _profile.userId,
      email: session.user.email,
      displayName: session.user.displayName,
      isPremium: _profile.isPremium,
      emailConfirmed: _profile.emailConfirmed,
      termsOfUseAccepted: session.user.termsOfUseAccepted,
      privacyPolicyAccepted: session.user.privacyPolicyAccepted,
      marketingEmailsEnabled: session.user.marketingEmailsEnabled,
      legalAcceptance: session.user.legalAcceptance,
      roles: _profile.roles,
      avatar: _profile.avatar,
    );
  }

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    RequestCancellation? cancelToken,
  }) async {
    return sampleLegalDocuments;
  }

  @override
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
    RequestCancellation? cancelToken,
  }) async {
    final session = storedSession;
    if (session == null) {
      throw const AppException('Unauthorized', statusCode: 401);
    }

    final profile = MobileUserProfile(
      userId: session.user.userId,
      email: session.user.email,
      displayName: session.user.displayName,
      isPremium: session.user.isPremium,
      emailConfirmed: session.user.emailConfirmed,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: session.user.marketingEmailsEnabled,
      legalAcceptance: MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: documents.termsOfUse.version,
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: documents.privacyPolicy.version,
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: documents.termsOfUse.version,
        currentPrivacyPolicyVersion: documents.privacyPolicy.version,
        requiresAcceptance: false,
      ),
      roles: session.user.roles,
      avatar: session.user.avatar,
    );

    storedSession = AuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAtUtc: session.expiresAtUtc,
      user: profile,
    );

    return profile;
  }

  @override
  Future<void> logout() async {
    storedSession = null;
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    RequestCancellation? cancelToken,
  }) async {
    passwordResetRequestedFor = email;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    RequestCancellation? cancelToken,
  }) async {
    passwordResetConfirmedFor = email;
  }
}

class CancelledLoginProfileRepository extends FakeProfileRepository {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    RequestCancellation? cancelToken,
  }) async {
    throw const RequestCancelledException();
  }
}

class UnavailableLegalDocumentsProfileRepository extends FakeProfileRepository {
  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    RequestCancellation? cancelToken,
  }) async {
    throw const AppException('Legal documents unavailable', statusCode: 503);
  }
}

class FakeExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    return AuthSession(
      accessToken: 'external-access-token',
      refreshToken: 'external-refresh-token',
      expiresAtUtc: DateTime.utc(2030, 1, 1),
      user: MobileUserProfile(
        userId: 'external-user-1',
        email: provider == ExternalAuthProvider.google
            ? 'google@example.com'
            : 'apple@example.com',
        displayName: provider == ExternalAuthProvider.google
            ? 'Google Pet Parent'
            : 'Apple Pet Parent',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        marketingEmailsEnabled: false,
        legalAcceptance: sampleLegalAcceptance,
        roles: const ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}
}

class TrackingExternalAuthRepository extends FakeExternalAuthRepository {
  final List<ExternalAuthProvider> clearedProviders = [];

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    clearedProviders.add(provider);
  }
}

class FailingExternalAuthRepository implements ExternalAuthRepository {
  const FailingExternalAuthRepository(this.error);

  final AppException error;

  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    throw error;
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    throw error;
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    throw error;
  }
}

class ThrowingExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    throw Exception('google sign-in failed unexpectedly');
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    throw Exception('external account link failed unexpectedly');
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    throw Exception('external account sign-out failed unexpectedly');
  }
}

class CancelledExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    throw const RequestCancelledException();
  }

  @override
  Future<List<MobileLinkedAccount>> link(
    ExternalAuthProvider provider, {
    RequestCancellation? cancelToken,
  }) async {
    throw const RequestCancelledException();
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}
}
