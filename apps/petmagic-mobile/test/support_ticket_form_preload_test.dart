import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_ticket_form_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'test_permission_fakes.dart';

late _SupportPreloadTracker _preloadTracker;

void main() {
  setUp(() {
    _preloadTracker = _SupportPreloadTracker();
  });

  test('support ticket route preserves scenario query', () {
    expect(
      SupportTicketFormPage.location('generation_failed'),
      '/profile/support/ticket?scenario=generation_failed',
    );
    expect(
      SupportTicketFormPage.location('  '),
      SupportTicketFormPage.routePath,
    );
  });

  testWidgets(
    'support ticket context preload starts independent loads together',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            generationHistoryControllerProvider.overrideWith(
              _TrackedGenerationHistoryController.new,
            ),
            walletControllerProvider.overrideWith(_TrackedWalletController.new),
            premiumControllerProvider.overrideWith(
              _TrackedPremiumController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SupportTicketFormPage(scenario: 'generation_failed'),
          ),
        ),
      );

      await tester.pump();

      expect(
        _preloadTracker.started,
        containsAll(['generation', 'wallet', 'premium']),
      );

      _preloadTracker.completeAll();
      await tester.pump();
    },
  );

  testWidgets('support ticket context preload is skipped for guests', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedAppLaunchController.new,
          ),
          generationHistoryControllerProvider.overrideWith(
            _TrackedGenerationHistoryController.new,
          ),
          walletControllerProvider.overrideWith(_TrackedWalletController.new),
          premiumControllerProvider.overrideWith(_TrackedPremiumController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SupportTicketFormPage(scenario: 'generation_failed'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(_preloadTracker.started, isEmpty);
  });

  testWidgets(
    'support ticket context preload starts after guest signs in on the same route',
    (tester) async {
      final launchController = _MutableAppLaunchController(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(() => launchController),
            generationHistoryControllerProvider.overrideWith(
              _TrackedGenerationHistoryController.new,
            ),
            walletControllerProvider.overrideWith(_TrackedWalletController.new),
            premiumControllerProvider.overrideWith(
              _TrackedPremiumController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SupportTicketFormPage(scenario: 'generation_failed'),
          ),
        ),
      );

      await tester.pump();
      expect(_preloadTracker.started, isEmpty);

      launchController.setAuthenticated(true);
      await tester.pump();

      expect(
        _preloadTracker.started,
        containsAll(['generation', 'wallet', 'premium']),
      );

      _preloadTracker.completeAll();
      await tester.pump();
    },
  );

  testWidgets(
    'support ticket context preload skips domains that already have snapshots',
    (tester) async {
      final generationController = _CountingLoadedGenerationHistoryController();
      final walletController = _CountingLoadedWalletController();
      final premiumController = _CountingLoadedPremiumController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            generationHistoryControllerProvider.overrideWith(
              () => generationController,
            ),
            walletControllerProvider.overrideWith(() => walletController),
            premiumControllerProvider.overrideWith(() => premiumController),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SupportTicketFormPage(scenario: 'generation_failed'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(generationController.loadCalls, 0);
      expect(walletController.loadCalls, 0);
      expect(premiumController.loadCalls, 0);
    },
  );

  testWidgets('support ticket submit skips attachment uploads after disposal', (
    tester,
  ) async {
    final repository = _DelayedSupportChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          supportChatRepositoryProvider.overrideWithValue(repository),
          generationHistoryControllerProvider.overrideWith(
            _IdleGenerationHistoryController.new,
          ),
          walletControllerProvider.overrideWith(_IdleWalletController.new),
          premiumControllerProvider.overrideWith(_IdlePremiumController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SupportTicketFormPage(
            scenario: 'generation_failed',
            initialAttachments: [XFile('/tmp/petmagic-support-test.jpg')],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Generation failed.');
    await tester.tap(find.byType(FilledButton));
    await repository.openStarted.future;
    expect(repository.openCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(repository.openCancelToken?.isCancelled, isTrue);

    repository.completeOpen();
    await tester.pump();

    expect(repository.sendAttachmentCalls, 0);
  });

  testWidgets(
    'support ticket gallery denial shows localized warning with settings action',
    (tester) async {
      addTearDown(() async {
        await PetMagicNotificationCenter.instance.clearQueue();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            generationHistoryControllerProvider.overrideWith(
              _IdleGenerationHistoryController.new,
            ),
            walletControllerProvider.overrideWith(_IdleWalletController.new),
            premiumControllerProvider.overrideWith(_IdlePremiumController.new),
            appPermissionCoordinatorProvider.overrideWithValue(
              FakeAppPermissionCoordinator(
                states: const {
                  AppPermissionType.photos:
                      AppPermissionState.permanentlyDenied,
                },
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SupportTicketFormPage(scenario: 'generation_failed'),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Add screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pump();

      final notification = PetMagicNotificationCenter.instance.current;
      expect(
        notification?.message,
        'Gallery access is off. Open device settings to allow it.',
      );
      expect(notification?.action?.label, 'Open settings');
      await PetMagicNotificationCenter.instance.clearQueue();
      await tester.pump();
    },
  );

  test('support ticket form uses a lazy scroll surface', () async {
    final source = await File(
      'lib/features/support/presentation/support_ticket_form_content.part.dart',
    ).readAsString();
    final buildBody = _methodBody(source, 'Widget build');

    expect(buildBody, contains('child: ListView('));
    expect(buildBody, isNot(contains('SingleChildScrollView(')));
  });
}

class _SupportPreloadTracker {
  final started = <String>[];
  final _completers = <String, Completer<void>>{
    'generation': Completer<void>(),
    'wallet': Completer<void>(),
    'premium': Completer<void>(),
  };

  Future<void> start(String name) {
    started.add(name);
    return _completers[name]!.future;
  }

  void completeAll() {
    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
}

String _methodBody(String source, String signature) {
  final signatureIndex = source.indexOf(signature);
  expect(signatureIndex, isNonNegative, reason: 'Missing $signature');
  final openBraceIndex = source.indexOf('{', signatureIndex);
  expect(openBraceIndex, isNonNegative, reason: 'Missing $signature body');

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }
    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('$signature body did not close.');
}

class _UnauthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _MutableAppLaunchController extends AppLaunchController {
  _MutableAppLaunchController(this._isAuthenticated);

  bool _isAuthenticated;

  @override
  AppLaunchState build() {
    return AppLaunchState(
      isLoading: false,
      isAuthenticated: _isAuthenticated,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: value,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
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

class _TrackedGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  Future<void> load({GenerationHistoryFilter? filter, bool refresh = false}) {
    return _preloadTracker.start('generation');
  }
}

class _TrackedWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) {
    return _preloadTracker.start('wallet');
  }
}

class _TrackedPremiumController extends PremiumController {
  @override
  PremiumState build() {
    return const PremiumState();
  }

  @override
  Future<void> load({bool refresh = false}) {
    return _preloadTracker.start('premium');
  }
}

class _IdleGenerationHistoryController extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  Future<void> load({GenerationHistoryFilter? filter, bool refresh = false}) {
    return Future<void>.value();
  }
}

class _IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) {
    return Future<void>.value();
  }
}

class _IdlePremiumController extends PremiumController {
  @override
  PremiumState build() {
    return const PremiumState();
  }

  @override
  Future<void> load({bool refresh = false}) {
    return Future<void>.value();
  }
}

class _CountingLoadedGenerationHistoryController
    extends GenerationHistoryController {
  int loadCalls = 0;

  @override
  GenerationHistoryState build() {
    return GenerationHistoryState(
      items: [
        TemplateGenerationResult(
          generationId: 'generation-1',
          userId: 'user-1',
          templateId: 'template-1',
          templateTitle: 'Magic Portrait',
          templateType: 'Image',
          status: TemplateGenerationStatus.completed,
          tokenCost: 12,
          attemptCount: 1,
          createdAtUtc: DateTime.utc(2026, 1, 1, 10),
          updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 1),
          userMediaExpired: false,
        ),
      ],
    );
  }

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    loadCalls++;
  }
}

class _CountingLoadedWalletController extends WalletController {
  int loadCalls = 0;

  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 130,
        adRewardsRemainingToday: 3,
        isPremium: false,
        updatedAtUtc: null,
        nextWeeklyGrantAtUtc: null,
      ),
      purchases: [
        PurchaseHistoryItem(
          orderId: '00000000-0000-4000-8000-000000000001',
          packDisplayName: 'Starter Pack',
          paymentProvider: 'Stripe',
          status: 'Succeeded',
          priceAmount: 9.99,
          currencyCode: 'USD',
          sparkToGrant: 100,
          createdAtUtc: DateTime.utc(2026, 1, 1, 9, 30),
        ),
      ],
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
  }
}

