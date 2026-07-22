import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/widgets/startup_chrome.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/app/shell/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/network_status_banner.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_action_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_notification_host.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final notificationCenter = PetMagicNotificationCenter.instance;

  test('premium shimmer button uses theme contrast foreground', () {
    final source = File(
      'lib/shared/widgets/premium_shimmer_button.dart',
    ).readAsStringSync();

    expect(source, contains('context.petMagicColors.on'));
    expect(source, contains('_kPremiumButtonForegroundTone'));
    expect(source, isNot(contains('color: Color(0xFF261903)')));
  });

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

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

  testWidgets('five-tab shell exposes one TalkBack label per destination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
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

    final text = AppLocalizations.of(
      tester.element(find.byType(PetMagicShell)),
    );
    for (final label in [
      text.navDiscover,
      text.navCreate,
      text.navCreations,
      text.navRewards,
      text.navProfile,
    ]) {
      expect(tester.getSemantics(find.bySemanticsLabel(label)).label, label);
    }
    semantics.dispose();
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
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkStatusControllerProvider.overrideWith(
              _HiddenNetworkStatusController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: const PetMagicNotificationHost(
              child: Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );

      notificationCenter.enqueue(
        'Localized warning',
        duration: const Duration(minutes: 1),
        dedupeKey: 'theme-$themeMode',
      );
      await tester.pump();

      final bannerContext = tester.element(find.text('Localized warning'));
      final colors = bannerContext.petMagicColors;
      final expectedBase =
          (Color.lerp(
                    colors.surface,
                    colors.blue,
                    themeMode == ThemeMode.dark ? 0.18 : 0.10,
                  ) ??
                  colors.surface)
              .withValues(alpha: 0.96);

      expect(find.text('Localized warning'), findsOneWidget);
      expect(_containerDecoration(tester, 22).color, expectedBase);

      await notificationCenter.dismissCurrent();
      await tester.pumpAndSettle();

      expect(find.text('Localized warning'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('network status banner follows theme surface tokens', (
    tester,
  ) async {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkStatusControllerProvider.overrideWith(
              _OfflineNetworkStatusController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: NetworkStatusBanner()),
          ),
        ),
      );
      await tester.pump();

      final bannerContext = tester.element(find.byType(NetworkStatusBanner));
      final colors = bannerContext.petMagicColors;
      final expectedBase =
          (Color.lerp(colors.surface, colors.danger, 0.10) ?? colors.surface)
              .withValues(alpha: 0.98);

      expect(_containerDecoration(tester, 18).color, expectedBase);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('notification center bounds queued banners under burst load', () async {
    await notificationCenter.clearQueue();

    for (var index = 0; index < 80; index++) {
      notificationCenter.enqueue(
        'Burst notification $index',
        duration: const Duration(minutes: 1),
        dedupeKey: 'burst-$index',
      );
    }

    expect(notificationCenter.current?.message, 'Burst notification 0');
    expect(notificationCenter.queueLength, 24);

    await notificationCenter.clearQueue();
  });

  test(
    'notification center clearQueue clears recent dedupe signatures',
    () async {
      await notificationCenter.clearQueue();

      notificationCenter.enqueue(
        'Sensitive payload should not remain after clear',
        duration: const Duration(minutes: 1),
        dedupeKey: 'sensitive-dedupe-key',
      );
      expect(notificationCenter.current, isNotNull);

      await notificationCenter.clearQueue();
      notificationCenter.enqueue(
        'Sensitive payload should not remain after clear',
        duration: const Duration(minutes: 1),
        dedupeKey: 'sensitive-dedupe-key',
      );

      expect(notificationCenter.current, isNotNull);
      expect(
        notificationCenter.current?.message,
        'Sensitive payload should not remain after clear',
      );

      await notificationCenter.clearQueue();
    },
  );
}

class _HiddenNetworkStatusController extends NetworkStatusController {
  @override
  NetworkStatusState build() => const NetworkStatusState();
}

class _OfflineNetworkStatusController extends NetworkStatusController {
  @override
  NetworkStatusState build() => const NetworkStatusState(
    bannerPhase: NetworkBannerPhase.offline,
    hasInternet: false,
  );
}

class _IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() => const GenerationHistoryState();
}

BoxDecoration _containerDecoration(WidgetTester tester, double radius) {
  final borderRadius = BorderRadius.circular(radius);
  final containers = tester.widgetList<Container>(
    find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }

      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.borderRadius == borderRadius;
    }),
  );

  expect(containers, hasLength(1));
  return containers.single.decoration! as BoxDecoration;
}
