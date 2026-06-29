part of 'support_ticket_form_page.dart';

class _SupportTicketFormContent extends StatelessWidget {
  const _SupportTicketFormContent({
    required this.scenarioData,
    required this.generationId,
    required this.paymentId,
    required this.subscriptionLabel,
    required this.descriptionController,
    required this.attachments,
    required this.isSubmitting,
    required this.isPickingAttachment,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.onSubmit,
  });

  final SupportAssistantScenario scenarioData;
  final String? generationId;
  final String? paymentId;
  final String? subscriptionLabel;
  final TextEditingController descriptionController;
  final List<XFile> attachments;
  final bool isSubmitting;
  final bool isPickingAttachment;
  final VoidCallback onAddAttachment;
  final ValueChanged<int> onRemoveAttachment;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(text.supportTicketFormTitle),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _ContextCard(
                label: text.supportTicketFormTopicLabel,
                value: scenarioData.topicLabel,
              ),
              if (generationId != null)
                _ContextCard(
                  label: text.supportTicketFormRelatedGenerationLabel,
                  value: generationId!,
                ),
              if (paymentId != null)
                _ContextCard(
                  label: text.supportTicketFormRelatedPaymentLabel,
                  value: paymentId!,
                ),
              if (subscriptionLabel != null)
                _ContextCard(
                  label: text.supportTicketFormRelatedSubscriptionLabel,
                  value: subscriptionLabel!,
                ),
              const SizedBox(height: 10),
              Text(
                text.supportTicketFormDescriptionLabel,
                style: TextStyle(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 5,
                minLines: 4,
                style: TextStyle(color: colors.textStrong),
                decoration: InputDecoration(
                  hintText: text.supportTicketFormDescriptionHint,
                  hintStyle: TextStyle(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.surfaceStrong.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    text.supportTicketFormAttachmentsLabel,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: isSubmitting || isPickingAttachment
                        ? null
                        : onAddAttachment,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(text.supportTicketFormAddScreenshotAction),
                  ),
                ],
              ),
              if (attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < attachments.length; i++)
                      _AttachmentChip(
                        file: attachments[i],
                        onRemove: isSubmitting
                            ? null
                            : () => onRemoveAttachment(i),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isSubmitting
                        ? text.supportTicketFormSubmittingLabel
                        : text.supportTicketFormSubmitAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProfileGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.file, this.onRemove});

  final XFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 16, color: colors.textSoft),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                file.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