class _CountingLoadedPremiumController extends PremiumController {
  int loadCalls = 0;

  @override
  PremiumState build() {
    return PremiumState(
      status: PremiumStatusModel(
        isPremium: true,
        canManageBilling: true,
        status: 'active',
        cancelAtPeriodEnd: false,
        monthlyTokenLimit: 1200,
        tokensAvailable: 300,
        canManageSubscription: true,
        manageSubscriptionAction: 'StripeCustomerPortal',
      ),
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
  }
}

class _DelayedSupportChatRepository extends SupportChatRepository {
  _DelayedSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final openStarted = Completer<void>();
  final _openCompleter = Completer<SupportChatConversation>();
  CancelToken? openCancelToken;
  int sendAttachmentCalls = 0;

  @override
  Future<SupportChatConversation> openConversation({
    String? initialMessage,
    String source = 'MobileChat',
    String? assistantScenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
    String? relatedSubscriptionId,
    CancelToken? cancelToken,
  }) {
    openCancelToken = cancelToken;
    if (!openStarted.isCompleted) {
      openStarted.complete();
    }
    return _openCompleter.future;
  }

  void completeOpen() {
    _openCompleter.complete(_supportConversation());
  }

  @override
  Future<SupportChatMessage> sendAttachment({
    required String conversationId,
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    sendAttachmentCalls += 1;
    return SupportChatMessage(
      messageId: 'attachment-message-1',
      conversationId: conversationId,
      senderUserId: 'user-1',
      senderDisplayName: 'Pet Parent',
      isFromAdmin: false,
      senderType: 'User',
      body: '',
      isRead: false,
      attachments: const [],
      createdAtUtc: DateTime.utc(2026, 1, 1, 10, 1),
    );
  }
}

SupportChatConversation _supportConversation() {
  return SupportChatConversation(
    conversationId: 'conversation-1',
    initiatorUserId: 'user-1',
    userEmail: 'pet@example.com',
    userDisplayName: 'Pet Parent',
    assignedAdminId: null,
    assignedAdminDisplayName: null,
    status: 'WaitingForSupport',
    priority: 'Normal',
    source: 'MobileAssistant',
    userUnreadCount: 0,
    adminUnreadCount: 1,
    createdAtUtc: DateTime.utc(2026, 1, 1, 10),
    updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 1),
    lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 1),
    messages: const [],
  );
}
