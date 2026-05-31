import 'dart:async';

import 'package:flutter/widgets.dart';
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
    required this.isLoadingOlder,
    this.conversation,
    this.errorMessage,
    this.sendProgress,
    this.sendingAttachmentIndex,
    this.sendingAttachmentTotal,
  });

  const SupportChatState.initial()
    : this(
        isLoading: true,
        isRefreshing: false,
        isSending: false,
        isLoadingOlder: false,
      );

  final bool isLoading;
  final bool isRefreshing;
  final bool isSending;
  final bool isLoadingOlder;
  final SupportChatConversation? conversation;
  final String? errorMessage;
  final double? sendProgress;
  final int? sendingAttachmentIndex;
  final int? sendingAttachmentTotal;

  SupportChatState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isSending,
    bool? isLoadingOlder,
    SupportChatConversation? conversation,
    String? errorMessage,
    bool clearConversation = false,
    bool clearError = false,
    double? sendProgress,
    int? sendingAttachmentIndex,
    int? sendingAttachmentTotal,
    bool clearSendProgress = false,
  }) {
    return SupportChatState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSending: isSending ?? this.isSending,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      conversation: clearConversation
          ? null
          : (conversation ?? this.conversation),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sendProgress: clearSendProgress
          ? null
          : (sendProgress ?? this.sendProgress),
      sendingAttachmentIndex: clearSendProgress
          ? null
          : (sendingAttachmentIndex ?? this.sendingAttachmentIndex),
      sendingAttachmentTotal: clearSendProgress
          ? null
          : (sendingAttachmentTotal ?? this.sendingAttachmentTotal),
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
  bool _isScreenVisible = true;

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
    _isScreenVisible = false;
  }

  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) {
      return;
    }

    _isScreenVisible = visible;
    if (_isScreenVisible) {
      _resumePendingRealtimeRefreshIfNeeded();
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
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
      final conversation = await _repository.getConversation();
      state = state.copyWith(
        isLoading: false,
        conversation: conversation,
        clearError: true,
      );
      state = state.copyWith(isLoadingOlder: false);
      await _markReadIfNeeded(conversation);
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      if (_isConversationNotFound(error.message)) {
        state = state.copyWith(
          isLoading: false,
          clearConversation: true,
          clearError: true,
        );
        _resumePendingRealtimeRefreshIfNeeded();
      } else {
        state = state.copyWith(isLoading: false, errorMessage: error.message);
      }
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

  Future<bool> sendMessage(
    String value, {
    required String localeTag,
    String? replyToMessageId,
  }) async {
    final body = value.trim();
    final conversation = state.conversation;
    if (body.isEmpty || state.isSending) {
      return false;
    }

    if (conversation != null && _isConversationReadOnlyForUser(conversation)) {
      return false;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      clearSendProgress: true,
    );

    try {
      if (conversation == null) {
        final createdConversation = await _repository.openConversation(
          initialMessage: body,
          source: 'MobileChat',
        );
        state = state.copyWith(
          isSending: false,
          conversation: createdConversation,
          clearError: true,
          clearSendProgress: true,
        );
        await _markReadIfNeeded(createdConversation);
      } else {
        final message = await _repository.sendMessage(
          conversationId: conversation.conversationId,
          body: body,
          localeTag: localeTag,
          replyToMessageId: replyToMessageId,
        );

        state = state.copyWith(
          isSending: false,
          conversation: _appendOutgoingMessage(conversation, message),
          clearError: true,
          clearSendProgress: true,
        );
      }
      _resumePendingRealtimeRefreshIfNeeded();
      return true;
    } on AppException catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
        clearSendProgress: true,
      );
      return false;
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

  Future<bool> sendAttachments({
    required List<SupportChatUploadAttachment> attachments,
    required String localeTag,
    String? body,
    String? replyToMessageId,
  }) async {
    if (attachments.isEmpty || state.isSending) {
      return false;
    }

    var conversation = state.conversation;
    if (conversation != null && _isConversationReadOnlyForUser(conversation)) {
      return false;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      sendProgress: 0,
      sendingAttachmentIndex: attachments.length == 1 ? 1 : null,
      sendingAttachmentTotal: attachments.length,
    );

    try {
      if (conversation == null) {
        conversation = await _repository.openConversation(source: 'MobileChat');
        state = state.copyWith(conversation: conversation);
      }

      final message = await _repository.sendAttachments(
        conversationId: conversation.conversationId,
        attachments: attachments,
        localeTag: localeTag,
        body: body,
        replyToMessageId: replyToMessageId,
        onSendProgress: (sent, total) {
          if (total <= 0) {
            return;
          }

          state = state.copyWith(
            sendProgress: (sent / total).clamp(0.0, 1.0).toDouble(),
          );
        },
      );

      final attachmentFailure = _messageFromAttachmentFailure(message);
      state = state.copyWith(
        isSending: false,
        conversation: _appendOutgoingMessage(conversation, message),
        errorMessage: attachmentFailure,
        clearError: attachmentFailure == null,
        clearSendProgress: true,
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return attachmentFailure == null;
    } on AppException catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
        clearSendProgress: true,
      );
      return false;
    } on Object {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'support.attachment_unavailable',
        clearSendProgress: true,
      );
      return false;
    }
  }

  Future<bool> sendAttachment({
    required String filePath,
    required String fileName,
    required String contentType,
    required String localeTag,
    String? body,
    String? replyToMessageId,
    int? attachmentBatchIndex,
    int? attachmentBatchTotal,
  }) async {
    var conversation = state.conversation;
    if (state.isSending) {
      return false;
    }

    if (conversation != null && _isConversationReadOnlyForUser(conversation)) {
      return false;
    }

    state = state.copyWith(
      isSending: true,
      clearError: true,
      sendProgress: 0,
      sendingAttachmentIndex: attachmentBatchIndex,
      sendingAttachmentTotal: attachmentBatchTotal,
    );

    try {
      if (conversation == null) {
        conversation = await _repository.openConversation(source: 'MobileChat');
        state = state.copyWith(conversation: conversation);
      }

      final message = await _repository.sendAttachment(
        conversationId: conversation.conversationId,
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        localeTag: localeTag,
        body: body,
        replyToMessageId: replyToMessageId,
        onSendProgress: (sent, total) {
          if (total <= 0) {
            return;
          }

          state = state.copyWith(
            sendProgress: (sent / total).clamp(0.0, 1.0).toDouble(),
          );
        },
      );

      final attachmentFailure = _messageFromAttachmentFailure(message);

      state = state.copyWith(
        isSending: false,
        conversation: _appendOutgoingMessage(conversation, message),
        errorMessage: attachmentFailure,
        clearError: attachmentFailure == null,
        clearSendProgress: true,
      );
      _resumePendingRealtimeRefreshIfNeeded();
      return message.isAttachmentUploaded;
    } on AppException catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
        clearSendProgress: true,
      );
      return false;
    } on Object {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'support.attachment_unavailable',
        clearSendProgress: true,
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
    if (conversation == null || conversation.isReadOnly || state.isSending) {
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

  Future<void> resolveConversation() async {
    await _runConversationLifecycleAction(
      (conversation) =>
          _repository.resolveConversation(conversation.conversationId),
    );
  }

  Future<void> reopenConversation() async {
    await _runConversationLifecycleAction(
      (conversation) =>
          _repository.reopenConversation(conversation.conversationId),
    );
  }

  Future<void> closeConversation() async {
    await _runConversationLifecycleAction(
      (conversation) =>
          _repository.closeConversation(conversation.conversationId),
    );
  }

  Future<void> submitFeedback(int rating) async {
    await _runConversationLifecycleAction(
      (conversation) => _repository.submitFeedback(
        conversationId: conversation.conversationId,
        rating: rating,
      ),
    );
  }

  void _handleRealtimeUpdate(SupportChatRealtimeUpdate event) {
    final activeConversationId = state.conversation?.conversationId;
    if (activeConversationId != null &&
        activeConversationId != event.conversationId) {
      return;
    }

    if (!_isScreenVisible) {
      _hasPendingRealtimeRefresh = true;
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
      status: 'New',
      userUnreadCount: 0,
      adminUnreadCount: conversation.adminUnreadCount + 1,
      updatedAtUtc: message.createdAtUtc,
      lastMessageAtUtc: message.createdAtUtc,
      isReadOnly: false,
      canReopen: false,
      clearResolvedAt: true,
      clearReopenUntil: true,
      clearClosedAt: true,
      messages: [...conversation.messages, message],
    );
  }

  Future<void> _runConversationLifecycleAction(
    Future<SupportChatConversation> Function(
      SupportChatConversation conversation,
    )
    action,
  ) async {
    final conversation = state.conversation;
    if (conversation == null || state.isSending) {
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);
    try {
      final updatedConversation = await action(conversation);
      state = state.copyWith(
        isSending: false,
        conversation: updatedConversation,
        clearError: true,
      );
      _resumePendingRealtimeRefreshIfNeeded();
    } on AppException catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
    } on Object {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'support.unavailable',
      );
    }
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

    return message.attachmentUploadErrorCode ??
        'support.attachment_unavailable';
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
      if (_isConversationNotFound(error.message)) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          clearConversation: true,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: error.message,
        );
      }
    }
  }

  bool get _isConversationBusy =>
      state.isLoading ||
      state.isRefreshing ||
      state.isSending ||
      state.isLoadingOlder;

  Future<void> loadOlderMessages() async {
    final conversation = state.conversation;
    if (conversation == null ||
        state.isLoadingOlder ||
        !conversation.hasOlderMessages) {
      return;
    }

    final before = conversation.oldestLoadedMessageCreatedAtUtc;
    if (before == null) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true);
    try {
      final chunk = await _repository.getConversation(
        beforeMessageCreatedAtUtc: before,
      );

      final existingById = {
        for (final message in conversation.messages) message.messageId: message,
      };
      final merged = <SupportChatMessage>[
        ...chunk.messages.where(
          (message) => !existingById.containsKey(message.messageId),
        ),
        ...conversation.messages,
      ]..sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));

      state = state.copyWith(
        isLoadingOlder: false,
        conversation: conversation.copyWith(
          hasOlderMessages: chunk.hasOlderMessages,
          oldestLoadedMessageCreatedAtUtc:
              chunk.oldestLoadedMessageCreatedAtUtc,
          messages: merged,
        ),
      );
    } on AppException catch (error) {
      state = state.copyWith(
        isLoadingOlder: false,
        errorMessage: error.message,
      );
    } on Object {
      state = state.copyWith(
        isLoadingOlder: false,
        errorMessage: 'support.unavailable',
      );
    }
  }

  void _scheduleRealtimeRefresh() {
    if (!_isScreenVisible || _isConversationBusy) {
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
    if (_isScreenVisible && _hasPendingRealtimeRefresh) {
      _scheduleRealtimeRefresh();
    }
  }

  Future<void> _markReadIfNeeded(SupportChatConversation conversation) async {
    if (conversation.userUnreadCount <= 0) {
      return;
    }

    // Skip marking read when the screen is hidden or the app is in background.
    if (!_isScreenVisible) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
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

    if (lowerPath.endsWith('.mp4') || lowerPath.endsWith('.m4v')) {
      return 'video/mp4';
    }

    if (lowerPath.endsWith('.mov') || lowerPath.endsWith('.qt')) {
      return 'video/quicktime';
    }

    return 'application/octet-stream';
  }

  bool _isConversationNotFound(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('support.conversation_not_found') ||
        normalized.contains('support conversation was not found');
  }

  bool _isConversationReadOnlyForUser(SupportChatConversation conversation) {
    final normalizedStatus = conversation.status.trim().toLowerCase();
    if (normalizedStatus == 'closed') {
      return false;
    }

    return conversation.isReadOnly;
  }
}
