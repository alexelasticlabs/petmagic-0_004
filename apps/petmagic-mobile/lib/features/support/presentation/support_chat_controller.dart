import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
        errorMessage: 'support.unavailable',
      );
    }
  }

  Future<void> refresh() async {
    await _refreshConversation();
  }

  Future<void> sendMessage(String value, {required String localeTag}) async {
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
        localeTag: localeTag,
      );

      state = state.copyWith(
        isSending: false,
        conversation: _appendOutgoingMessage(conversation, message),
        clearError: true,
      );
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
    }
  }

  Future<bool> sendImageAttachment(
    XFile file, {
    String? body,
    required String localeTag,
  }) async {
    return sendAttachment(
      filePath: file.path,
      fileName: file.name,
      contentType: resolveContentTypeForUpload(file.path),
      localeTag: localeTag,
      body: body,
    );
  }

  String resolveContentTypeForUpload(String path) {
    return _resolveContentType(path);
  }

  Future<bool> sendAttachment({
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
  }) async {
    final conversation = state.conversation;
    if (conversation == null || state.isSending) {
      return false;
    }

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final message = await _repository.sendAttachment(
        conversationId: conversation.conversationId,
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        localeTag: localeTag,
        body: body,
      );

      state = state.copyWith(
        isSending: false,
        conversation: _appendOutgoingMessage(conversation, message),
        errorMessage: _messageFromAttachmentFailure(message),
        clearError: _messageFromAttachmentFailure(message) == null,
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return message.isAttachmentUploaded;
    } on AppException catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'support.attachment_unavailable',
      );
      return false;
    }
  }

  Future<bool> retryAttachment({
    required String messageId,
    required String filePath,
    required String fileName,
    required String contentType,
  }) async {
    final conversation = state.conversation;
    if (conversation == null || state.isSending) {
      return false;
    }

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final message = await _repository.retryAttachment(
        conversationId: conversation.conversationId,
        messageId: messageId,
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
      );

      final attachmentFailure = _messageFromAttachmentFailure(message);
      state = state.copyWith(
        isSending: false,
        conversation: _upsertMessage(conversation, message),
        errorMessage: attachmentFailure,
        clearError: attachmentFailure == null,
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return message.isAttachmentUploaded;
    } on AppException catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'support.attachment_unavailable',
      );
      return false;
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

  SupportChatConversation _appendOutgoingMessage(
    SupportChatConversation conversation,
    SupportChatMessage message,
  ) {
    return conversation.copyWith(
      status:
          conversation.status == 'Resolved' || conversation.status == 'Closed'
          ? 'Open'
          : conversation.status,
      userUnreadCount: 0,
      adminUnreadCount: conversation.adminUnreadCount + 1,
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      messages: [...conversation.messages, message],
    );
  }

  SupportChatConversation _upsertMessage(
    SupportChatConversation conversation,
    SupportChatMessage message,
  ) {
    final index = conversation.messages.indexWhere(
      (existing) => existing.messageId == message.messageId,
    );
    if (index < 0) {
      return _appendOutgoingMessage(conversation, message);
    }

    final updatedMessages = [...conversation.messages];
    updatedMessages[index] = message;
    return conversation.copyWith(
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      messages: updatedMessages,
    );
  }

  String? _messageFromAttachmentFailure(SupportChatMessage message) {
    if (!message.isAttachmentFailed) {
      return null;
    }

    return message.attachmentUploadErrorCode ?? 'support.attachment_unavailable';
  }

  Future<void> _refreshConversation() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

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
    unawaited(_refreshConversation());
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

  String _resolveContentType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.jpg')) {
      return 'image/jpeg';
    }

    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'application/octet-stream';
  }
}
