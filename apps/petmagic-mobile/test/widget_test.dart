import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/app.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('shows onboarding for first-time guest', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Create magic moments with your pet'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('shows short welcome for returning guest', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
    );

    expect(find.text('Welcome back to PetMagic'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });

  testWidgets('guest can open auth and registration pages', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Display name (optional)'), findsOneWidget);
  });

  testWidgets('registers a new user and opens templates', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
      profileRepository: _FakeProfileRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Pet Parent');
    await tester.enterText(find.byType(TextField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password123');

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Magic Studio'), findsOneWidget);
  });

  testWidgets('shows validation error when passwords do not match', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      profileRepository: _FakeProfileRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Sign Up'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Sign Up'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'pet@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password123');
    await tester.enterText(find.byType(TextField).at(3), 'Password321');

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Sign Up'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('continues with Google and opens templates', (tester) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
      externalAuthRepository: _FakeExternalAuthRepository(),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Continue with Google'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Magic Studio'), findsOneWidget);
  });

  testWidgets('shows localized message when external sign-in is cancelled', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      externalAuthRepository: _FailingExternalAuthRepository(
        const AppException('auth.external_cancelled'),
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in was cancelled.'), findsOneWidget);
  });

  testWidgets('opens templates directly for authenticated user', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: {
        _onboardingSeenKey: true,
        _sessionKey: _buildSessionJson(),
      },
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    expect(find.text('Create Magic'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Magic Studio'), findsOneWidget);
  });

  testWidgets('guest can continue from welcome into template browsing', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      sharedPrefs: const {_onboardingSeenKey: true},
      repository: _FakeTemplatesRepository(items: const [_sampleTemplate]),
    );

    await tester.tap(find.text('Continue as guest'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Magic Studio'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Try template'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Try template'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> sharedPrefs = const {},
  TemplatesRepository? repository,
  ProfileRepository? profileRepository,
  ExternalAuthRepository? externalAuthRepository,
}) async {
  SharedPreferences.setMockInitialValues(sharedPrefs);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        templatesRepositoryProvider.overrideWith(
          (ref) => repository ?? _FakeTemplatesRepository(),
        ),
        profileRepositoryProvider.overrideWith(
          (ref) => profileRepository ?? _FakeProfileRepository(),
        ),
        externalAuthRepositoryProvider.overrideWith(
          (ref) => externalAuthRepository ?? _FakeExternalAuthRepository(),
        ),
      ],
      child: const PetMagicApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
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
        roles: ['user'],
        avatar: null,
      ),
    ).toJson(),
  );
}

const _sessionKey = 'petmagic_mobile_auth_session';
const _onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';

const _sampleTemplate = TemplateItem(
  templateId: 'template-1',
  templateType: TemplateType.image,
  title: 'Magic Studio',
  shortDescription: 'Turn your pet into a star.',
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
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  AuthSession? storedSession;

  MobileUserProfile get _profile =>
      const MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet Parent',
        isPremium: false,
        emailConfirmed: true,
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
    String? displayName,
  }) async {
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
      roles: _profile.roles,
      avatar: _profile.avatar,
    );
  }

  @override
  Future<void> logout() async {
    storedSession = null;
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
        roles: const ['user'],
        avatar: null,
      ),
    );
  }
}

class _FailingExternalAuthRepository implements ExternalAuthRepository {
  const _FailingExternalAuthRepository(this.error);

  final AppException error;

  @override
  Future<AuthSession> authenticate(ExternalAuthProvider provider) async {
    throw error;
  }
}
