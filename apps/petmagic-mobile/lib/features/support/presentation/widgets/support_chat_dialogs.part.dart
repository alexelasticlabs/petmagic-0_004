part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportImagePreviewDialog extends StatefulWidget {
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
  State<_SupportImagePreviewDialog> createState() =>
      _SupportImagePreviewDialogState();
}

class _SupportImagePreviewDialogState
    extends State<_SupportImagePreviewDialog> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.01 || details == null) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final position = details.localPosition;
    final zoomMatrix = Matrix4.identity()
      ..setEntry(0, 0, 2.4)
      ..setEntry(1, 1, 2.4)
      ..setTranslationRaw(-position.dx, -position.dy, 0);
    _transformationController.value = zoomMatrix;
  }

  @override
  Widget build(BuildContext context) {
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName?.trim().isNotEmpty == true
                          ? widget.fileName!
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
                  PopupMenuButton<_SupportImagePreviewAction>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    color: Colors.black.withValues(alpha: 0.92),
                    onSelected: (action) {
                      switch (action) {
                        case _SupportImagePreviewAction.save:
                          unawaited(widget.onSaveImage());
                          return;
                        case _SupportImagePreviewAction.share:
                          unawaited(widget.onShareImage());
                          return;
                        case _SupportImagePreviewAction.openOriginal:
                          unawaited(widget.onOpenOriginal());
                          return;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _SupportImagePreviewAction.save,
                        child: Text(text.supportChatSaveImageAction),
                      ),
                      PopupMenuItem(
                        value: _SupportImagePreviewAction.share,
                        child: Text(text.supportChatShareAction),
                      ),
                      PopupMenuItem(
                        value: _SupportImagePreviewAction.openOriginal,
                        child: Text(text.supportChatOpenOriginalAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.imageUrl,
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
            ),
          ],
        ),
      ),
    );
  }
}

enum _SupportImagePreviewAction { save, share, openOriginal }
