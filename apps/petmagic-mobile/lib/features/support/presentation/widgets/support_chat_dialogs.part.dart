part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportImagePreviewDialog extends StatelessWidget {
  const _SupportImagePreviewDialog({
    required this.imageUrl,
    required this.fileName,
    required this.onSaveImage,
    required this.onShareImage,
    required this.onOpenOriginal,
  });

  final String imageUrl;
  final String? fileName;
  final Future<void> Function() onSaveImage;
  final Future<void> Function() onShareImage;
  final Future<void> Function() onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fileName?.trim().isNotEmpty == true
                          ? fileName!
                          : text.supportChatImageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 48,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              decoration: BoxDecoration(
                color: colors.surfaceStrong.withValues(alpha: 0.16),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _DialogActionChip(
                    icon: Icons.download_rounded,
                    label: text.supportChatSaveImageAction,
                    onPressed: () => unawaited(onSaveImage()),
                  ),
                  _DialogActionChip(
                    icon: Icons.share_rounded,
                    label: text.supportChatShareAction,
                    onPressed: () => unawaited(onShareImage()),
                  ),
                  _DialogActionChip(
                    icon: Icons.open_in_new_rounded,
                    label: text.supportChatOpenOriginalAction,
                    onPressed: () => unawaited(onOpenOriginal()),
                  ),
                  _DialogActionChip(
                    icon: Icons.close_rounded,
                    label: text.supportChatCloseAction,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogActionChip extends StatelessWidget {
  const _DialogActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
