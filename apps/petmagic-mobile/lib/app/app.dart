import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
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

    return MaterialApp.router(
      title: 'PetMagic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: _supportedAppLocales,
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
