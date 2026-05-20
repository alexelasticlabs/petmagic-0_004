import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';

final supportChatControllerProvider =
    NotifierProvider<SupportChatController, SupportChatState>(
      SupportChatController.new,
    );

class SupportChatState {
  const SupportChatState({
    required this.isLoading,
    required this.isRefreshing,
    required this.isSending,
    this.conversation,
    this.errorMessage,
  });

  const SupportChatState.initial()
    : this(isLoading: true, isRefreshing: false, isSending: false);

  final bool isLoading;
  final bool isRefreshing;
  final bool isSending;
  final SupportChatConversation? conversation;
  final String? errorMessage;

  SupportChatState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isSending,
    SupportChatConversation? conversation,
    String? errorMessage,
    bool clearConversation = false,
    bool clearError = false,
  }) {
    return SupportChatState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSending: isSending ?? this.isSending,
      conversation: clearConversation
          ? null
          : (conversation ?? this.conversation),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SupportChatController extends Notifier<SupportChatState> {
  late final SupportChatRepository _repository;
  late final SupportChatRealtimeClient _realtimeClient;
  StreamSubscription<SupportChatRealtimeUpdate>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  bool _hasPendingRealtimeRefresh = false;
  bool _started = false;

  @override
  SupportChatState build() {
    _repository = ref.watch(supportChatRepositoryProvider);
    _realtimeClient = ref.watch(supportChatRealtimeClientProvider);
    return const SupportChatState.initial();
  }

  void stop() {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    unawaited(_realtimeClient.disconnect());
    _started = false;
    _hasPendingRealtimeRefresh = false;
  }

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    await initialize();
    _realtimeSubscription ??= _realtimeClient.events.listen(
      _handleRealtimeUpdate,
    );
    try {
      await _realtimeClient.connect();
    } on Object {
      // Realtime is best-effort; keep the chat usable over REST even if the hub is unavailable.
    }
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversation = await _repository.openConversation();
      state = state.copyWith(
        isLoading: false,
        conversation: conversation,
        clearError: true,
      );
      await _markReadIfNeeded(conversation);
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Unable to reach support right now. Please try again in a moment.',
      );
    }
  }

  Future<void> refresh() async {
    await _refreshConversation(showLoading: false);
  }

  Future<void> sendMessage(String value) async {
    final body = value.trim();
    final conversation = state.conversation;
    if (body.isEmpty || conversation == null || state.isSending) {
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final message = await _repository.sendMessage(
        conversationId: conversation.conversationId,
        body: body,
      );

      state = state.copyWith(
        isSending: false,
        conversation: conversation.copyWith(
          assignedAdminId: conversation.assignedAdminId,
          assignedAdminDisplayName: conversation.assignedAdminDisplayName,
          status:
              conversation.status == 'Resolved' ||
                  conversation.status == 'Closed'
              ? 'Open'
              : conversation.status,
          userUnreadCount: 0,
          adminUnreadCount: conversation.adminUnreadCount + 1,
          updatedAtUtc: message.createdAtUtc,
          lastMessageAtUtc: message.createdAtUtc,
          messages: [...conversation.messages, message],
        ),
        clearError: true,
      );
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
    }
  }

  void _handleRealtimeUpdate(SupportChatRealtimeUpdate event) {
    final activeConversationId = state.conversation?.conversationId;
    if (activeConversationId != null &&
        activeConversationId != event.conversationId) {
      return;
    }

    _hasPendingRealtimeRefresh = true;
    _scheduleRealtimeRefresh();
  }

  Future<void> _refreshConversation({required bool showLoading}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(isRefreshing: true, clearError: true);
    }

    try {
      final conversation = await _repository.getConversation();
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        conversation: conversation,
        clearError: true,
      );

      if (conversation.userUnreadCount > 0) {
        await _markReadIfNeeded(conversation);
      }
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.message,
      );
    }
  }

  bool get _isConversationBusy =>
      state.isLoading || state.isRefreshing || state.isSending;

  void _scheduleRealtimeRefresh() {
    if (_isConversationBusy) {
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(
      const Duration(milliseconds: 350),
      _flushPendingRealtimeRefresh,
    );
  }

  void _flushPendingRealtimeRefresh() {
    _realtimeRefreshTimer = null;
    if (!_hasPendingRealtimeRefresh || _isConversationBusy) {
      return;
    }

    _hasPendingRealtimeRefresh = false;
    unawaited(_refreshConversation(showLoading: false));
  }

  void _resumePendingRealtimeRefreshIfNeeded() {
    if (_hasPendingRealtimeRefresh) {
      _scheduleRealtimeRefresh();
    }
  }

  Future<void> _markReadIfNeeded(SupportChatConversation conversation) async {
    if (conversation.userUnreadCount <= 0) {
      return;
    }

    final now = DateTime.now().toUtc();
    try {
      await _repository.markConversationRead(conversation.conversationId);
      final updatedMessages = conversation.messages
          .map(
            (message) => message.isFromAdmin && !message.isRead
                ? message.copyWith(isRead: true, readAtUtc: now)
                : message,
          )
          .toList(growable: false);

      state = state.copyWith(
        conversation: conversation.copyWith(
          userUnreadCount: 0,
          messages: updatedMessages,
        ),
      );
    } on AppException {
      // Keep realtime refresh resilient; the next event or manual refresh will try again.
    }
  }
}
