import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
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
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:url_launcher/url_launcher.dart';

const _supportSecondaryGreen = Color(0xFF69D8A7);
const _supportMessageGreen = Color(0xFF129369);
const _supportMessageGreenBorder = Color(0xFF0D7752);
const _supportComposerSendGreen = Color(0xFF00D97E);
const _supportComposerIconColor = Color(0xFFA0AEC0);
const _supportComposerHintColor = Color(0xFF7B8794);

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

  Future<void> _pickImageAttachment(String localeTag) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) {
      return;
    }

    final wasSent = await _controller.sendImageAttachment(
      picked,
      body: _messageController.text,
      localeTag: localeTag,
    );
    if (!mounted || !wasSent) {
      return;
    }

    _messageController.clear();
  }

  Future<void> _pickFileAttachment(String localeTag) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    final file = picked?.files.single;
    if (file == null || file.path == null || !mounted) {
      return;
    }

    final wasSent = await _controller.sendAttachment(
      filePath: file.path!,
      fileName: file.name,
      contentType: _controller.resolveContentTypeForUpload(file.path!),
      localeTag: localeTag,
      body: _messageController.text,
    );
    if (!mounted || !wasSent) {
      return;
    }

    _messageController.clear();
  }

  Future<void> _showAttachmentOptions(String localeTag) async {
    if (ref.read(supportChatControllerProvider).isSending) {
      return;
    }

    final action = await showModalBottomSheet<_SupportAttachmentAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.petMagicColors;
        final text = AppLocalizations.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceStrong,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.85),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: _supportComposerIconColor,
                    ),
                    title: Text(
                      text.imageLabel,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_SupportAttachmentAction.gallery),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.attach_file_rounded,
                      color: _supportComposerIconColor,
                    ),
                    title: Text(
                      text.profileLegalDocumentSection,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_SupportAttachmentAction.file),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _SupportAttachmentAction.gallery:
        await _pickImageAttachment(localeTag);
      case _SupportAttachmentAction.file:
        await _pickFileAttachment(localeTag);
    }
  }

  Future<void> _sendCurrentMessage(String localeTag) async {
    final body = _messageController.text;
    await _controller.sendMessage(body, localeTag: localeTag);
    if (!mounted) {
      return;
    }

    if (body.trim().isNotEmpty) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
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
    final bottomNavInset = petMagicBottomNavInset(context);
    final isWaitingForInitialConversation = _isWaitingForInitialConversation(
      state,
    );
    final quickActions = [
      _SupportQuickActionData(
        icon: Icons.auto_awesome_rounded,
        label: text.supportChatQuickActionGeneration,
        prompt: text.supportChatQuickActionGeneration,
      ),
      _SupportQuickActionData(
        icon: Icons.credit_card_rounded,
        label: text.supportChatQuickActionPayment,
        prompt: text.supportChatQuickActionPayment,
      ),
      _SupportQuickActionData(
        icon: Icons.reply_all_rounded,
        label: text.supportChatQuickActionRefund,
        prompt: text.supportChatQuickActionRefund,
      ),
      _SupportQuickActionData(
        icon: Icons.support_agent_rounded,
        label: text.supportChatQuickActionHuman,
        prompt: text.supportChatQuickActionHuman,
      ),
    ];
    final faqItems = [
      _SupportFaqItemData(
        icon: Icons.image_search_rounded,
        title: text.supportChatFaqGenerationTitle,
        body: text.supportChatFaqGenerationBody,
      ),
      _SupportFaqItemData(
        icon: Icons.schedule_rounded,
        title: text.supportChatFaqResponseTitle,
        body: text.supportChatFaqResponseBody,
      ),
      _SupportFaqItemData(
        icon: Icons.receipt_long_rounded,
        title: text.supportChatFaqRefundTitle,
        body: text.supportChatFaqRefundBody,
      ),
    ];

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
                      child: () {
                        if (isWaitingForInitialConversation &&
                            !_showLoadingFallback) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (conversation == null) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: _SupportEmptyState(
                                      icon: Icons.support_agent_rounded,
                                      title: text.supportChatEmptyTitle,
                                      description: state.errorMessage != null
                                          ? _mapSupportError(
                                              text,
                                              state.errorMessage!,
                                            )
                                          : (_showLoadingFallback
                                                ? _mapSupportError(
                                                    text,
                                                    _loadingFallbackMessageCode,
                                                  )
                                                : text.supportChatEmptyMessage),
                                      actionLabel: text.retryAction,
                                      onAction: () {
                                        _clearLoadingFallback(notify: true);
                                        _controller.initialize();
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        if (messages.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: _controller.refresh,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 24,
                                      ),
                                      child: _SupportStarterState(
                                        title: text.supportChatWelcomeTitle,
                                        description:
                                            text.supportChatWelcomeBody,
                                        faqTitle: text.supportChatFaqTitle,
                                        quickActions: quickActions,
                                        faqItems: faqItems,
                                        onQuickActionSelected: _prefillComposer,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: _controller.refresh,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
                            itemCount:
                                messages.length +
                                (state.errorMessage == null ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (state.errorMessage != null && index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ProfileMessageCard(
                                    message: _mapSupportError(
                                      text,
                                      state.errorMessage!,
                                    ),
                                    tone: colors.danger,
                                  ),
                                );
                              }

                              final messageIndex = state.errorMessage == null
                                  ? index
                                  : index - 1;
                              final message = messages[messageIndex];
                              final previousMessage = messageIndex > 0
                                  ? messages[messageIndex - 1]
                                  : null;
                              final showDayDivider =
                                  previousMessage == null ||
                                  !_isSameDay(
                                    previousMessage.createdAtUtc,
                                    message.createdAtUtc,
                                  );

                              return Padding(
                                padding: EdgeInsets.only(
                                  top: showDayDivider ? 12 : 0,
                                  bottom: 14,
                                ),
                                child: Column(
                                  children: [
                                    if (showDayDivider)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 18,
                                        ),
                                        child: _DayDivider(
                                          label: _formatDayLabel(
                                            message.createdAtUtc,
                                          ),
                                        ),
                                      ),
                                    _MessageBubble(message: message),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      }(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: 62),
                      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceStrong.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: colors.accent.withValues(
                            alpha: _composerHasFocus ? 0.2 : 0.08,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            splashRadius: 18,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            onPressed: state.isSending
                                ? null
                                : () => _showAttachmentOptions(localeTag),
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              size: 23,
                              color: _supportComposerIconColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 15.5,
                                height: 1.28,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: text.supportChatInputHint,
                                hintStyle: TextStyle(
                                  color: _supportComposerHintColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  4,
                                  12,
                                  4,
                                  12,
                                ),
                                filled: false,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            splashRadius: 18,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            onPressed: state.isSending ? null : _insertEmoji,
                            icon: const Icon(
                              Icons.sentiment_satisfied_alt_rounded,
                              size: 23,
                              color: _supportComposerIconColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedScale(
                            scale: _composerHasText ? 1 : 0.9,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            child: IgnorePointer(
                              ignoring: !_composerHasText || state.isSending,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: _composerHasText || state.isSending
                                    ? 1
                                    : 0.72,
                                child: Material(
                                  color: state.isSending
                                      ? _supportComposerSendGreen.withValues(
                                          alpha: 0.92,
                                        )
                                      : _composerHasText
                                      ? _supportComposerSendGreen
                                      : _supportComposerSendGreen.withValues(
                                          alpha: 0.38,
                                        ),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: state.isSending || !_composerHasText
                                        ? null
                                        : () => _sendCurrentMessage(localeTag),
                                    child: SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: Center(
                                        child: state.isSending
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.send_rounded,
                                                size: 21,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
    final localValue = value.toLocal();
    final localNow = DateTime.now();
    if (_isSameDay(localValue, localNow)) {
      return AppLocalizations.of(context).supportChatTodayLabel;
    }

    return DateFormat('MMM d').format(localValue);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }
}

String _mapSupportError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('support.attachment_unavailable')) {
    return text.supportChatAttachmentUnavailableError;
  }

  if (value.contains('support.unavailable') ||
      value.contains('support.request_failed')) {
    return text.supportChatUnavailableError;
  }

  if (value.contains('auth.sign_in_required')) {
    return text.authSignInRequired;
  }

  if (value.contains('auth.session_expired')) {
    return text.authSessionExpired;
  }

  return raw;
}

enum _SupportAttachmentAction { gallery, file }

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textStrong,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceStrong,
                  colors.accent.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Icon(Icons.pets_rounded, size: 20, color: colors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _supportSecondaryGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSecurityCard extends StatelessWidget {
  const _SupportSecurityCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.24),
                  colors.accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Icon(Icons.shield_rounded, color: colors.accent, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ProfileGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: colors.accent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.edit_outlined),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportStarterState extends StatelessWidget {
  const _SupportStarterState({
    required this.title,
    required this.description,
    required this.faqTitle,
    required this.quickActions,
    required this.faqItems,
    required this.onQuickActionSelected,
  });

  final String title;
  final String description;
  final String faqTitle;
  final List<_SupportQuickActionData> quickActions;
  final List<_SupportFaqItemData> faqItems;
  final ValueChanged<String> onQuickActionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileGlassCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Stack(
            children: [
              Positioned(
                top: -4,
                right: 0,
                child: Icon(
                  Icons.pets_rounded,
                  size: 24,
                  color: colors.accent.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 34,
                child: Icon(
                  Icons.pets_rounded,
                  size: 18,
                  color: colors.accent.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.surfaceStrong,
                              colors.accent.withValues(alpha: 0.16),
                            ],
                          ),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: colors.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).supportChatTeamTitle,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _supportSecondaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).supportChatTeamStatus,
                                    style: TextStyle(
                                      color: colors.textSoft,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in quickActions)
                        ActionChip(
                          onPressed: () => onQuickActionSelected(action.prompt),
                          avatar: Icon(
                            action.icon,
                            size: 16,
                            color: colors.accent,
                          ),
                          label: Text(action.label),
                          side: BorderSide(
                            color: colors.border.withValues(alpha: 0.7),
                          ),
                          backgroundColor: colors.surfaceStrong.withValues(
                            alpha: 0.72,
                          ),
                          labelStyle: TextStyle(
                            color: colors.textStrong,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            faqTitle,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final item in faqItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SupportFaqCard(
              item: item,
              onTap: () => onQuickActionSelected(item.title),
            ),
          ),
      ],
    );
  }
}

class _SupportFaqCard extends StatelessWidget {
  const _SupportFaqCard({required this.item, required this.onTap});

  final _SupportFaqItemData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.78)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(item.icon, size: 18, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.body,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportQuickActionData {
  const _SupportQuickActionData({
    required this.icon,
    required this.label,
    required this.prompt,
  });

  final IconData icon;
  final String label;
  final String prompt;
}

class _SupportFaqItemData {
  const _SupportFaqItemData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.68,
      288.0,
    );
    final attachmentCacheWidth =
        (maxBubbleWidth * MediaQuery.devicePixelRatioOf(context)).round();
    final attachmentCacheHeight = (attachmentCacheWidth / 1.05).round();
    final bubbleColor = message.isFromAdmin
        ? colors.surfaceStrong
        : _supportMessageGreen;
    final borderColor = message.isFromAdmin
        ? colors.border
        : _supportMessageGreenBorder;
    final alignment = message.isFromAdmin
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final timeLabel = DateFormat(
      'HH:mm',
    ).format(message.createdAtUtc.toLocal());
    final textColor = message.isFromAdmin ? colors.textStrong : Colors.white;
    final metaColor = message.isFromAdmin
        ? colors.textMuted
        : Colors.white.withValues(alpha: 0.78);
    final deliveryLabel = message.isRead
        ? text.supportChatMessageRead
        : text.supportChatMessageDelivered;
    final hasImageAttachment = message.hasImageAttachment;
    final hasFileAttachment = message.hasAttachment && !hasImageAttachment;
    final attachmentFileName = message.attachmentFileName?.trim();
    final shouldShowBody =
        message.body.trim().isNotEmpty &&
        message.body.trim() != (attachmentFileName ?? '');
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(message.isFromAdmin ? 8 : 20),
      bottomRight: Radius.circular(message.isFromAdmin ? 20 : 8),
    );

    return Align(
      alignment: alignment,
      child: Row(
        mainAxisAlignment: message.isFromAdmin
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.isFromAdmin) ...[
            _SupportAvatar(label: message.senderDisplayName),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: bubbleRadius,
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isFromAdmin) ...[
                      Text(
                        message.senderDisplayName,
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (hasImageAttachment) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 1.05,
                          child: Image.network(
                            message.attachmentUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: attachmentCacheWidth,
                            cacheHeight: attachmentCacheHeight,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colors.surface,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: colors.textMuted,
                                  size: 24,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }

                              return Container(
                                color: colors.surface,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (attachmentFileName != null &&
                          attachmentFileName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 13,
                              color: metaColor,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                attachmentFileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: metaColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (shouldShowBody) const SizedBox(height: 8),
                    ],
                    if (hasFileAttachment) ...[
                      InkWell(
                        onTap: () => _openAttachment(message.attachmentUrl),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.92),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                size: 18,
                                color: metaColor,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      attachmentFileName ?? message.body,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatAttachmentSize(
                                        message.attachmentFileSizeBytes,
                                      ),
                                      style: TextStyle(
                                        color: metaColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (shouldShowBody) const SizedBox(height: 8),
                    ],
                    if (shouldShowBody)
                      Text(
                        message.body,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          height: 1.34,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: metaColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!message.isFromAdmin) ...[
                          const SizedBox(width: 4),
                          Text(
                            deliveryLabel,
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead
                                ? Icons.done_all_rounded
                                : Icons.check_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatAttachmentSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return 'File';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final initial = label.trim().isEmpty ? 'P' : label.trim().substring(0, 1);

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceStrong,
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: _supportSecondaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
