import 'dart:io';

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
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
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

    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text(text.profileSettingsLanguageEnglish), findsWidgets);
  });

  test('profile settings page uses shared localized language helpers', () {
    final pageSource = File(
      'lib/features/profile/presentation/profile_settings_page.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/features/profile/presentation/profile_settings_page_content.part.dart',
    ).readAsStringSync();
    final bottomSheetSource = File(
      'lib/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart',
    ).readAsStringSync();

    expect(pageSource, contains('options: profileLanguageSheetOptions'));
    expect(pageSource, isNot(contains("nativeLabel: 'Русский'")));
    expect(pageSource, isNot(contains("=> 'English'")));
    expect(
      contentSource,
      contains('profileLanguageLabel(text, resolvedLocale)'),
    );
    expect(bottomSheetSource, contains('profileLanguageSheetOptions ='));
    expect(bottomSheetSource, contains('text.profileSettingsLanguageGerman'));
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

    final text = AppLocalizations.of(
      tester.element(find.byType(ProfileSettingsPage)),
    );
    final feedbackRow = find.text(text.profileSettingsFeedbackTitle).first;
    await tester.scrollUntilVisible(
      feedbackRow,
      320,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(feedbackRow);
    await tester.pumpAndSettle();

    await tester.tap(feedbackRow);
    await tester.pumpAndSettle();

    expect(find.text(text.profileSettingsFeedbackOptionBug), findsOneWidget);

    await tester.tap(find.text(text.profileSettingsFeedbackOptionBug));
    await tester.enterText(find.byType(TextFormField), 'Краш при отправке');
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        text.profileSettingsFeedbackSubmitAction,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(repository.submittedType, 'BugReport');
    expect(repository.submittedCategory, 'bug');
    expect(repository.submittedMessage, 'Краш при отправке');
    expect(repository.submittedSourceScreen, 'settings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page shows auth gate for guests', (tester) async {
    await _pumpSettingsPage(tester, guest: true);

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text('Account information'), findsNothing);
  });

  testWidgets('account details page shows auth gate for guests', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(_GuestProfileController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfileAccountInfoPage()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
  });

  test('profile settings page keeps content and feedback flows split', () async {
    final pageSource = await File(
      'lib/features/profile/presentation/profile_settings_page.dart',
    ).readAsString();
    final contentSource = await File(
      'lib/features/profile/presentation/profile_settings_page_content.part.dart',
    ).readAsString();
    final feedbackSource = await File(
      'lib/features/profile/presentation/profile_settings_feedback.part.dart',
    ).readAsString();

    expect(
      pageSource,
      contains("part 'profile_settings_page_content.part.dart';"),
    );
    expect(pageSource, contains("part 'profile_settings_feedback.part.dart';"));
    expect(pageSource, isNot(contains('class _SettingsFeedbackSheet')));
    expect(pageSource, isNot(contains('ProfileGlassCard(')));
    expect(contentSource, contains("part of 'profile_settings_page.dart';"));
    expect(feedbackSource, contains("part of 'profile_settings_page.dart';"));
    expect(contentSource, contains('class _ProfileSettingsPageContent'));
    expect(feedbackSource, contains('class _SettingsFeedbackSheet'));
    expect(feedbackSource, contains('sourceScreen: \'settings\''));
    expect(feedbackSource, contains('AppLogger.warn('));
    expect(feedbackSource, contains("feature: 'Profile.SettingsFeedback'"));
    expect(feedbackSource, isNot(contains('} catch (_) {')));
    expect(contentSource, contains('Color.alphaBlend('));
    expect(
      contentSource,
      contains('colors.danger.withValues(alpha: isLight ? 0.08 : 0.18)'),
    );
    expect(contentSource, contains('colors.surfaceStrong'));
    expect(contentSource, isNot(contains('const Color(0xFFF7EEF0)')));
    expect(contentSource, isNot(contains('const Color(0xFF151A29)')));
    expect(contentSource, isNot(contains('const Color(0xFFFDF7F8)')));
    expect(contentSource, isNot(contains('const Color(0xFF1A2236)')));
  });
}

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  TemplateGenerationRepository? templateRepository,
  bool guest = false,
}) async {
  _FakeProfileController.deleteAccountCalls = 0;
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(
          guest ? _GuestProfileController.new : _FakeProfileController.new,
        ),
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

class _GuestProfileController extends ProfileController {
  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: '',
      email: '',
      password: '',
      confirmPassword: '',
    );
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
