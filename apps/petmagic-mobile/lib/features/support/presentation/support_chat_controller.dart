import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';

part 'support_chat_controller_conversation.part.dart';
part 'support_chat_controller_messaging.part.dart';

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

abstract class _SupportChatControllerScope {
  SupportChatRepository get _repository;
  SupportChatRealtimeClient get _realtimeClient;

  bool _updateStateIfMounted(
    SupportChatState Function(SupportChatState current) update,
  );
}

abstract class _SupportChatControllerBase extends Notifier<SupportChatState>
    implements _SupportChatControllerScope {}

class SupportChatController extends _SupportChatControllerBase
    with
        _SupportChatControllerConversationMixin,
        _SupportChatControllerMessagingMixin {
  @override
  late final SupportChatRepository _repository;
  @override
  late final SupportChatRealtimeClient _realtimeClient;

  @override
  SupportChatState build() {
    _repository = ref.watch(supportChatRepositoryProvider);
    _realtimeClient = ref.watch(supportChatRealtimeClientProvider);
    ref.onDispose(stop);
    return const SupportChatState.initial();
  }

  @override
  bool _updateStateIfMounted(
    SupportChatState Function(SupportChatState current) update,
  ) {
    if (!ref.mounted) {
      return false;
    }

    state = update(state);
    return true;
  }
}
