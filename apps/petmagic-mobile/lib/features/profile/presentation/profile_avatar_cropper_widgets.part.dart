part of 'profile_avatar_cropper_page.dart';

class _AvatarCropViewportView extends StatelessWidget {
  const _AvatarCropViewportView({
    required this.cropSize,
    required this.viewport,
    required this.imageBytes,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  final double cropSize;
  final AvatarCropViewport viewport;
  final Uint8List imageBytes;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cropSize,
      height: cropSize,
      child: GestureDetector(
        key: profileAvatarCropViewportKey,
        behavior: HitTestBehavior.opaque,
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    key: profileAvatarCropImageKey,
                    left: viewport.offset.dx,
                    top: viewport.offset.dy,
                    width: viewport.imageSize.width * viewport.scale,
                    height: viewport.imageSize.height * viewport.scale,
                    child: Image.memory(imageBytes, fit: BoxFit.fill),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _AvatarCropOverlayPainter(
                  overlayColor: Colors.black.withValues(alpha: 0.46),
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.96),
                    width: 2,
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

class _AvatarCropActions extends StatelessWidget {
  const _AvatarCropActions({
    required this.isSaving,
    required this.resetLabel,
    required this.fitLabel,
    required this.onReset,
    required this.onFit,
  });

  final bool isSaving;
  final String resetLabel;
  final String fitLabel;
  final VoidCallback onReset;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: isSaving ? null : onReset,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: Text(resetLabel),
        ),
        OutlinedButton.icon(
          onPressed: isSaving ? null : onFit,
          icon: const Icon(Icons.fit_screen_rounded, size: 18),
          label: Text(fitLabel),
        ),
      ],
    );
  }
}
