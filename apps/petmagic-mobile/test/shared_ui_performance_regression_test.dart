import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/widgets/startup_chrome.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_action_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_notification_host.dart';

void main() {
  final notificationCenter = PetMagicNotificationCenter.instance;

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await notificationCenter.clearQueue();
  });

  testWidgets('android shell drops backdrop filters in reduced motion', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(390, 844), disableAnimations: true),
            child: PetMagicShell(
              location: '/templates',
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS shell keeps glass backdrop when motion is allowed', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PetMagicShell(
            location: '/templates',
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'android startup backdrop avoids expensive blur filters on phone',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: Scaffold(body: StartupBackdrop(accentRank: 0)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ImageFiltered), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'android welcome page drops decorative transitions on compact phones',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MediaQuery(
              data: MediaQueryData(size: Size(390, 844)),
              child: GuestWelcomePage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(GuestWelcomePage),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(GuestWelcomePage),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('android action sheet avoids backdrop blur on phones', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showPetMagicActionSheet(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('notification host still renders and dismisses banners', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkStatusControllerProvider.overrideWith(
            _HiddenNetworkStatusController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PetMagicNotificationHost(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );

    notificationCenter.enqueue(
      'Localized warning',
      duration: const Duration(minutes: 1),
    );
    await tester.pump();

    expect(find.text('Localized warning'), findsOneWidget);

    await notificationCenter.dismissCurrent();
    await tester.pumpAndSettle();

    expect(find.text('Localized warning'), findsNothing);
  });
}

class _HiddenNetworkStatusController extends NetworkStatusController {
  @override
  NetworkStatusState build() => const NetworkStatusState();
}

class _IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() => const GenerationHistoryState();
}
