import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  testWidgets(
    'password change page shows auth gate for guests without resetting controller',
    (tester) async {
      _TrackedPasswordChangeController.resetCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _GuestAppLaunchController.new,
            ),
            passwordChangeControllerProvider.overrideWith(
              _TrackedPasswordChangeController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: PasswordChangePage(email: 'user@example.com'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final context = tester.element(find.byType(PasswordChangePage));
      final text = AppLocalizations.of(context);

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(find.text(text.authRequiredTitle), findsOneWidget);
      expect(find.text(text.profileSettingsPasswordTitle), findsNothing);
      expect(_TrackedPasswordChangeController.resetCalls, 0);
    },
  );

  testWidgets(
    'password change page resets controller after guest signs in on the same route',
    (tester) async {
      _TrackedPasswordChangeController.resetCalls = 0;
      final launchController = _MutableAppLaunchController(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(() => launchController),
            passwordChangeControllerProvider.overrideWith(
              _TrackedPasswordChangeController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: PasswordChangePage(email: 'user@example.com'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(_TrackedPasswordChangeController.resetCalls, 0);

      launchController.setAuthenticated(true);
      await tester.pump();
      await tester.pump();

      expect(_TrackedPasswordChangeController.resetCalls, 1);
      expect(find.byType(ProtectedAuthGate), findsNothing);
    },
  );

  testWidgets(
    'password change keeps the active code form when route arguments are lost',
    (tester) async {
      _ActivePasswordChangeController.resetCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            passwordChangeControllerProvider.overrideWith(
              _ActivePasswordChangeController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: PasswordChangePage(email: 'user@example.com'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            passwordChangeControllerProvider.overrideWith(
              _ActivePasswordChangeController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: PasswordChangePage(email: '')),
          ),
        ),
      );

      await tester.pump();
      expect(_ActivePasswordChangeController.resetCalls, 0);
      expect(find.byType(TextField), findsNWidgets(3));
    },
  );
}

class _TrackedPasswordChangeController extends PasswordChangeController {
  static int resetCalls = 0;

  @override
  PasswordChangeState build() {
    return const PasswordChangeState();
  }

  @override
  void reset({required String email}) {
    resetCalls += 1;
    super.reset(email: email);
  }
}

class _GuestAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
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

class _ActivePasswordChangeController extends PasswordChangeController {
  static int resetCalls = 0;

  @override
  PasswordChangeState build() {
    return const PasswordChangeState(
      email: 'user@example.com',
      code: '123456',
      codeRequested: true,
    );
  }

  @override
  void reset({required String email}) {
    resetCalls += 1;
    super.reset(email: email);
  }
}

class _MutableAppLaunchController extends AppLaunchController {
  _MutableAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: value,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}
