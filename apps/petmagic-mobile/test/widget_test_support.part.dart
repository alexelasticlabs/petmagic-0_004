part of 'widget_test.dart';

GoRouter _testRouter(Widget home) {
  return GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => home)],
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> sharedPrefs = const {},
  TemplatesRepository? repository,
  ProfileRepository? profileRepository,
  ExternalAuthRepository? externalAuthRepository,
  AppLaunchController Function()? appLaunchController,
  Size surfaceSize = const Size(1080, 1920),
}) async {
  final view = tester.view;
  view.physicalSize = surfaceSize;
  view.devicePixelRatio = 1.0;

  final sharedPrefsWithoutSession = Map<String, Object>.from(sharedPrefs)
    ..remove(_sessionKey);
  SharedPreferences.setMockInitialValues(sharedPrefsWithoutSession);

  final authStorage = _TestAuthSessionStorage(
    rawSessionJson: sharedPrefs[_sessionKey] is String
        ? sharedPrefs[_sessionKey] as String
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
          (ref) => repository ?? _FakeTemplatesRepository(),
        ),
        templateGenerationControllerProvider.overrideWith(
          _IdleTemplateGenerationController.new,
        ),
        generationHistoryControllerProvider.overrideWith(
          _IdleGenerationHistoryController.new,
        ),
        walletControllerProvider.overrideWith(_IdleWalletController.new),
        profileRepositoryProvider.overrideWith(
          (ref) => profileRepository ?? _FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => externalAuthRepository ?? _FakeExternalAuthRepository(),
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int count = 8,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(step);
  }
}

class _IdleTemplateGenerationController extends TemplateGenerationController {
  @override
  TemplateGenerationState build() {
    return const TemplateGenerationState();
  }
}

class _IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }
}

class _ThrowingGuestLaunchController extends AppLaunchController {
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

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

String _buildSessionJson() {
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
        legalAcceptance: _sampleLegalAcceptance,
        roles: ['user'],
        avatar: null,
      ),
    ).toJson(),
  );
}

class _TestAuthSessionStorage extends AuthSessionStorage {
  _TestAuthSessionStorage({String? rawSessionJson})
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

const _sampleLegalAcceptance = MobileLegalAcceptanceStatus(
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

const _sampleLegalDocuments = MobileLegalDocuments(
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

const _sessionKey = AuthSessionStorage.sessionKey;
const _onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';

const _sampleTemplate = TemplateItem(
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

class _FakeTemplatesRepository implements TemplatesRepository {
  const _FakeTemplatesRepository({this.items = const []});

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

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  AuthSession? storedSession;
  String? passwordResetRequestedFor;
  String? passwordResetConfirmedFor;
  bool? lastTermsOfUseAccepted;
  bool? lastMarketingEmailsEnabled;

  MobileUserProfile get _profile => const MobileUserProfile(
    userId: 'user-1',
    email: 'pet@example.com',
    displayName: 'Pet Parent',
    isPremium: false,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: _sampleLegalAcceptance,
    roles: ['user'],
    avatar: null,
  );

  @override
  Future<AuthSession?> readSession() async => storedSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
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
  }) async {
    lastTermsOfUseAccepted = termsOfUseAccepted;
    lastMarketingEmailsEnabled = marketingEmailsEnabled;

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
  Future<MobileUserProfile> fetchProfile() async {
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
  }) async {
    return _sampleLegalDocuments;
  }

  @override
  Future<MobileUserProfile> acceptCurrentLegalDocuments({
    required MobileLegalDocuments documents,
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
  Future<void> requestPasswordReset({required String email}) async {
    passwordResetRequestedFor = email;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    passwordResetConfirmedFor = email;
  }
}

class _UnavailableLegalDocumentsProfileRepository
    extends _FakeProfileRepository {
  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
  }) async {
    throw const AppException('Legal documents unavailable', statusCode: 503);
  }
}

class _FakeExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
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
        legalAcceptance: _sampleLegalAcceptance,
        roles: const ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    return const [];
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {}
}

class _TrackingExternalAuthRepository extends _FakeExternalAuthRepository {
  final List<ExternalAuthProvider> clearedProviders = [];

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    clearedProviders.add(provider);
  }
}

class _FailingExternalAuthRepository implements ExternalAuthRepository {
  const _FailingExternalAuthRepository(this.error);

  final AppException error;

  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    throw error;
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    throw error;
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    throw error;
  }
}

class _ThrowingExternalAuthRepository implements ExternalAuthRepository {
  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    throw Exception('google sign-in failed unexpectedly');
  }

  @override
  Future<List<MobileLinkedAccount>> link(ExternalAuthProvider provider) async {
    throw Exception('external account link failed unexpectedly');
  }

  @override
  Future<void> clearSession(ExternalAuthProvider provider) async {
    throw Exception('external account sign-out failed unexpectedly');
  }
}

