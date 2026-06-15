import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
  });

  testWidgets('1000+ templates feed stays lazy during fast scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _FeedStressTemplatesController(
      items: List<TemplateItem>.generate(
        1005,
        (index) => _template(
          'stress-template-$index',
          'Stress Template ${index.toString().padLeft(4, '0')}',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(_AuthenticatedLaunch.new),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          templatesControllerProvider.overrideWith(() => controller),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TemplatesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final firstFrameCardCount = find.byType(TemplateCard).evaluate().length;
    expect(firstFrameCardCount, greaterThan(0));
    expect(firstFrameCardCount, lessThan(40));

    final scrollable = find.byType(CustomScrollView);
    var capturedPerformance = false;
    try {
      await binding.watchPerformance(
        () => _fastScrollTemplatesFeed(tester, scrollable),
        reportKey: 'templates_feed_fast_scroll',
      );
      capturedPerformance =
          binding.reportData?['templates_feed_fast_scroll'] is Map;
    } catch (_) {
      await _fastScrollTemplatesFeed(tester, scrollable);
    }

    final afterFastScrollCardCount = find
        .byType(TemplateCard)
        .evaluate()
        .length;
    expect(afterFastScrollCardCount, greaterThan(0));
    expect(afterFastScrollCardCount, lessThan(60));
    if (capturedPerformance) {
      expect(binding.reportData?['templates_feed_fast_scroll'], isA<Map>());
    }

    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollableState.position.jumpTo(
      scrollableState.position.maxScrollExtent - 500,
    );
    await tester.pump();

    expect(controller.loadMoreCalls, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _fastScrollTemplatesFeed(
  WidgetTester tester,
  Finder scrollable,
) async {
  for (var i = 0; i < 14; i++) {
    await tester.fling(scrollable, const Offset(0, -1400), 9000);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

class _FeedStressTemplatesController extends TemplatesController {
  _FeedStressTemplatesController({required this.items});

  final List<TemplateItem> items;
  int loadMoreCalls = 0;

  @override
  TemplatesState build() {
    return const TemplatesState();
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {
    state = TemplatesState(
      items: items,
      hasMore: true,
      nextCursor: 'stress-cursor-2',
      isLoading: false,
      isRefreshing: false,
    );
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  void setScreenVisible(bool visible) {}
}

class _AuthenticatedLaunch extends AppLaunchController {
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

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

TemplateItem _template(String id, String title) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.image,
    title: title,
    shortDescription: title,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Stress',
    tags: const ['stress'],
    isPremium: false,
    tokenCost: 1,
  );
}
