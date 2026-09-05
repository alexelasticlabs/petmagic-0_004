import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/application/pet_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_pet_repository_adapter.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'templates_page_lifecycle_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await _cachePetPreviewImage();
  });

  tearDown(() async {
    VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    );
    await PetMagicNotificationCenter.instance.clearQueue();
  });

  testWidgets(
    'upload flow uses template selected inside preview, including its version',
    (tester) async {
      final original = _template(
        'template-original',
        title: 'Original template',
        version: 3,
      );
      final selected = _template(
        'template-selected',
        title: 'Selected after swipe',
        version: 17,
      );
      final generationRepository = _RecordingPetFlowGenerationRepository();

      await _pumpFlow(
        tester,
        items: [original, selected],
        generationRepository: generationRepository,
        selectedFromPreview: selected,
      );

      await tester.tap(find.text('Original template').first);
      await tester.pumpAndSettle();

      expect(find.text('Return swiped template'), findsOneWidget);
      await tester.tap(find.text('Return swiped template'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Create magic'), findsOneWidget);
      await tester.tap(find.text('Create magic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(generationRepository.startFromPetCalls, 1);
      expect(generationRepository.lastTemplateId, selected.templateId);
      expect(generationRepository.lastExpectedTemplateVersion, 17);
      expect(
        find.text('status:generation-pet-1|featured:false'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swiping away from Template of the Day drops featured generation payload',
    (tester) async {
      final featuredTemplate = _template(
        'template-featured',
        title: 'Featured template',
        version: 4,
      );
      final selected = _template(
        'template-selected',
        title: 'Selected after swipe',
        version: 23,
      );
      final featured = TemplateOfTheDayItem(
        templateId: featuredTemplate.templateId,
        title: featuredTemplate.title,
        subtitle: featuredTemplate.shortDescription,
        badgeText: 'Template of the Day',
        templateType: featuredTemplate.templateType,
        isPremium: false,
        requiredPlan: 'free',
        date: DateTime.utc(2026, 9, 4),
        source: 'manual',
        category: featuredTemplate.category,
        tags: featuredTemplate.tags,
        tokenCost: featuredTemplate.tokenCost,
      );
      final templatesRepository = _RecordingTemplatesRepository(
        items: [featuredTemplate, selected],
      );
      final generationRepository = _RecordingPetFlowGenerationRepository();

      await _pumpFlow(
        tester,
        items: [featuredTemplate, selected],
        templateOfTheDay: featured,
        templatesRepository: templatesRepository,
        generationRepository: generationRepository,
        selectedFromPreview: selected,
      );

      await tester.tap(find.byType(TemplateCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return swiped template'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Create magic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(generationRepository.lastTemplateId, selected.templateId);
      expect(generationRepository.lastExpectedTemplateVersion, 23);
      expect(
        templatesRepository.analyticsEvents.where(
          (event) => event.eventType == 'generation_started',
        ),
        isEmpty,
      );
      expect(
        find.text('status:generation-pet-1|featured:false'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selecting Template of the Day from a regular preview keeps featured payload',
    (tester) async {
      final featuredTemplate = _template(
        'template-featured',
        title: 'Featured template',
        version: 41,
      );
      final regularTemplate = _template(
        'template-regular',
        title: 'Regular template',
        version: 5,
      );
      final featured = TemplateOfTheDayItem(
        templateId: featuredTemplate.templateId,
        title: featuredTemplate.title,
        subtitle: featuredTemplate.shortDescription,
        badgeText: 'Template of the Day',
        templateType: featuredTemplate.templateType,
        isPremium: false,
        requiredPlan: 'free',
        date: DateTime.utc(2026, 9, 4),
        source: 'manual',
        category: featuredTemplate.category,
        tags: featuredTemplate.tags,
        tokenCost: featuredTemplate.tokenCost,
      );
      final templatesRepository = _RecordingTemplatesRepository(
        items: [featuredTemplate, regularTemplate],
      );
      final generationRepository = _RecordingPetFlowGenerationRepository();

      await _pumpFlow(
        tester,
        items: [featuredTemplate, regularTemplate],
        templateOfTheDay: featured,
        templatesRepository: templatesRepository,
        generationRepository: generationRepository,
        selectedFromPreview: featuredTemplate,
      );

      await tester.tap(find.text('Regular template').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return swiped template'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Create magic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(generationRepository.lastTemplateId, featuredTemplate.templateId);
      expect(generationRepository.lastExpectedTemplateVersion, 41);
      expect(
        templatesRepository.analyticsEvents.where(
          (event) =>
              event.templateId == featuredTemplate.templateId &&
              event.eventType == 'generation_started',
        ),
        hasLength(1),
      );
      expect(
        find.text('status:generation-pet-1|featured:true'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpFlow(
  WidgetTester tester, {
  required List<TemplateItem> items,
  required _RecordingPetFlowGenerationRepository generationRepository,
  required TemplateItem selectedFromPreview,
  TemplateOfTheDayItem? templateOfTheDay,
  _RecordingTemplatesRepository? templatesRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository =
      templatesRepository ?? _RecordingTemplatesRepository(items: items);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: TemplatesPage(
            initialPetId: 'pet-42',
            initialPetPhotoId: 'photo-7',
          ),
        ),
      ),
      GoRoute(
        path: '${TemplatePreviewPage.routePath}/:templateId',
        builder: (context, state) {
          final args = state.extra! as TemplatePreviewRouteArgs;
          expect(
            state.pathParameters['templateId'],
            args.effectiveSession.initialTemplate.templateId,
          );
          expect(
            args.effectiveSession.items.map((item) => item.templateId),
            containsAll(items.map((item) => item.templateId)),
          );
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop<Object?>(
                  TemplatePreviewResult(
                    action: TemplateDetailAction.upload,
                    selectedTemplate: selectedFromPreview,
                  ),
                ),
                child: const Text('Return swiped template'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '${GenerationStatusPage.routePrefix}/:generationId',
        builder: (context, state) => Scaffold(
          body: Text(
            'status:${state.pathParameters['generationId'] ?? ''}'
            '|featured:${state.extra is TemplateOfTheDayItem}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          AuthenticatedAppLaunchController.new,
        ),
        walletControllerProvider.overrideWith(FundedWalletController.new),
        profileControllerProvider.overrideWith(FakeProfileController.new),
        templatesControllerProvider.overrideWith(
          () => FakeTemplatesController(
            items: items,
            templateOfTheDay: templateOfTheDay,
          ),
        ),
        templatesRepositoryProvider.overrideWithValue(repository),
        templateGenerationRepositoryProvider.overrideWithValue(
          generationRepository,
        ),
        petRepositoryProvider.overrideWithValue(
          TemplateGenerationPetRepositoryAdapter(generationRepository),
        ),
        generationHistoryControllerProvider.overrideWith(
          IdleTemplatesGenerationHistoryController.new,
        ),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
      ],
      child: MaterialApp.router(
        builder: (context, child) => AppNavigationScope(
          navigator: GoRouterAppNavigator(router),
          child: child!,
        ),
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

TemplateItem _template(
  String id, {
  required String title,
  required int version,
}) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.image,
    title: title,
    shortDescription: '$title description',
    petPhotoRequirements: const ['Clear photo'],
    category: 'Portrait',
    tags: const ['pet'],
    isPremium: false,
    tokenCost: 1,
    version: version,
  );
}

class _RecordingPetFlowGenerationRepository
    extends PetFlowGenerationRepository {
  int? lastExpectedTemplateVersion;

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
  }) {
    lastExpectedTemplateVersion = expectedTemplateVersion;
    return super.startGenerationFromPet(
      petId: petId,
      petPhotoId: petPhotoId,
      templateId: templateId,
      expectedTemplateVersion: expectedTemplateVersion,
      correlationId: correlationId,
      cancelToken: cancelToken,
    );
  }
}

class _RecordingTemplatesRepository extends RandomTemplatesRepository {
  _RecordingTemplatesRepository({required super.items});

  final analyticsEvents =
      <({String templateId, String eventType, String? generationId})>[];

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {
    analyticsEvents.add((
      templateId: templateId,
      eventType: eventType,
      generationId: generationId,
    ));
  }
}

Future<void> _cachePetPreviewImage() async {
  final codec = await ui.instantiateImageCodec(
    Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    ),
  );
  final frame = await codec.getNextFrame();
  for (final maxWidth in const [180, 760]) {
    final provider = CachedNetworkImageProvider(
      'https://cdn.petgpt.app/pet-thumb.jpg',
      cacheKey: persistentSafeGenerationMediaUrl(
        'https://cdn.petgpt.app/pet-thumb.jpg',
      ),
      maxWidth: maxWidth,
    );
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: frame.image)),
      ),
    );
  }
}
