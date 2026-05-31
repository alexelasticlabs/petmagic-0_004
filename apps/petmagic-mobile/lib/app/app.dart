import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/app_performance_monitor.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/router/app_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/notifications/push_notifications_bootstrap.dart';
import 'package:petmagic_mobile/core/startup/session_scope_reset.dart';
import 'package:petmagic_mobile/shared/widgets/network_status_banner.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_notification_host.dart';

const _supportedAppLocales = <Locale>[
  Locale('ru'),
  Locale('en'),
  Locale('de'),
  Locale('es'),
  Locale('fr'),
  Locale('it'),
  Locale('pl'),
];

class PetMagicApp extends ConsumerWidget {
  const PetMagicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionScopeResetProvider);
    ref.watch(networkStatusControllerProvider);
    final router = ref.watch(appRouterProvider);
    final preferences = ref.watch(appPreferencesControllerProvider);

    return MaterialApp.router(
      title: 'PetMagic',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: AppConfig.enablePerformanceOverlay,
      checkerboardRasterCacheImages:
          AppConfig.enableCheckerboardRasterCacheImages,
      checkerboardOffscreenLayers: AppConfig.enableCheckerboardOffscreenLayers,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: preferences.themeMode,
      routerConfig: router,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle =
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                );
        final appChild = PushNotificationsBootstrap(
          router: router,
          child: child ?? const SizedBox.shrink(),
        );
        final hostedChild = AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Stack(
            children: [
              PetMagicNotificationHost(child: appChild),
              Positioned.fill(
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: const NetworkStatusBanner(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        if (!AppConfig.enableFrameTelemetry &&
            !AppConfig.enableImageCacheTelemetry) {
          return hostedChild;
        }

        return AppPerformanceMonitor(child: hostedChild);
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: _supportedAppLocales,
      locale: preferences.locale,
      localeListResolutionCallback: (locales, supportedLocales) {
        if (locales == null || locales.isEmpty) {
          return const Locale('ru');
        }

        for (final locale in locales) {
          for (final supportedLocale in _supportedAppLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }

          if (locale.languageCode == 'en') {
            return const Locale('en');
          }
        }

        return const Locale('ru');
      },
    );
  }
}
