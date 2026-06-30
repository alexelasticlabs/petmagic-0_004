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
  late (String, String, String) _selected = widget.copy.options.first;
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in copy.options)
                      ChoiceChip(
                        selected: _selected == option,
                        label: Text(option.$3),
                        onSelected: (_) => setState(() => _selected = option),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: copy.messageLabel,
                    hintText: copy.messageHint,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final trimmedMessage = _messageController.text.trim();
                    Navigator.of(context).pop(
                      _SettingsFeedbackDraft(
                        type: _selected.$1,
                        category: _selected.$2,
                        message: trimmedMessage.isEmpty ? null : trimmedMessage,
                      ),
                    );
                  },
                  child: Text(copy.submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
