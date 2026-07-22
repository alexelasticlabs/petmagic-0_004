part of 'premium_page.dart';

class _PaywallFeedbackResult {
  const _PaywallFeedbackResult(this.category, this.message);

  final String category;
  final String? message;
}

class _PaywallFeedbackCopy {
  const _PaywallFeedbackCopy({
    required this.title,
    required this.commentLabel,
    required this.commentHint,
    required this.submit,
    required this.thanks,
    required this.options,
  });

  final String title;
  final String commentLabel;
  final String commentHint;
  final String submit;
  final String thanks;
  final List<(String, String)> options;
}

_PaywallFeedbackCopy _paywallFeedbackCopy(BuildContext context) {
  final text = AppLocalizations.of(context);
  return _PaywallFeedbackCopy(
    title: text.premiumPaywallFeedbackTitle,
    commentLabel: text.premiumPaywallFeedbackCommentLabel,
    commentHint: text.premiumPaywallFeedbackCommentHint,
    submit: text.premiumPaywallFeedbackSubmitAction,
    thanks: text.premiumPaywallFeedbackThanksMessage,
    options: [
      ('expensive', text.premiumPaywallFeedbackOptionExpensive),
      ('low_value', text.premiumPaywallFeedbackOptionLowValue),
      ('payment_problem', text.premiumPaywallFeedbackOptionPaymentProblem),
      ('just_browsing', text.premiumPaywallFeedbackOptionJustBrowsing),
      ('other', text.premiumPaywallFeedbackOptionOther),
    ],
  );
}

Future<_PaywallFeedbackResult?> _showPaywallFeedbackSheet(
  BuildContext context,
) {
  final copy = _paywallFeedbackCopy(context);
  final controller = TextEditingController();
  var selected = copy.options.first;

  return showModalBottomSheet<_PaywallFeedbackResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final brightness = Theme.of(context).brightness;
          final isDark = brightness == Brightness.dark;
          final surface = isDark ? _kDarkSurface : _kLightSurface;
          final textColor = isDark ? _kDarkText : _kLightText;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark ? _kDarkBorder : _kLightBorder,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            copy.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _PaywallFeedbackOptions(
                            options: copy.options,
                            selected: selected,
                            isDark: isDark,
                            textColor: textColor,
                            onSelected: (option) =>
                                setState(() => selected = option),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: InputDecoration(
                              labelText: copy.commentLabel,
                              hintText: copy.commentHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  _PaywallFeedbackResult(
                                    selected.$1,
                                    controller.text.trim().isEmpty
                                        ? null
                                        : controller.text.trim(),
                                  ),
                                );
                              },
                              child: Text(copy.submit),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}

class _PaywallFeedbackOptions extends StatelessWidget {
  const _PaywallFeedbackOptions({
    required this.options,
    required this.selected,
    required this.isDark,
    required this.textColor,
    required this.onSelected,
  });

  final List<(String, String)> options;
  final (String, String) selected;
  final bool isDark;
  final Color textColor;
  final ValueChanged<(String, String)> onSelected;

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
            mainAxisExtent: 46,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return _PaywallFeedbackOptionButton(
              label: option.$2,
              selected: selected == option,
              isDark: isDark,
              textColor: textColor,
              onPressed: () => onSelected(option),
            );
          },
        );
      },
    );
  }
}

class _PaywallFeedbackOptionButton extends StatelessWidget {
  const _PaywallFeedbackOptionButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark
        ? const Color(0xFF385842)
        : const Color(0xFFDCEFE3);
    final borderColor = selected
        ? selectedColor
        : (isDark ? _kDarkBorder : _kLightBorder);

    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: selected
                      ? Icon(Icons.check_rounded, size: 18, color: textColor)
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
