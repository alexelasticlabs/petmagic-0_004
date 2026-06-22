import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('language sheet applies locale selection', (tester) async {
    await _pumpSettingsPage(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(ProfileSettingsPage)),
    );

    await tester.tap(find.text(text.profileSettingsLanguageTitle));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsWidgets);
  });

  testWidgets('theme sheet applies selected theme mode', (tester) async {
    await _pumpSettingsPage(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(ProfileSettingsPage)),
    );

    await tester.tap(find.text(text.profileSettingsThemeTitle));
    await tester.pumpAndSettle();

    expect(find.text(text.profileSettingsThemeDark), findsOneWidget);

    await tester.tap(find.text(text.profileSettingsThemeDark));
    await tester.pumpAndSettle();

    expect(find.text(text.profileSettingsThemeDark), findsOneWidget);
  });

  testWidgets('delete confirmation sheet triggers account deletion action', (
    tester,
  ) async {
    await _pumpSettingsPage(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(ProfileSettingsPage)),
    );

    final deleteRow = find.text(text.profileSettingsDeleteAccountTitle);
    await tester.scrollUntilVisible(
      deleteRow,
      320,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(deleteRow);
    await tester.pumpAndSettle();
    await tester.tap(deleteRow);
    await tester.pumpAndSettle();

    final deleteButton = find.widgetWithText(
      FilledButton,
      text.profileSettingsDeleteAccountTitle,
    );
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(_FakeProfileController.deleteAccountCalls, 1);
  });

  testWidgets('change password row opens in-app password change route', (
    tester,
  ) async {
    await _pumpSettingsPage(tester);

    final text = AppLocalizations.of(
      tester.element(find.byType(ProfileSettingsPage)),
    );

    await tester.tap(find.text(text.profileSettingsPasswordTitle));
    await tester.pumpAndSettle();

    expect(find.text('password-change-screen'), findsOneWidget);
  });

  testWidgets('feedback sheet submits selected category without crashing', (
    tester,
  ) async {
    final repository = _FakeTemplateGenerationRepository();
    await _pumpSettingsPage(tester, templateRepository: repository);

    final feedbackRow = find.text('Send feedback').first;
    await tester.scrollUntilVisible(
      feedbackRow,
      320,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(feedbackRow);
    await tester.pumpAndSettle();

    await tester.tap(feedbackRow);
    await tester.pumpAndSettle();

    expect(find.text('Баг'), findsOneWidget);

    await tester.tap(find.text('Баг'));
    await tester.enterText(find.byType(TextFormField), 'Краш при отправке');
    await tester.tap(find.widgetWithText(FilledButton, 'Отправить'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(repository.submittedType, 'BugReport');
    expect(repository.submittedCategory, 'bug');
    expect(repository.submittedMessage, 'Краш при отправке');
    expect(repository.submittedSourceScreen, 'settings');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  TemplateGenerationRepository? templateRepository,
}) async {
  _FakeProfileController.deleteAccountCalls = 0;
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(_FakeProfileController.new),
        appPreferencesControllerProvider.overrideWith(
          _FakePreferencesController.new,
        ),
        templateGenerationRepositoryProvider.overrideWithValue(
          templateRepository ?? _FakeTemplateGenerationRepository(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [
          Locale('ru'),
          Locale('en'),
          Locale('de'),
          Locale('es'),
          Locale('fr'),
          Locale('it'),
          Locale('pl'),
        ],
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: ProfileSettingsPage()),
            ),
            GoRoute(
              path: PasswordChangePage.routePath,
              builder: (context, state) =>
                  const Scaffold(body: Text('password-change-screen')),
            ),
          ],
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _FakeProfileController extends ProfileController {
  static int deleteAccountCalls = 0;

  @override
  ProfileState build() {
    const profile = MobileUserProfile(
      userId: 'user-1',
      email: 'user@example.com',
      displayName: 'Pet User',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: true,
      legalAcceptance: MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: '1.0',
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: '1.0',
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: '1.0',
        currentPrivacyPolicyVersion: '1.0',
        requiresAcceptance: false,
      ),
      roles: ['user'],
      avatar: null,
    );

    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: 'Pet User',
      email: 'user@example.com',
      password: '',
      confirmPassword: '',
      profile: profile,
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls += 1;
  }
}

class _FakePreferencesController extends AppPreferencesController {
  @override
  AppPreferencesState build() {
    return const AppPreferencesState(
      themeMode: ThemeMode.system,
      locale: Locale('ru'),
      hasLoaded: true,
    );
  }

  @override
  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode, hasLoaded: true);
  }

  @override
  Future<void> updateLocale(Locale? locale) async {
    state = state.copyWith(locale: locale, localeWasSet: true, hasLoaded: true);
  }
}

class _FakeTemplateGenerationRepository extends TemplateGenerationRepository {
  _FakeTemplateGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  String? submittedType;
  String? submittedCategory;
  String? submittedMessage;
  String? submittedSourceScreen;

  @override
  Future<String> submitFeedback({
    required String type,
    required String category,
    int? rating,
    String? message,
    String? generationId,
    String? templateId,
    String? petId,
    String sourceScreen = 'settings',
    CancelToken? cancelToken,
    bool retryTransientFailures = false,
  }) async {
    submittedType = type;
    submittedCategory = category;
    submittedMessage = message;
    submittedSourceScreen = sourceScreen;
    return 'feedback-1';
  }
}
