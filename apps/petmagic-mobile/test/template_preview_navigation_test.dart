import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/router/app_router.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_loader_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_discovery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  testWidgets('preview route keys the viewer by its initial template', (
    tester,
  ) async {
    final repository = FakeTemplatesRepository(
      items: [_template('template-a'), _template('template-b')],
    );
    final container = ProviderContainer(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          _AuthenticatedAppLaunchController.new,
        ),
        templatesRepositoryProvider.overrideWithValue(repository),
        templatePremiumAccessProvider.overrideWithValue(false),
      ],
    );
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    final firstSession = TemplatePreviewSession.single(_template('template-a'));
    final firstArgs = TemplatePreviewRouteArgs(
      template: firstSession.initialTemplate,
      hasPremiumAccess: false,
      isAuthenticated: true,
      session: firstSession,
    );
    router.go(
      const TemplatePreviewDestination(templateId: 'template-a').location,
      extra: firstArgs,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('template-preview:template-a')),
      findsOneWidget,
    );

    final secondSession = TemplatePreviewSession.single(
      _template('template-b'),
    );
    final secondArgs = TemplatePreviewRouteArgs(
      template: secondSession.initialTemplate,
      hasPremiumAccess: false,
      isAuthenticated: true,
      session: secondSession,
    );
    router.go(
      const TemplatePreviewDestination(templateId: 'template-b').location,
      extra: secondArgs,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('template-preview:template-a')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('template-preview:template-b')),
      findsOneWidget,
    );
  });

  testWidgets(
    'system back from a discovery preview preserves discovery state and scroll',
    (tester) async {
      final templates = List<TemplateItem>.generate(
        6,
        (index) => _template('discovery-template-$index'),
      );
      final discoveryRepository = _TrackingDiscoveryRepository(
        TemplateDiscovery(
          sections: [
            for (var index = 0; index < templates.length; index++)
              TemplateDiscoverySection(
                category: 'Discovery category $index',
                items: [templates[index]],
              ),
          ],
          generatedAtUtc: DateTime.utc(2026, 9, 5),
        ),
      );

      await pumpTestApp(
        tester,
        surfaceSize: const Size(390, 844),
        repository: FakeTemplatesRepository(items: templates),
        discoveryRepository: discoveryRepository,
        appLaunchController: _AuthenticatedAppLaunchController.new,
        networkStatusController: OnlineWidgetNetworkStatusController.new,
      );
      await _pumpUntil(
        tester,
        () =>
            find.byType(TemplatesDiscoveryPage).evaluate().isNotEmpty &&
            find.text('Discovery category 5').evaluate().isNotEmpty,
      );

      final discoveryFinder = find.byType(TemplatesDiscoveryPage);
      final discoveryStateBefore = tester.state(discoveryFinder);
      final discoveryScrollFinder = _discoveryVerticalScrollable();
      expect(discoveryScrollFinder, findsOneWidget);

      await tester.drag(
        find.byKey(const PageStorageKey<String>('templates-discovery-scroll')),
        const Offset(0, -520),
      );
      await tester.pumpAndSettle();

      final scrollStateBefore = tester.state<ScrollableState>(
        discoveryScrollFinder,
      );
      final scrollOffsetBefore = scrollStateBefore.position.pixels;
      expect(scrollOffsetBefore, greaterThan(0));

      final router = GoRouter.of(tester.element(discoveryFinder));
      final session = TemplatePreviewSession.fromSelection(
        items: templates,
        selectedTemplate: templates[4],
        source: TemplatePreviewSource.discovery,
      );
      final bridgeFuture = GoRouterAppNavigator(router).push<void>(
        TemplatesDestination(
          category: 'Discovery category 4',
          payload: session,
        ),
      );

      await _pumpUntil(
        tester,
        () => find.byType(TemplatePreviewPage).evaluate().isNotEmpty,
      );
      expect(
        router.state.uri.path,
        '/templates/preview/${templates[4].templateId}',
      );

      await tester.binding.handlePopRoute();
      await _pumpUntil(
        tester,
        () => router.state.uri.path == TemplatesDiscoveryPage.routePath,
      );
      await bridgeFuture;
      await tester.pumpAndSettle();

      expect(find.byType(TemplatesPage), findsNothing);
      expect(find.byType(TemplatesDiscoveryPage), findsOneWidget);
      expect(tester.state(discoveryFinder), same(discoveryStateBefore));

      final scrollStateAfter = tester.state<ScrollableState>(
        _discoveryVerticalScrollable(),
      );
      expect(scrollStateAfter, same(scrollStateBefore));
      expect(
        scrollStateAfter.position.pixels,
        closeTo(scrollOffsetBefore, 0.1),
      );
      expect(discoveryRepository.fetchCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loader keeps a localized error visible and retries in place', (
    tester,
  ) async {
    final repository = _ControlledTemplatesRepository();
    final navigator = _RecordingNavigator();
    await _pumpLoader(
      tester,
      templateId: 'retry-template',
      repository: repository,
      navigator: navigator,
      locale: const Locale('ru'),
    );

    repository
        .requestsFor('retry-template')
        .single
        .completeError(StateError('temporary failure'));
    await tester.pump();
    await tester.pump();

    final text = AppLocalizations.of(
      tester.element(
        find.byKey(const ValueKey('template-preview-loader-error')),
      ),
    );
    expect(find.text(text.templatesErrorTitle), findsOneWidget);
    expect(find.text(text.templatesRequestFailedError), findsOneWidget);
    expect(find.text(text.retryAction), findsOneWidget);
    expect(find.text(text.createHubBrowseAction), findsOneWidget);
    expect(navigator.goes, isEmpty);

    await tester.tap(find.text(text.retryAction));
    await tester.pump();
    expect(repository.requestsFor('retry-template'), hasLength(2));

    repository
        .requestsFor('retry-template')
        .last
        .complete(_template('retry-template'));
    await tester.pump();
    await tester.pump();

    expect(navigator.goes, hasLength(1));
    final destination = navigator.goes.single as TemplatesDestination;
    final session = destination.extra! as TemplatePreviewSession;
    expect(session.initialTemplate.templateId, 'retry-template');
    expect(session.source, TemplatePreviewSource.deepLink);
    expect(session.initialDetailResolved, isTrue);
  });

  testWidgets('loader ignores stale result after template id changes', (
    tester,
  ) async {
    final repository = _ControlledTemplatesRepository();
    final navigator = _RecordingNavigator();
    await _pumpLoader(
      tester,
      templateId: 'template-a',
      repository: repository,
      navigator: navigator,
    );

    await _pumpLoader(
      tester,
      templateId: 'template-b',
      repository: repository,
      navigator: navigator,
    );
    expect(repository.requestedTemplateIds, ['template-a', 'template-b']);

    repository
        .requestsFor('template-b')
        .single
        .complete(_template('template-b'));
    await tester.pump();
    await tester.pump();
    expect(navigator.goes, hasLength(1));
    expect(
      ((navigator.goes.single as TemplatesDestination).extra!
              as TemplatePreviewSession)
          .initialTemplate
          .templateId,
      'template-b',
    );

    repository
        .requestsFor('template-a')
        .single
        .complete(_template('template-a'));
    await tester.pump();
    await tester.pump();
    expect(navigator.goes, hasLength(1));
  });

  testWidgets('loader error can return to the previous route', (tester) async {
    final repository = _ControlledTemplatesRepository();
    final navigator = _RecordingNavigator(canPopResult: true);
    await _pumpLoader(
      tester,
      templateId: 'back-template',
      repository: repository,
      navigator: navigator,
    );

    repository
        .requestsFor('back-template')
        .single
        .completeError(StateError('temporary failure'));
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('template-preview-loader-exit')),
    );
    await tester.pump();
    expect(navigator.popCalls, 1);
    expect(navigator.goes, isEmpty);
  });
}

