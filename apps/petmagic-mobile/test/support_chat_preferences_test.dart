import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support_chat_test_support.dart';
import 'widget_test_support.dart';

void main() {
  configureWidgetTestHarness();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('support chat controller loads existing messages', () async {
    final supportRepository = FakeSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        supportChatRepositoryProvider.overrideWith((ref) => supportRepository),
        supportChatRealtimeClientProvider.overrideWith(
          (ref) => const FakeSupportChatRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(supportChatControllerProvider.notifier).initialize();

    final state = container.read(supportChatControllerProvider);
    expect(state.conversation, isNotNull);
    expect(state.conversation?.assignedAdminDisplayName, 'PetMagic Support');
    expect(state.conversation?.messages.first.body, 'How can we help today?');
    expect(state.conversation?.userUnreadCount, 0);
  });

  test('support chat controller sends a new message', () async {
    final supportRepository = FakeSupportChatRepository();
    final container = ProviderContainer(
      overrides: [
        supportChatRepositoryProvider.overrideWith((ref) => supportRepository),
        supportChatRealtimeClientProvider.overrideWith(
          (ref) => const FakeSupportChatRealtimeClient(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(supportChatControllerProvider.notifier);
    await controller.initialize();
    await controller.sendMessage('I need billing help', localeTag: 'en');

    final state = container.read(supportChatControllerProvider);
    expect(supportRepository.lastSentBody, 'I need billing help');
    expect(
      state.conversation?.messages.any(
        (message) => message.body == 'I need billing help',
      ),
      isTrue,
    );
  });

  test(
    'support chat controller creates conversation on first message',
    () async {
      final supportRepository = FakeSupportChatRepository(
        hasConversation: false,
      );
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const FakeSupportChatRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(supportChatControllerProvider.notifier);
      await controller.initialize();
      expect(
        container.read(supportChatControllerProvider).conversation,
        isNull,
      );

      await controller.sendMessage('Need help with tokens', localeTag: 'en');

      final state = container.read(supportChatControllerProvider);
      expect(supportRepository.openConversationCalls, 1);
      expect(
        supportRepository.lastOpenedInitialMessage,
        'Need help with tokens',
      );
      expect(supportRepository.lastOpenedRelatedGenerationId, isNull);
      expect(state.conversation, isNotNull);
      expect(
        state.conversation?.messages.any(
          (message) => message.body == 'Need help with tokens',
        ),
        isTrue,
      );
    },
  );

  test(
    'support chat controller attaches related generation to first message',
    () async {
      final supportRepository = FakeSupportChatRepository(
        hasConversation: false,
      );
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const FakeSupportChatRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(supportChatControllerProvider.notifier);
      await controller.initialize();
      await controller.sendMessage(
        'Generation issue',
        localeTag: 'en',
        relatedGenerationId: 'generation-router',
      );

      expect(supportRepository.openConversationCalls, 1);
      expect(
        supportRepository.lastOpenedRelatedGenerationId,
        'generation-router',
      );
    },
  );

  test(
    'support chat controller clears loading state on unexpected error',
    () async {
      final supportRepository = ThrowingSupportChatRepository();
      final container = ProviderContainer(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const FakeSupportChatRealtimeClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(supportChatControllerProvider.notifier).initialize();

      final state = container.read(supportChatControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.conversation, isNull);
      expect(state.errorMessage, 'support.unavailable');
    },
  );

  testWidgets(
    'support chat page shows retry fallback when initial load takes too long',
    (tester) async {
      final supportRepository = DelayedSupportChatRepository();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportChatRepositoryProvider.overrideWith(
              (ref) => supportRepository,
            ),
            appLaunchControllerProvider.overrideWith(
              AuthenticatedWidgetAppLaunchController.new,
            ),
            supportChatRealtimeClientProvider.overrideWith(
              (ref) => const FakeSupportChatRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SupportChatPage(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));

      expect(find.text('Start the conversation'), findsOneWidget);
      expect(
        find.text(
          'Unable to reach support right now. Please try again in a moment.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets('support chat page renders support header and security card', (
    tester,
  ) async {
    final supportRepository = FakeSupportChatRepository();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          appLaunchControllerProvider.overrideWith(
            AuthenticatedWidgetAppLaunchController.new,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const FakeSupportChatRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SupportChatPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Your conversation is protected. We use it only for support.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.text('PetMagic Support'), findsWidgets);
    expect(find.text('We usually reply within 24 hours'), findsWidgets);
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
  });

  testWidgets('support chat page preloads generation report context', (
    tester,
  ) async {
    final supportRepository = FakeSupportChatRepository(hasConversation: false);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          appLaunchControllerProvider.overrideWith(
            AuthenticatedWidgetAppLaunchController.new,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const FakeSupportChatRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SupportChatPage(
            initialMessage: 'Report a problem\nRelated generation: g-ready-1',
            relatedGenerationId: 'g-ready-1',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(find.byType(TextField).last);
    expect(
      composer.controller?.text,
      'Report a problem\nRelated generation: g-ready-1',
    );
  });

  testWidgets('support chat page shows welcome actions for empty chat', (
    tester,
  ) async {
    final supportRepository = FakeSupportChatRepository(
      emptyConversation: true,
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportChatRepositoryProvider.overrideWith(
            (ref) => supportRepository,
          ),
          appLaunchControllerProvider.overrideWith(
            AuthenticatedWidgetAppLaunchController.new,
          ),
          supportChatRealtimeClientProvider.overrideWith(
            (ref) => const FakeSupportChatRealtimeClient(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SupportChatPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final text = AppLocalizations.of(
      tester.element(find.byType(SupportChatPage)),
    );

    expect(find.text(text.supportChatWelcomeBody), findsOneWidget);
    expect(find.text(text.supportHomeTopicGenerationIssue), findsOneWidget);
    expect(find.text(text.supportHomeTopicPaymentRefund), findsOneWidget);
    expect(find.text(text.supportHomeTopicTokensNotArrived), findsOneWidget);
  });

  testWidgets(
    'support chat keeps real admin replies visible even when body matches old system prefixes',
    (tester) async {
      final supportRepository = FakeSupportChatRepository()
        ..seedConversation(
          SupportChatConversation(
            conversationId: 'conversation-admin-prefix-1',
            initiatorUserId: 'user-1',
            userEmail: 'pet@example.com',
            userDisplayName: 'Pet Parent',
            assignedAdminId: 'admin-1',
            assignedAdminDisplayName: 'PetMagic Support',
            status: 'Open',
            priority: 'Normal',
            source: 'Direct',
            userUnreadCount: 0,
            adminUnreadCount: 0,
            createdAtUtc: DateTime.utc(2026, 1, 1, 10),
            updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
            lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
            messages: [
              SupportChatMessage(
                messageId: 'message-admin-prefix-1',
                conversationId: 'conversation-admin-prefix-1',
                senderUserId: 'admin-1',
                senderDisplayName: 'PetMagic Support',
                isFromAdmin: true,
                senderType: 'Admin',
                body:
                    'Message received from billing provider. We still need your last receipt screenshot.',
                isRead: true,
                attachments: const [],
                createdAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
              ),
            ],
          ),
        );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportChatRepositoryProvider.overrideWith(
              (ref) => supportRepository,
            ),
            appLaunchControllerProvider.overrideWith(
              AuthenticatedWidgetAppLaunchController.new,
            ),
            supportChatRealtimeClientProvider.overrideWith(
              (ref) => const FakeSupportChatRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SupportChatPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Message received from billing provider. We still need your last receipt screenshot.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'support chat attachment bubble does not overflow on narrow screens',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(320, 720);
      view.devicePixelRatio = 1.0;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      const longFileName =
          'ultra-super-mega-long-support-attachment-file-name-for-mobile-overflow-regression-check-2026-final-version.pdf';

      final supportRepository = FakeSupportChatRepository()
        ..seedConversation(
          SupportChatConversation(
            conversationId: 'conversation-overflow-1',
            initiatorUserId: 'user-1',
            userEmail: 'pet@example.com',
            userDisplayName: 'Pet Parent',
            assignedAdminId: 'admin-1',
            assignedAdminDisplayName: 'PetMagic Support',
            status: 'Open',
            priority: 'Normal',
            source: 'Direct',
            userUnreadCount: 0,
            adminUnreadCount: 0,
            createdAtUtc: DateTime.utc(2026, 1, 1, 10),
            updatedAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
            lastMessageAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
            messages: [
              SupportChatMessage(
                messageId: 'message-replied',
                conversationId: 'conversation-overflow-1',
                senderUserId: 'admin-1',
                senderDisplayName: 'PetMagic Support',
                isFromAdmin: true,
                senderType: 'Admin',
                body:
                    'Please attach the file so we can investigate this issue.',
                isRead: true,
                attachments: const [],
                createdAtUtc: DateTime.utc(2026, 1, 1, 10, 5),
              ),
              SupportChatMessage(
                messageId: 'message-attachment',
                conversationId: 'conversation-overflow-1',
                senderUserId: 'user-1',
                senderDisplayName: 'Pet Parent',
                isFromAdmin: false,
                senderType: 'User',
                body: '',
                replyToMessageId: 'message-replied',
                replyToPreview: 'Please attach the file so we can investigate.',
                isRead: false,
                attachments: const [
                  SupportChatAttachment(
                    fileUrl: 'https://example.com/files/attachment.pdf',
                    type: 'file',
                    mimeType: 'application/pdf',
                    fileName: longFileName,
                    sizeBytes: 245760,
                  ),
                ],
                createdAtUtc: DateTime.utc(2026, 1, 1, 10, 6),
              ),
            ],
          ),
        );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportChatRepositoryProvider.overrideWith(
              (ref) => supportRepository,
            ),
            appLaunchControllerProvider.overrideWith(
              AuthenticatedWidgetAppLaunchController.new,
            ),
            supportChatRealtimeClientProvider.overrideWith(
              (ref) => const FakeSupportChatRealtimeClient(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SupportChatPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.textContaining('Please attach the file'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  test('app preferences controller persists theme and locale', () async {
    SharedPreferences.setMockInitialValues(const {});

    final firstContainer = ProviderContainer();
    addTearDown(firstContainer.dispose);

    firstContainer.read(appPreferencesControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final firstController = firstContainer.read(
      appPreferencesControllerProvider.notifier,
    );

    await firstController.updateThemeMode(ThemeMode.dark);
    await firstController.updateLocale(const Locale('en'));

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    secondContainer.read(appPreferencesControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final loadedState = secondContainer.read(appPreferencesControllerProvider);
    expect(loadedState.themeMode, ThemeMode.dark);
    expect(loadedState.locale, const Locale('en'));
  });

  test(
    'app preferences controller preserves stored country-specific locale',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(const {
            'petmagic_mobile_locale': 'en_US',
          });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appPreferencesControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(appPreferencesControllerProvider);
      expect(state.locale, const Locale('en', 'US'));
    },
  );
}
