import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/app_performance_monitor.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/router/app_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

const _supportedAppLocales = <Locale>[
  Locale('ru'),
  Locale('en'),
  Locale('en', 'US'),
];

class PetMagicApp extends ConsumerWidget {
  const PetMagicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        final appChild = child ?? const SizedBox.shrink();
        if (!AppConfig.enableFrameTelemetry &&
            !AppConfig.enableImageCacheTelemetry) {
          return appChild;
        }

        return AppPerformanceMonitor(child: appChild);
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: _supportedAppLocales,
      locale: preferences.locale,
      localeListResolutionCallback: (locales, supportedLocales) {
        if (locales == null || locales.isEmpty) {
          return const Locale('ru');
        }

        for (final locale in locales) {
          if (locale.languageCode == 'ru') {
            return const Locale('ru');
          }
          if (locale.languageCode == 'en') {
            return locale.countryCode == 'US'
                ? const Locale('en', 'US')
                : const Locale('en');
          }
        }

        return const Locale('ru');
      },
    );
  }
}