Future<void> _pumpLoader(
  WidgetTester tester, {
  required String templateId,
  required _ControlledTemplatesRepository repository,
  required _RecordingNavigator navigator,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [templatesRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppNavigationScope(
          navigator: navigator,
          child: TemplatePreviewLoaderPage(templateId: templateId),
        ),
      ),
    ),
  );
  await tester.pump();
}

TemplateItem _template(String id) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.image,
    title: 'Template $id',
    shortDescription: 'Description $id',
    petPhotoRequirements: const ['Clear face'],
    category: 'Magic',
    tags: const ['test'],
    isPremium: false,
    tokenCost: 1,
  );
}

Finder _discoveryVerticalScrollable() {
  return find.descendant(
    of: find.byType(TemplatesDiscoveryPage),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxFrames = 60,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Condition was not reached within the expected frame budget.');
}

final class _TrackingDiscoveryRepository
    implements TemplateDiscoveryRepository {
  _TrackingDiscoveryRepository(this.discovery);

  final TemplateDiscovery discovery;
  int fetchCalls = 0;

  @override
  Future<TemplateDiscovery?> readCached() async => null;

  @override
  Future<TemplateDiscovery> fetch() async {
    fetchCalls++;
    return discovery;
  }

  @override
  void cancelPendingRequest() {}
}

class _ControlledTemplatesRepository extends FakeTemplatesRepository {
  final List<String> requestedTemplateIds = [];
  final Map<String, List<Completer<TemplateItem>>> _requests = {};

  List<Completer<TemplateItem>> requestsFor(String templateId) =>
      _requests[templateId] ?? const [];

  @override
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
    String? analyticsSource,
    int? minimumVersion,
  }) {
    requestedTemplateIds.add(templateId);
    final request = Completer<TemplateItem>();
    _requests.putIfAbsent(templateId, () => []).add(request);
    return request.future;
  }
}

class _RecordingNavigator implements AppNavigator {
  _RecordingNavigator({this.canPopResult = false});

  final bool canPopResult;
  final List<AppDestination> goes = [];
  int popCalls = 0;

  @override
  bool canPop() => canPopResult;

  @override
  void go(AppDestination destination) => goes.add(destination);

  @override
  void pop<T extends Object?>([T? result]) {
    popCalls++;
  }

  @override
  Future<T?> push<T>(AppDestination destination) async => null;

  @override
  void replace(AppDestination destination) {}
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