class _FakeSupportChatRepository extends SupportChatRepository {
  _FakeSupportChatRepository({
    this.emptyConversation = false,
    bool hasConversation = true,
  }) : _hasConversation = hasConversation,
       super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final bool emptyConversation;
  bool _hasConversation;
  String? lastSentBody;
  int openConversationCalls = 0;
  String? lastOpenedInitialMessage;
  late SupportChatConversation _conversation = SupportChatConversation(
    conversationId: 'conversation-1',
    initiatorUserId: 'user-1',
    userEmail: 'pet@example.com',
    userDisplayName: 'Pet Parent',
    assignedAdminId: 'admin-1',
    assignedAdminDisplayName: 'PetMagic Support',
    status: 'Open',
    priority: 'Normal',
    source: 'Direct',
    userUnreadCount: 1,
    adminUnreadCount: 0,
    createdAtUtc: DateTime.utc(2026, 1, 1, 10),
    updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
    lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
    messages: emptyConversation
        ? []
        : [
            SupportChatMessage(
              messageId: 'message-1',
              conversationId: 'conversation-1',
              senderUserId: 'admin-1',
              senderDisplayName: 'PetMagic Support',
              isFromAdmin: true,
              senderType: 'Admin',
              body: 'How can we help today?',
              isRead: false,
              attachments: const [],
              createdAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
            ),
          ],
  );

  @override
  Future<SupportChatConversation> openConversation({
    String source = 'Direct',
    String? assistantScenario,
    String? initialMessage,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    CancelToken? cancelToken,
  }) async {
    openConversationCalls += 1;
    lastOpenedInitialMessage = initialMessage;
    if (!_hasConversation) {
      _hasConversation = true;
      final now = DateTime.utc(2026, 1, 1, 10, 10);
      final initialMessages = <SupportChatMessage>[];
      final trimmedInitial = initialMessage?.trim() ?? '';
      if (trimmedInitial.isNotEmpty) {
        initialMessages.add(
          SupportChatMessage(
            messageId: 'message-2',
            conversationId: 'conversation-1',
            senderUserId: 'user-1',
            senderDisplayName: 'Pet Parent',
            isFromAdmin: false,
            senderType: 'User',
            body: trimmedInitial,
            isRead: false,
            attachments: const [],
            createdAtUtc: now,
          ),
        );
      }

      _conversation = SupportChatConversation(
        conversationId: 'conversation-1',
        initiatorUserId: 'user-1',
        userEmail: 'pet@example.com',
        userDisplayName: 'Pet Parent',
        assignedAdminId: 'admin-1',
        assignedAdminDisplayName: 'PetMagic Support',
        status: initialMessages.isEmpty ? 'Open' : 'WaitingForSupport',
        priority: 'Normal',
        source: source,
        userUnreadCount: 0,
        adminUnreadCount: initialMessages.isEmpty ? 0 : 1,
        createdAtUtc: DateTime.utc(2026, 1, 1, 10),
        updatedAtUtc: now,
        lastMessageAtUtc: initialMessages.isEmpty ? null : now,
        messages: initialMessages,
      );
      return _conversation;
    }

    return _conversation;
  }

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    CancelToken? cancelToken,
  }) async {
    if (!_hasConversation) {
      throw const AppException(
        'support.conversation_not_found',
        statusCode: 404,
      );
    }
    return _conversation;
  }

  @override
  Future<SupportChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String localeTag,
    String? replyToMessageId,
  }) async {
    if (!_hasConversation) {
      throw const AppException(
        'support.conversation_not_found',
        statusCode: 404,
      );
    }

    lastSentBody = body;
    final message = SupportChatMessage(
      messageId: 'message-2',
      conversationId: conversationId,
      senderUserId: 'user-1',
      senderDisplayName: 'Pet Parent',
      isFromAdmin: false,
      senderType: 'User',
      body: body,
      isRead: false,
      attachments: const [],
      createdAtUtc: DateTime.utc(2026, 1, 1, 10, 10),
    );

    _conversation = _conversation.copyWith(
      adminUnreadCount: _conversation.adminUnreadCount + 1,
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      messages: [..._conversation.messages, message],
    );

    return message;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    _conversation = _conversation.copyWith(
      userUnreadCount: 0,
      messages: _conversation.messages
          .map(
            (message) => message.isFromAdmin
                ? message.copyWith(
                    isRead: true,
                    readAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
                  )
                : message,
          )
          .toList(growable: false),
    );
  }
}

class _ThrowingSupportChatRepository extends SupportChatRepository {
  _ThrowingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    CancelToken? cancelToken,
  }) async {
    throw Exception('unexpected support failure');
  }
}

class _DelayedSupportChatRepository extends SupportChatRepository {
  _DelayedSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    CancelToken? cancelToken,
  }) async {
    return Completer<SupportChatConversation>().future;
  }
}

class _FakeSupportChatRealtimeClient implements SupportChatRealtimeClient {
  const _FakeSupportChatRealtimeClient();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<SupportChatRealtimeUpdate> get events => const Stream.empty();
}
