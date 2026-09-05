import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_discovery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_rail.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';

import 'templates_page_lifecycle_test_support.dart';
import 'widget_test_support.dart';

const _photoUrl = 'https://discovery-fixture.test/portrait.png';
late File _photoFile;

void main() {
  configureWidgetTestHarness();
  late Directory cacheDirectory;
  setUpAll(() async {
    // Flutter's own bundled reading font, rather than Ahem blocks in captions.
    final fonts = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent.uri.resolve('material_fonts/');
    final loader = FontLoader('Roboto')
      ..addFont(
        File.fromUri(
          fonts.resolve('roboto-regular.ttf'),
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
    cacheDirectory = await Directory.systemTemp.createTemp(
      'petmagic-discovery-theme-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cacheDirectory.path,
        );
    final photo = await rootBundle.load(
      'assets/rewards/profile-premium-dog.png',
    );
    await TemplateMediaCache.thumbnailCache.putFile(
      _photoUrl,
      photo.buffer.asUint8List(),
      key: TemplateMediaCache.cacheKeyForMedia(_photoUrl),
      fileExtension: 'png',
    );
    _photoFile = await TemplateMediaCache.fetchThumbnailFile(_photoUrl);
  });
  tearDownAll(() async {
    await TemplateMediaCache.thumbnailCache.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    expect(
      cacheDirectory.parent.absolute.path,
      Directory.systemTemp.absolute.path,
    );
    await cacheDirectory.delete(recursive: true);
  });

  for (final brightness in Brightness.values) {
    test('Discovery ink contrast in ${brightness.name}', () {
      final colors = PetMagicPalettes.forBrightness(brightness);
      for (final background in [
        colors.backgroundTop,
        colors.surface,
        Color.alphaBlend(colors.accent.withValues(alpha: 0.24), colors.surface),
      ]) {
        expect(
          PetMagicPalettes.contrastRatio(colors.accentInk, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        PetMagicPalettes.contrastRatio(colors.goldInk, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'Discovery ${brightness.name} visual and interaction baseline',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final mode = ValueNotifier(
          brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        );
        addTearDown(mode.dispose);
        await _pumpPage(tester, mode);
        await expectLater(
          find.byKey(const Key('discovery-theme-surface')),
          matchesGoldenFile('goldens/discovery_home_${brightness.name}.png'),
        );

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -390));
        await tester.pumpAndSettle();
        final caption = find.text('Секретный агент');
        await Scrollable.ensureVisible(
          tester.element(caption),
          alignment: 0.35,
        );
        await tester.pumpAndSettle();
        expect(find.byType(TemplateDiscoveryRail), findsNWidgets(2));
        final price = find.byKey(const ValueKey('discovery-price-premium'));
        final priceDecoration =
            tester.widget<Container>(price).decoration! as BoxDecoration;
        if (brightness == Brightness.light) {
          expect(priceDecoration.color, PetMagicPalettes.light.surface);
        }
        await expectLater(
          find.byKey(const Key('discovery-theme-surface')),
          matchesGoldenFile('goldens/discovery_rails_${brightness.name}.png'),
        );

        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final offset = scrollable.position.pixels;
        mode.value = brightness == Brightness.light
            ? ThemeMode.dark
            : ThemeMode.light;
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, offset);
        mode.value = brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark;
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('discovery-random-launcher')),
        );
        await tester.pumpAndSettle();
        final text = AppLocalizations.of(
          tester.element(find.byType(TemplatesDiscoveryPage)),
        );
        await tester.tap(find.text(text.videoLabel));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text(text.videoLabel)).style!.color,
          PetMagicPalettes.forBrightness(brightness).accentInk,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/discovery_random_${brightness.name}.png'),
        );
        await tester.tap(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('discovery-random-launcher')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'light Discovery and random sheet fit 320dp at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await _pumpPage(tester, mode, scale: 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('discovery-random-launcher')),
      );
      await tester.tap(find.byKey(const ValueKey('discovery-random-launcher')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  ValueNotifier<ThemeMode> mode, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        templateDiscoveryRepositoryProvider.overrideWithValue(
          const _DiscoveryRepository(),
        ),
        appLaunchControllerProvider.overrideWith(_GuestLaunch.new),
        walletControllerProvider.overrideWith(IdleWalletController.new),
        networkStatusControllerProvider.overrideWith(
          () => TestTemplatesNetworkStatusController(initialHasInternet: true),
        ),
      ],
      child: ValueListenableBuilder(
        valueListenable: mode,
        builder: (_, value, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: value,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: Key('discovery-theme-surface'),
            child: Scaffold(body: TemplatesDiscoveryPage()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final context = tester.element(find.byType(TemplatesDiscoveryPage));
    for (final width in [280, 480]) {
      await precacheImage(
        ResizeImage(FileImage(_photoFile), width: width),
        context,
      );
    }
  });
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump();
    if (find.byType(Image).evaluate().length >= 2) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
  expect(find.byType(Image).evaluate().length, greaterThanOrEqualTo(2));
}

class _GuestLaunch extends AppLaunchController {
  @override
  AppLaunchState build() => const AppLaunchState(
    isLoading: false,
    isAuthenticated: false,
    requiresLegalAcceptance: false,
    hasSeenOnboarding: true,
    guestSessionReady: true,
  );
}

class _DiscoveryRepository implements TemplateDiscoveryRepository {
  const _DiscoveryRepository();
  @override
  void cancelPendingRequest() {}
  @override
  Future<TemplateDiscovery?> readCached() async => null;
  @override
  Future<TemplateDiscovery> fetch() async => TemplateDiscovery(
    generatedAtUtc: DateTime.utc(2026, 9, 5),
    sections: [
      TemplateDiscoverySection(
        category: 'Cinematic',
        items: [_item('agent', 'Секретный агент')],
      ),
      TemplateDiscoverySection(
        category: 'Funny',
        items: [
          _item('premium', 'Фотография домашнего животного', premium: true),
          _item('video', 'Танцующая звезда', video: true),
          _item('free', 'Большой босс', free: true),
        ],
      ),
    ],
  );
}

TemplateItem _item(
  String id,
  String title, {
  bool premium = false,
  bool video = false,
  bool free = false,
}) => TemplateItem(
  templateId: id,
  templateType: video ? TemplateType.video : TemplateType.image,
  title: title,
  shortDescription: '',
  petPhotoRequirements: [],
  category: '',
  tags: [],
  isPremium: premium,
  tokenCost: free ? 0 : (video ? 25 : 4),
  thumbnailUrl: video || free ? null : _photoUrl,
  durationMs: video ? 5000 : null,
);
