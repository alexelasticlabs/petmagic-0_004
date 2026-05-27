part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _PendingAttachmentPreviewList extends StatelessWidget {
  const _PendingAttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
  });

  final List<_PendingSupportAttachment> attachments;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 66,
                        height: 66,
                        child: attachment.isVideo
                            ? ColoredBox(
                                color: colors.surface,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(
                                      child: Icon(
                                        Icons.videocam_outlined,
                                        color: colors.textMuted,
                                        size: 22,
                                      ),
                                    ),
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(
                                File(attachment.filePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return ColoredBox(
                                    color: colors.surface,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: colors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    Positioned(
                      top: -7,
                      right: -7,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onRemove == null
                              ? null
                              : () => onRemove!(index),
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  attachment.isVideo
                      ? text.supportChatVideoAttachedLabel
                      : text.supportChatPhotoAttachedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
