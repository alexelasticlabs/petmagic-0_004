import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_home_page.dart';

void main() {
  testWidgets('support home cancels conversation load on disposal', (
    tester,
  ) async {
    final repository = _CancellableSupportChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

  testWidgets('support home keeps load failures distinct from empty chat state', (
    tester,
  ) async {
    final repository = _FailingSupportChatRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
      find.text('Unable to reach support right now. Please try again in a moment.'),
      findsNWidgets(2),
    );
    expect(find.text('Start the conversation'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
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
