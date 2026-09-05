import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/theme/petmagic_typography.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_state_illustration.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    PetMagicTypography.debugUseFontFamily('Comfortaa');
    final fonts = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.uri.resolve('material_fonts/');
    await (FontLoader('Roboto')..addFont(
          File.fromUri(
            fonts.resolve('roboto-regular.ttf'),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  for (final brightness in Brightness.values) {
    for (final scene in ['guest', 'empty', 'invitation']) {
      testWidgets(
        '$scene ${brightness.name} visual baseline',
        (tester) async {
        _size(tester, const Size(390, 844));
        await tester.pumpWidget(
          _host(
            brightness: brightness,
            child: Builder(
              builder: (context) {
                final text = AppLocalizations.of(context);
                if (scene == 'guest') {
                  return ProtectedAuthGate(
                    subtitle: text.authRequiredMessage,
                    onSignIn: () {},
                    onSignUp: () {},
                  );
                }
                if (scene == 'empty') {
                  return PetMagicAsyncStateView(
                    icon: Icons.photo_library_outlined,
                    title: text.generationStatusEmptyTitle,
                    message: text.generationStatusEmptyMessage,
                    actionLabel: text.createHubBrowseAction,
                    actionIcon: Icons.auto_awesome_rounded,
                    onAction: () {},
                  );
                }
                return Center(
                  child: FilledButton(
                    onPressed: () => showAuthRequiredSheet(
                      context,
                      title: text.navCreations,
                      redirectPath: '/creations',
                      showSignUp: true,
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (scene == 'invitation') {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.getBottomRight(find.byType(BottomSheet)).dy, 844);
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/state_${scene}_${brightness.name}.png'),
        );
          expect(tester.takeException(), isNull);
        },
        tags: const ['platform-golden'],
      );
    }
  }

  for (final language in ['ru', 'en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets(
      '$language guest actions remain reachable at 200 percent text',
      (tester) async {
        _size(tester, const Size(320, 568));
        var taps = 0;
        await tester.pumpWidget(
          _host(
            locale: Locale(language),
            textScale: 2,
            child: Center(
              child: SizedBox(
                height: 300,
                child: Builder(
                  builder: (context) => ProtectedAuthGate(
                    subtitle: AppLocalizations.of(context).authRequiredMessage,
                    onSignIn: () => taps++,
                    onSignUp: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.ensureVisible(find.byType(OutlinedButton));
        await tester.tap(find.byType(OutlinedButton));
        expect(taps, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact invitation scrolls and preserves safe area and auth intent',
    (tester) async {
      _size(tester, const Size(320, 568));
      final navigator = _RecordingNavigator();
      late AppLocalizations text;
      await tester.pumpWidget(
        AppNavigationScope(
          navigator: navigator,
          child: _host(
            textScale: 2,
            child: Builder(
              builder: (context) {
                text = AppLocalizations.of(context);
                return Center(
                  child: FilledButton(
                    onPressed: () => showAuthRequiredSheet(
                      context,
                      redirectPath: '/rewards',
                      showSignUp: true,
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final continueButton = find.widgetWithText(
        TextButton,
        text.authRequiredContinueBrowsing,
      );
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(continueButton).dy,
        lessThanOrEqualTo(568 - 34),
      );
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(navigator.destination, isNull);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final signUp = find.widgetWithText(OutlinedButton, text.authSignUpAction);
      await tester.ensureVisible(signUp);
      await tester.tap(signUp);
      await tester.pumpAndSettle();
      expect(
        (navigator.destination! as RegisterDestination).redirectPath,
        '/rewards',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'state inside a sliver supports intrinsic sizing and accessible action',
    (tester) async {
      _size(tester, const Size(320, 568));
      var calls = 0;
      await tester.pumpWidget(
        _host(
          textScale: 2,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: PetMagicAsyncStateView(
                  icon: Icons.pets_rounded,
                  title: 'Магия для питомца',
                  message: 'Выберите шаблон для первого портрета.',
                  actionLabel: 'Выбрать шаблон',
                  onAction: () => calls++,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      expect(calls, 1);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(FilledButton)).label,
        'Выбрать шаблон',
      );
      semantics.dispose();
      expect(find.byType(PetMagicStateIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(bottom: 34, top: 24);
  addTearDown(tester.view.reset);
}

Widget _host({
  required Widget child,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('ru'),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

class _RecordingNavigator implements AppNavigator {
  AppDestination? destination;
  @override
  void go(AppDestination value) => destination = value;
  @override
  Future<T?> push<T>(AppDestination value) async {
    destination = value;
    return null;
  }

  @override
  void replace(AppDestination value) => go(value);
  @override
  bool canPop() => false;
  @override
  void pop<T extends Object?>([T? result]) {}
}
