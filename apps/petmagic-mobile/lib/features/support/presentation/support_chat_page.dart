import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/presentation/support_attachment_validation.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

part 'widgets/support_chat_actions.part.dart';
part 'widgets/support_chat_external_media.part.dart';
part 'widgets/support_chat_composer.part.dart';
part 'widgets/support_chat_dialogs.part.dart';
part 'widgets/support_chat_header.part.dart';
part 'widgets/support_chat_messages.part.dart';
part 'widgets/support_chat_message_media.part.dart';
part 'widgets/support_chat_models.part.dart';
part 'widgets/support_chat_sections.part.dart';
part 'widgets/support_chat_states.part.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  static const routePath = '/profile/support/chat';

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
  final AppPermissionCoordinator _permissionCoordinator =
      AppPermissionCoordinator();
  late final SupportChatController _controller;
  Timer? _loadingFallbackTimer;
  Timer? _messageHighlightTimer;
  bool _showLoadingFallback = false;
  bool _composerHasText = false;
  bool _composerHasFocus = false;
  List<_PendingSupportAttachment> _pendingAttachments = const [];
  SupportChatMessage? _replyToMessage;
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  double _keyboardInset = 0;

  void _showSupportToast(
    String message, {
    PetMagicToastTone tone = PetMagicToastTone.info,
  }) {
    PetMagicToast.show(context, message: message, tone: tone);
  }

  bool get _hasPendingAttachment => _pendingAttachments.isNotEmpty;

  bool get _composerCanSend => _composerHasText || _hasPendingAttachment;

  bool _isWaitingForInitialConversation(SupportChatState state) {
    return state.isLoading && state.conversation == null;
  }

  void _scheduleLoadingFallbackIfNeeded() {
    _loadingFallbackTimer ??= Timer(_loadingFallbackDelay, () {
      _loadingFallbackTimer = null;
      if (!mounted ||
          !_isWaitingForInitialConversation(
            ref.read(supportChatControllerProvider),
          )) {
        return;
      }

      setState(() {
        _showLoadingFallback = true;
      });
    });
  }

  void _clearLoadingFallback({bool notify = false}) {
    _loadingFallbackTimer?.cancel();
    _loadingFallbackTimer = null;
    if (notify && mounted && _showLoadingFallback) {
      setState(() {
        _showLoadingFallback = false;
      });
      return;
    }

    _showLoadingFallback = false;
  }

  @override
  void initState() {
    super.initState();
    _controller = ref.read(supportChatControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _scheduleLoadingFallbackIfNeeded();
    _messageController.addListener(_handleComposerChanged);
    _messageFocusNode.addListener(_handleComposerFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _controller.start();
      _controller.setScreenVisible(true);
    });
  }

  @override
  void deactivate() {
    _controller.setScreenVisible(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _controller.setScreenVisible(true);
    _scheduleLoadingFallbackIfNeeded();
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.setScreenVisible(true);
      _scheduleLoadingFallbackIfNeeded();
      unawaited(_controller.start());
      return;
    }

    _controller.setScreenVisible(false);
    _clearLoadingFallback();
    _controller.stop();
  }

  @override
  void dispose() {
    _clearLoadingFallback();
    _messageHighlightTimer?.cancel();
    _messageHighlightTimer = null;
    _messageController.removeListener(_handleComposerChanged);
    _messageFocusNode.removeListener(_handleComposerFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _controller.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _prefillComposer(String value) {
    _messageController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _messageFocusNode.requestFocus();
  }

  void _handleComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText == _composerHasText || !mounted) {
      return;
    }

    setState(() {
      _composerHasText = hasText;
    });
  }

  void _handleComposerFocusChanged() {
    final hasFocus = _messageFocusNode.hasFocus;
    if (hasFocus == _composerHasFocus || !mounted) {
      return;
    }

    setState(() {
      _composerHasFocus = hasFocus;
    });
  }

  void _applyState(VoidCallback action) {
    if (!mounted) {
      return;
    }

    setState(action);
  }

  Future<void> _showAttachmentOptions() {
    return _SupportChatPageActions(this)._showAttachmentOptionsImpl();
  }

  Future<void> _sendCurrentMessage(String localeTag) {
    return _SupportChatPageActions(this)._sendCurrentMessageImpl(localeTag);
  }

  void _removePendingAttachment(int index) {
    _SupportChatPageActions(this)._removePendingAttachmentImpl(index);
  }

  Future<void> _retryAttachmentForMessage(SupportChatMessage message) {
    return _SupportChatPageActions(
      this,
    )._retryAttachmentForMessageImpl(message);
  }

  Future<void> _openImageFullscreen({
    required String imageUrl,
    String? fileName,
  }) {
    return _SupportChatPageActions(
      this,
    )._openImageFullscreenImpl(imageUrl: imageUrl, fileName: fileName);
  }

  Future<void> _openVideoFullscreen({
    required String videoUrl,
    String? fileName,
  }) {
    return _SupportChatPageActions(
      this,
    )._openVideoFullscreenImpl(videoUrl: videoUrl, fileName: fileName);
  }

  void _setReplyToMessage(SupportChatMessage message) {
    if (_isSupportSystemMessage(message) || !mounted) {
      return;
    }

    _applyState(() {
      _replyToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _clearReplyToMessage() {
    if (!mounted || _replyToMessage == null) {
      return;
    }

    _applyState(() {
      _replyToMessage = null;
    });
  }

  GlobalKey _messageItemKeyForId(String messageId) {
    final normalizedMessageId = messageId.trim();
    return _messageKeys.putIfAbsent(
      normalizedMessageId,
      () => GlobalKey(debugLabel: 'support-message-$normalizedMessageId'),
    );
  }

  void _retainMessageKeys(Iterable<SupportChatMessage> messages) {
    final activeIds = <String>{
      for (final message in messages)
        if (message.messageId.trim().isNotEmpty) message.messageId.trim(),
    };
    _messageKeys.removeWhere((messageId, _) => !activeIds.contains(messageId));
  }

  Future<void> _jumpToMessage(String messageId) async {
    final normalizedMessageId = messageId.trim();
    if (!mounted || normalizedMessageId.isEmpty) {
      return;
    }

    final targetKey = _messageKeys[normalizedMessageId];
    final targetContext = targetKey?.currentContext;
    if (targetContext == null) {
      final text = AppLocalizations.of(context);
      _showSupportToast(text.supportChatReplyOriginalUnavailable);
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.25,
    );
    if (!mounted) {
      return;
    }

    _messageHighlightTimer?.cancel();
    _applyState(() {
      _highlightedMessageId = normalizedMessageId;
    });
    _messageHighlightTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted || _highlightedMessageId != normalizedMessageId) {
        return;
      }

      _applyState(() {
        _highlightedMessageId = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final state = ref.watch(supportChatControllerProvider);

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
        if (!_scrollController.hasClients) {
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
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(ProfilePage.routePath);
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
                        showLoadingFallback: _showLoadingFallback,
                        loadingFallbackMessageCode: _loadingFallbackMessageCode,
                        onRefresh: _controller.refresh,
                        onLoadOlderMessages: _controller.loadOlderMessages,
                        onRetryInitialize: () {
                          _clearLoadingFallback(notify: true);
                          _controller.initialize();
                        },
                        onQuickActionSelected: _prefillComposer,
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

  String _formatDayLabel(DateTime value) {
    return _SupportChatPageActions(this)._formatDayLabelImpl(value);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return _SupportChatPageActions(this)._isSameDayImpl(left, right);
  }

  bool _isPinnedToBottom({double threshold = 72}) {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return (position.maxScrollExtent - position.pixels) <= threshold;
  }
}
