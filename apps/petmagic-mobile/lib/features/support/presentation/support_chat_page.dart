import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_models.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

part 'widgets/support_chat_actions.part.dart';
part 'widgets/support_chat_composer.part.dart';
part 'widgets/support_chat_dialogs.part.dart';
part 'widgets/support_chat_header.part.dart';
part 'widgets/support_chat_messages.part.dart';
part 'widgets/support_chat_models.part.dart';
part 'widgets/support_chat_sections.part.dart';
part 'widgets/support_chat_states.part.dart';

class SupportChatPage extends ConsumerStatefulWidget {
  const SupportChatPage({super.key});

  static const routePath = '/profile/support';

  @override
  ConsumerState<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends ConsumerState<SupportChatPage> {
  static const _loadingFallbackDelay = Duration(seconds: 8);
  static const _loadingFallbackMessageCode = 'support.unavailable';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  late final SupportChatController _controller;
  Timer? _loadingFallbackTimer;
  bool _showLoadingFallback = false;
  bool _showSecurityBanner = true;
  bool _composerHasText = false;
  bool _composerHasFocus = false;
  _PendingSupportAttachment? _pendingAttachment;

  bool get _hasPendingAttachment => _pendingAttachment != null;

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
    _scheduleLoadingFallbackIfNeeded();
    _messageController.addListener(_handleComposerChanged);
    _messageFocusNode.addListener(_handleComposerFocusChanged);
    _scrollController.addListener(_handleMessageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _controller.start();
    });
  }

  @override
  void dispose() {
    _clearLoadingFallback();
    _messageController.removeListener(_handleComposerChanged);
    _messageFocusNode.removeListener(_handleComposerFocusChanged);
    _scrollController.removeListener(_handleMessageScroll);
    _controller.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _handleMessageScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final shouldShow = _scrollController.offset < 24;
    if (shouldShow == _showSecurityBanner || !mounted) {
      return;
    }

    setState(() {
      _showSecurityBanner = shouldShow;
    });
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

  void _insertEmoji() {
    const emoji = '😊';
    final currentValue = _messageController.value;
    final selection = currentValue.selection;
    final start = selection.isValid
        ? selection.start
        : currentValue.text.length;
    final end = selection.isValid ? selection.end : currentValue.text.length;
    final safeStart = start < 0 ? currentValue.text.length : start;
    final safeEnd = end < 0 ? currentValue.text.length : end;
    final updatedText = currentValue.text.replaceRange(
      safeStart,
      safeEnd,
      emoji,
    );

    _messageController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: safeStart + emoji.length),
    );
    _messageFocusNode.requestFocus();
  }

  Future<void> _showAttachmentOptions() {
    return _SupportChatPageActions(this)._showAttachmentOptionsImpl();
  }

  Future<void> _sendCurrentMessage(String localeTag) {
    return _SupportChatPageActions(this)._sendCurrentMessageImpl(localeTag);
  }

  void _removePendingAttachment() {
    _SupportChatPageActions(this)._removePendingAttachmentImpl();
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

      final previousMessageCount = previous?.conversation?.messages.length ?? 0;
      final nextMessageCount = next.conversation?.messages.length ?? 0;
      if (nextMessageCount == 0 || nextMessageCount == previousMessageCount) {
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
    final messages = conversation?.messages ?? const <SupportChatMessage>[];
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final bottomNavInset = petMagicScrollableBottomInset(context);
    final isWaitingForInitialConversation = _isWaitingForInitialConversation(
      state,
    );

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomNavInset),
            child: SizedBox.expand(
              child: Column(
                children: [
                  _SupportHeader(
                    title:
                        conversation?.assignedAdminDisplayName
                                ?.trim()
                                .isNotEmpty ==
                            true
                        ? conversation!.assignedAdminDisplayName!
                        : text.supportChatTeamTitle,
                    subtitle: text.supportChatTeamStatus,
                    onBack: () => context.pop(),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: messages.isEmpty || _showSecurityBanner
                        ? Padding(
                            key: const ValueKey('security-banner-visible'),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: _SupportSecurityCard(
                              title: text.supportChatSecureTitle,
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('security-banner-hidden'),
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
                        onRetryInitialize: () {
                          _clearLoadingFallback(notify: true);
                          _controller.initialize();
                        },
                        onQuickActionSelected: _prefillComposer,
                        onOpenImage: _openImageFullscreen,
                        onRetryAttachment: _retryAttachmentForMessage,
                        formatDayLabel: _formatDayLabel,
                        isSameDay: _isSameDay,
                      ),
                    ),
                  ),
                  _SupportComposerPanel(
                    state: state,
                    messageController: _messageController,
                    messageFocusNode: _messageFocusNode,
                    pendingAttachment: _pendingAttachment,
                    composerHasFocus: _composerHasFocus,
                    composerCanSend: _composerCanSend,
                    onRemovePendingAttachment: _removePendingAttachment,
                    onShowAttachmentOptions: _showAttachmentOptions,
                    onInsertEmoji: _insertEmoji,
                    onSendMessage: () => _sendCurrentMessage(localeTag),
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
}
