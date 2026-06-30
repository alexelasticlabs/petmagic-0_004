import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_home_page.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

void main() {
  testWidgets('support home shows auth gate for guests without loading chat', (
    tester,
  ) async {
    final repository = _CountingSupportChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _UnauthenticatedAppLaunchController.new,
          ),
          supportChatRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          home: const SupportHomePage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(repository.getConversationCalls, 0);
  });

  testWidgets('support home cancels conversation load on disposal', (
    tester,
  ) async {
    final repository = _CancellableSupportChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(
            _AuthenticatedAppLaunchController.new,
          ),
          supportChatRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(),
          home: const SupportHomePage(),
        ),
      ),
    );

    await repository.loadStarted.future;
    final cancelToken = repository.lastCancelToken;
    expect(cancelToken, isNotNull);
    expect(cancelToken!.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cancelToken.isCancelled, isTrue);
  });

  testWidgets(
    'support home keeps load failures distinct from empty chat state',
    (tester) async {
      final repository = _FailingSupportChatRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(
              _AuthenticatedAppLaunchController.new,
            ),
            supportChatRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            home: const SupportHomePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Unable to reach support right now. Please try again in a moment.',
        ),
        findsNWidgets(2),
      );
      expect(find.text('Start the conversation'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'support home clears stale conversation on sign out and reloads on next sign in',
    (tester) async {
      final launchController = _MutableAppLaunchController(true);
      final repository = _SequencedSupportChatRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLaunchControllerProvider.overrideWith(() => launchController),
            supportChatRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            home: const SupportHomePage(),
          ),
        ),
      );

      await tester.pump();
      expect(repository.getConversationCalls, 1);

      repository.completeNext(_conversation(displayName: 'Old User'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Old User'), findsOneWidget);

      launchController.setAuthenticated(false);
      await tester.pump();

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(find.text('Old User'), findsNothing);

      launchController.setAuthenticated(true);
      await tester.pump();

      expect(repository.getConversationCalls, 2);
      expect(find.text('Old User'), findsNothing);

      repository.completeNext(_conversation(displayName: 'New User'));
      await tester.pump();
      await tester.pump();

      expect(find.text('New User'), findsOneWidget);
    },
  );
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
      guestSessionReady: _isAuthenticated,
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

class _CountingSupportChatRepository extends SupportChatRepository {
  _CountingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int getConversationCalls = 0;

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) {
    getConversationCalls++;
    throw AppException('support.unavailable', statusCode: 503);
  }
}

class _CancellableSupportChatRepository extends SupportChatRepository {
  _CancellableSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final Completer<void> loadStarted = Completer<void>();
  CancelToken? lastCancelToken;

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) {
    lastCancelToken = cancelToken;
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
    }

    return Completer<SupportChatConversation>().future;
  }
}

class _FailingSupportChatRepository extends SupportChatRepository {
  _FailingSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) {
    throw AppException('support.unavailable', statusCode: 503);
  }
}

class _SequencedSupportChatRepository extends SupportChatRepository {
  _SequencedSupportChatRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  final List<Completer<SupportChatConversation>> _pendingLoads =
      <Completer<SupportChatConversation>>[];
  int getConversationCalls = 0;

  @override
  Future<SupportChatConversation> getConversation({
    int take = 60,
    DateTime? beforeMessageCreatedAtUtc,
    String? beforeMessageId,
    CancelToken? cancelToken,
  }) {
    getConversationCalls++;
    final completer = Completer<SupportChatConversation>();
    _pendingLoads.add(completer);
    return completer.future;
  }

  void completeNext(SupportChatConversation conversation) {
    final completer = _pendingLoads.removeAt(0);
    completer.complete(conversation);
  }
}

SupportChatConversation _conversation({required String displayName}) {
  final now = DateTime.utc(2026, 6, 30, 12);
  return SupportChatConversation(
    conversationId: 'conversation-$displayName',
    initiatorUserId: 'user-1',
    userEmail: 'user@example.com',
    userDisplayName: displayName,
    assignedAdminId: null,
    assignedAdminDisplayName: null,
    status: 'Open',
    priority: 'Normal',
    source: 'MobileAssistant',
    userUnreadCount: 0,
    adminUnreadCount: 0,
    createdAtUtc: now,
    updatedAtUtc: now,
    lastMessageAtUtc: now,
    messages: const <SupportChatMessage>[],
  );
}
