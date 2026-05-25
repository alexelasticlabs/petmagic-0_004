part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  final _PendingSupportAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1.55,
            child: Image.file(
              File(attachment.filePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return ColoredBox(
                  color: colors.surface,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.56),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
