import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/support/application/support_contract.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_conversation_policy.dart';

part 'support_chat_controller_conversation.part.dart';
part 'support_chat_controller_messaging.part.dart';
part 'support_chat_controller_realtime.part.dart';

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
  SupportRepository get _repository;
  SupportRealtimeGateway get _realtimeClient;

  bool _updateStateIfMounted(
    SupportChatState Function(SupportChatState current) update,
  );
}

abstract class _SupportChatControllerBase extends Notifier<SupportChatState>
    implements _SupportChatControllerScope {}

class SupportChatController extends _SupportChatControllerBase
    with
        _SupportChatControllerRealtimeMixin,
        _SupportChatControllerConversationMixin,
        _SupportChatControllerMessagingMixin {
  SupportRepository? _activeRepository;
  SupportRealtimeGateway? _activeRealtimeClient;

  @override
  SupportRepository get _repository {
    final repository = _activeRepository;
    if (repository != null) {
      return repository;
    }

    return ref.read(supportChatRepositoryProvider);
  }

  @override
  SupportRealtimeGateway get _realtimeClient {
    final realtimeClient = _activeRealtimeClient;
    if (realtimeClient != null) {
      return realtimeClient;
    }

    return ref.read(supportChatRealtimeClientProvider);
  }

  @override
  SupportChatState build() {
    _activeRepository = ref.read(supportChatRepositoryProvider);
    _activeRealtimeClient = ref.read(supportChatRealtimeClientProvider);
    _hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    _canUsePrivateSupportApi = _isLaunchAuthorized(
      ref.read(appLaunchControllerProvider),
    );
    ref.listen<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleAuthStatusChanged(next),
    );
    ref.listen<bool>(
      networkStatusControllerProvider.select((state) => state.hasInternet),
      (_, hasInternet) => _handleNetworkStatusChanged(hasInternet),
    );
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
