import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/domain/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/domain/support_attachment_validation.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

part 'widgets/support_chat_actions_attachment_flow.part.dart';
part 'widgets/support_chat_actions_message_flow.part.dart';
part 'widgets/support_chat_actions_preview.part.dart';
part 'widgets/support_chat_attachment_picker.part.dart';
part 'widgets/support_chat_attachment_picker_asset_tile.part.dart';
part 'widgets/support_chat_attachment_picker_quick_tiles.part.dart';
part 'widgets/support_chat_external_media.part.dart';
part 'widgets/support_chat_composer.part.dart';
part 'widgets/support_chat_dialogs.part.dart';
part 'widgets/support_chat_header.part.dart';
part 'widgets/support_chat_messages.part.dart';
part 'widgets/support_chat_messages_meta.part.dart';
part 'widgets/support_chat_messages_reply.part.dart';
part 'widgets/support_chat_message_media_grid.part.dart';
part 'widgets/support_chat_message_media.part.dart';
part 'widgets/support_chat_models.part.dart';
part 'widgets/support_chat_sections_composer.part.dart';
part 'widgets/support_chat_sections_interactions.part.dart';
part 'widgets/support_chat_sections.part.dart';
part 'widgets/support_chat_states.part.dart';
part 'support_chat_page_lifecycle.part.dart';
part 'support_chat_page_interactions.part.dart';

