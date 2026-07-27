part of 'profile_settings_page.dart';

class _SettingsFeedbackCopy {
  const _SettingsFeedbackCopy({
    required this.title,
    required this.subtitle,
    required this.sheetTitle,
    required this.messageLabel,
    required this.messageHint,
    required this.submit,
    required this.thanks,
    required this.options,
  });

  final String title;
  final String subtitle;
  final String sheetTitle;
  final String messageLabel;
  final String messageHint;
  final String submit;
  final String thanks;
  final List<(String, String, String)> options;
}

class _SettingsFeedbackDraft {
  const _SettingsFeedbackDraft({
    required this.type,
    required this.category,
    this.message,
  });

  final String type;
  final String category;
  final String? message;
}

_SettingsFeedbackCopy _settingsFeedbackCopy(BuildContext context) {
  final text = AppLocalizations.of(context);
  return _SettingsFeedbackCopy(
    title: text.profileSettingsFeedbackTitle,
    subtitle: text.profileSettingsFeedbackSubtitle,
    sheetTitle: text.profileSettingsFeedbackSheetTitle,
    messageLabel: text.profileSettingsFeedbackMessageLabel,
    messageHint: text.profileSettingsFeedbackMessageHint,
    submit: text.profileSettingsFeedbackSubmitAction,
    thanks: text.profileSettingsFeedbackThanksMessage,
    options: [
      ('General', 'general', text.profileSettingsFeedbackOptionGeneral),
      (
        'FeatureRequest',
        'suggestion',
        text.profileSettingsFeedbackOptionFeatureRequest,
      ),
      ('BugReport', 'bug', text.profileSettingsFeedbackOptionBug),
      ('PaymentIssue', 'payment', text.profileSettingsFeedbackOptionPayment),
    ],
  );
}

Future<void> _handleSettingsFeedbackSubmission({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final text = AppLocalizations.of(context);
  final draft = await _showSettingsFeedbackSheet(context);
  if (draft == null || !context.mounted) {
    return;
  }

  try {
    await ref
        .read(templateGenerationRepositoryProvider)
        .submitFeedback(
          type: draft.type,
          category: draft.category,
          message: draft.message,
          sourceScreen: 'settings',
        );
  } on AppException catch (error) {
    if (!context.mounted) {
      return;
    }

    PetMagicToast.show(
      context,
      message: mapProfileFeedbackMessage(error.message, text),
      tone: PetMagicToastTone.warning,
    );
    return;
  } catch (error, stackTrace) {
    AppLogger.warn(
      feature: 'Profile.SettingsFeedback',
      operation: 'submit_feedback',
      message: 'Profile settings feedback submission failed',
      context: {
        'type': draft.type,
        'category': draft.category,
        'hasMessage': (draft.message?.trim().isNotEmpty ?? false),
      },
      error: error,
      stackTrace: stackTrace,
    );
    if (!context.mounted) {
      return;
    }

    PetMagicToast.show(
      context,
      message: mapProfileFeedbackMessage('profile.action_failed', text),
      tone: PetMagicToastTone.warning,
    );
    return;
  }

  if (!context.mounted) {
    return;
  }

  PetMagicToast.show(
    context,
    message: _settingsFeedbackCopy(context).thanks,
    tone: PetMagicToastTone.success,
  );
}

Future<_SettingsFeedbackDraft?> _showSettingsFeedbackSheet(
  BuildContext context,
) {
  final copy = _settingsFeedbackCopy(context);

  return showModalBottomSheet<_SettingsFeedbackDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _SettingsFeedbackSheet(copy: copy);
    },
  );
}

class _SettingsFeedbackSheet extends StatefulWidget {
  const _SettingsFeedbackSheet({required this.copy});

  final _SettingsFeedbackCopy copy;

  @override
  State<_SettingsFeedbackSheet> createState() => _SettingsFeedbackSheetState();
}

class _SettingsFeedbackSheetState extends State<_SettingsFeedbackSheet> {
  (String, String, String)? _selected;
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final colors = context.petMagicColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    copy.sheetTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsFeedbackOptions(
                    options: copy.options,
                    selected: _selected,
                    onSelected: (option) => setState(() => _selected = option),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: copy.messageLabel,
                      hintText: copy.messageHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _selected == null
                          ? null
                          : () {
                              final trimmedMessage = _messageController.text
                                  .trim();
                              final selected = _selected;
                              if (selected == null) {
                                return;
                              }
                              Navigator.of(context).pop(
                                _SettingsFeedbackDraft(
                                  type: selected.$1,
                                  category: selected.$2,
                                  message: trimmedMessage.isEmpty
                                      ? null
                                      : trimmedMessage,
                                ),
                              );
                            },
                      icon: const Icon(Icons.send_rounded),
                      label: Text(copy.submit),
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
}

class _SettingsFeedbackOptions extends StatelessWidget {
  const _SettingsFeedbackOptions({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, String, String)> options;
  final (String, String, String)? selected;
  final ValueChanged<(String, String, String)> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 360 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisExtent: 56,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return _SettingsFeedbackOptionButton(
              option: option,
              selected: selected == option,
              onPressed: () => onSelected(option),
            );
          },
        );
      },
    );
  }
}

class _SettingsFeedbackOptionButton extends StatelessWidget {
  const _SettingsFeedbackOptionButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final (String, String, String) option;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final icon = switch (option.$2) {
      'suggestion' => Icons.lightbulb_outline_rounded,
      'bug' => Icons.bug_report_outlined,
      'payment' => Icons.receipt_long_outlined,
      _ => Icons.chat_bubble_outline_rounded,
    };

    return Semantics(
      button: true,
      selected: selected,
      label: option.$3,
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.accent : colors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : icon,
                    color: selected ? colors.accent : colors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.$3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
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
}