const int _supportReplyThumbnailCacheWidth = 160;
const int _supportComposerAttachmentPreviewCacheExtent = 220;
const int _supportRecentMediaThumbnailCacheExtent = 300;
const int _supportAttachmentGridThumbnailCacheWidth = 512;
const int _supportImagePreviewDialogCacheWidth = 1440;

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({
    this.initialMessage,
    this.relatedGenerationId,
    super.key,
  });

  static const routePath = '/profile/support/chat';
  static const initialMessageQueryParam = 'initialMessage';
  static const relatedGenerationIdQueryParam = 'relatedGenerationId';
  static const int maxInitialMessageQueryLength = 500;
  static const int maxRelatedGenerationIdQueryLength = 128;
  static final RegExp _relatedGenerationIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$',
  );

  final String? initialMessage;
  final String? relatedGenerationId;

  static String routeFor({
    String? initialMessage,
    String? relatedGenerationId,
  }) {
    final queryParameters = <String, String>{};
    final normalizedInitialMessage = normalizeInitialMessageQuery(
      initialMessage,
    );
    if (normalizedInitialMessage != null &&
        normalizedInitialMessage.isNotEmpty) {
      queryParameters[initialMessageQueryParam] = normalizedInitialMessage;
    }
    final normalizedGenerationId = normalizeRelatedGenerationIdQuery(
      relatedGenerationId,
    );
    if (normalizedGenerationId != null && normalizedGenerationId.isNotEmpty) {
      queryParameters[relatedGenerationIdQueryParam] = normalizedGenerationId;
    }

    return Uri(
      path: routePath,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  static String? normalizeInitialMessageQuery(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized.length <= maxInitialMessageQueryLength
        ? normalized
        : normalized.substring(0, maxInitialMessageQueryLength);
  }

  static String? normalizeRelatedGenerationIdQuery(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized.length > maxRelatedGenerationIdQueryLength ||
        !_relatedGenerationIdPattern.hasMatch(normalized)) {
      return null;
    }

    return normalized;
  }

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage>
    with WidgetsBindingObserver {
  static const _loadingFallbackDelay = Duration(seconds: 8);
  static const _loadingFallbackMessageCode = 'support.unavailable';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  SupportChatController? _activeController;
  Timer? _loadingFallbackTimer;
  Timer? _messageHighlightTimer;
  RequestCancellation? _activeMediaDownloadCancelToken;
  bool _showLoadingFallback = false;
  bool _composerHasText = false;
  bool _composerHasFocus = false;
  bool _attachmentPickerBusy = false;
  int _externalMediaPickerDepth = 0;
  List<_PendingSupportAttachment> _pendingAttachments = const [];
  SupportChatMessage? _replyToMessage;
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  double _keyboardInset = 0;
  bool _hasRequestedControllerStart = false;

  SupportChatController get _controller {
    final controller = ref.read(supportChatControllerProvider.notifier);
    if (!identical(_activeController, controller)) {
      _activeController?.stop();
      _activeController = controller;
    }

    return controller;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_handleComposerChanged);
    _messageFocusNode.addListener(_handleComposerFocusChanged);
    _applyInitialMessage(
      SupportChatPage.normalizeInitialMessageQuery(widget.initialMessage),
    );
    _ensureControllerStarted();
  }

  @override
  void didUpdateWidget(covariant SupportChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != oldWidget.initialMessage) {
      _applyInitialMessage(
        SupportChatPage.normalizeInitialMessageQuery(widget.initialMessage),
        notify: true,
      );
    }
  }

  @override
  void deactivate() {
    _controller.setScreenVisible(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }
    _controller.setScreenVisible(true);
    _scheduleLoadingFallbackIfNeeded();
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _clearLoadingFallback();
      _controller.stop();
      _hasRequestedControllerStart = false;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _controller.setScreenVisible(true);
      _scheduleLoadingFallbackIfNeeded();
      unawaited(_controller.start());
      return;
    }

    if (_isExternalMediaPickerOpen) {
      return;
    }

    _controller.setScreenVisible(false);
    _clearLoadingFallback();
    _controller.suspend();
  }

  @override
  void dispose() {
    _clearLoadingFallback();
    _messageHighlightTimer?.cancel();
    _messageHighlightTimer = null;
    _messageController.removeListener(_handleComposerChanged);
    _messageFocusNode.removeListener(_handleComposerFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _cancelActiveMediaDownload();
    _activeController?.stop();
    _activeController = null;
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _applyState(VoidCallback action) {
    if (!mounted) {
      return;
    }

    setState(action);
  }

  RequestCancellation? _startMediaDownload() {
    if (_activeMediaDownloadCancelToken != null) {
      return null;
    }

    final cancelToken = RequestCancellation();
    _activeMediaDownloadCancelToken = cancelToken;
    return cancelToken;
  }

  void _completeMediaDownload(RequestCancellation cancelToken) {
    if (identical(_activeMediaDownloadCancelToken, cancelToken)) {
      _activeMediaDownloadCancelToken = null;
    }
  }

  void _cancelActiveMediaDownload() {
    final cancelToken = _activeMediaDownloadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('support_media_download_cancelled');
    }
    _activeMediaDownloadCancelToken = null;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    if (!isAuthenticated) {
      _clearLoadingFallback();
      _controller.stop();
      _hasRequestedControllerStart = false;
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: SupportChatPage.routeFor(
                  initialMessage: widget.initialMessage,
                  relatedGenerationId:
                      SupportChatPage.normalizeRelatedGenerationIdQuery(
                        widget.relatedGenerationId,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    _ensureControllerStarted();
    final state = ref.watch(supportChatControllerProvider);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final unavailableKind = state.conversation == null
        ? classifyAppUnavailable(
            raw: state.errorMessage,
            hasInternet: hasInternet,
          )
        : null;

    ref.listen<SupportChatState>(supportChatControllerProvider, (
      previous,
      next,
    ) {
      final wasWaiting =
          previous != null && _isWaitingForInitialConversation(previous);
      final isWaiting = _isWaitingForInitialConversation(next);
      if (isWaiting && !wasWaiting) {
        _scheduleLoadingFallbackIfNeeded();
      } else if (!isWaiting &&
          (wasWaiting ||
              _loadingFallbackTimer != null ||
              _showLoadingFallback)) {
        _clearLoadingFallback();
      }

      final previousVisibleMessages = _visibleSupportThreadMessages(
        previous?.conversation?.messages ?? const <SupportChatMessage>[],
      );
      final nextVisibleMessages = _visibleSupportThreadMessages(
        next.conversation?.messages ?? const <SupportChatMessage>[],
      );
      if (nextVisibleMessages.isEmpty ||
          nextVisibleMessages.length == previousVisibleMessages.length) {
        return;
      }

      final latestMessage = nextVisibleMessages.last;
      final previousLatestMessageId = previousVisibleMessages.isEmpty
          ? null
          : previousVisibleMessages.last.messageId;
      final shouldAutoScroll =
          _isPinnedToBottom() ||
          previousLatestMessageId != latestMessage.messageId;
      if (!shouldAutoScroll) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      });
    });

    final conversation = state.conversation;
    final messages = _visibleSupportThreadMessages(
      conversation?.messages ?? const <SupportChatMessage>[],
    );
    _retainMessageKeys(messages);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    _keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNavInset = _keyboardInset > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;
    final isWaitingForInitialConversation = _isWaitingForInitialConversation(
      state,
    );

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: SizedBox.expand(
              child: Column(
                children: [
                  _SupportHeader(
                    title: text.supportChatTeamTitle,
                    subtitle: text.supportChatTeamStatus,
                    onBack: () {
                      if (context.appNavigator.canPop()) {
                        context.appNavigator.pop();
                      } else {
                        context.appNavigator.go(const ProfileDestination());
                      }
                    },
                  ),
                  if (conversation != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _SupportConversationStatusStrip(
                        conversation: conversation,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: _SupportSecurityCard(
                      title: text.supportChatSecureTitle,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SupportConversationViewport(
                        state: state,
                        conversation: conversation,
                        messages: messages,
                        scrollController: _scrollController,
                        isWaitingForInitialConversation:
                            isWaitingForInitialConversation,
                        unavailableKind: unavailableKind,
                        showLoadingFallback: _showLoadingFallback,
                        loadingFallbackMessageCode: _loadingFallbackMessageCode,
                        onRefresh: _controller.refresh,
                        onLoadOlderMessages: _controller.loadOlderMessages,
                        onRetryInitialize: () {
                          _clearLoadingFallback(notify: true);
                          _controller.initialize();
                        },
                        onQuickActionSelected: _prefillComposer,
                        onOpenAttachment: _openAttachmentExternallyImpl,
                        onOpenImage: _openImageFullscreen,
                        onOpenVideo: _openVideoFullscreen,
                        onRetryAttachment: _retryAttachmentForMessage,
                        onReplyToMessage: _setReplyToMessage,
                        onJumpToMessage: _jumpToMessage,
                        highlightedMessageId: _highlightedMessageId,
                        messageItemKeyForId: _messageItemKeyForId,
                        formatDayLabel: _formatDayLabel,
                        isSameDay: _isSameDay,
                      ),
                    ),
                  ),
                  _SupportComposerPanel(
                    state: state,
                    messageController: _messageController,
                    messageFocusNode: _messageFocusNode,
                    pendingAttachments: _pendingAttachments,
                    composerHasFocus: _composerHasFocus,
                    composerCanSend: _composerCanSend,
                    keyboardInset: _keyboardInset,
                    onRemovePendingAttachment: _removePendingAttachment,
                    onShowAttachmentOptions: _showAttachmentOptions,
                    onSendMessage: () => _sendCurrentMessage(localeTag),
                    onCloseConversation: _controller.closeConversation,
                    onReopenConversation: _controller.reopenConversation,
                    onSubmitFeedback: (rating, comment) =>
                        _controller.submitFeedback(rating, comment: comment),
                    replyToMessage: _replyToMessage,
                    onClearReplyToMessage: _clearReplyToMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
