part of 'template_flow_sheets.dart';

/// A silent video loop, including legacy templates without an image poster.
/// The immersive viewer borrows its page's texture, including a paused warm
/// neighbour. Standalone thumbnails use the visibility and decoder budget.
class TemplateVideoThumbnail extends StatelessWidget {
  const TemplateVideoThumbnail({
    required this.template,
    required this.isActive,
    required this.placeholder,
    this.controllerFactory,
    this.playbackRegistry,
    this.autoplay = true,
    super.key,
  });

  final TemplateItem template;
  final bool isActive;
  final Widget placeholder;
  final Future<VideoPlayerController> Function(String)? controllerFactory;
  final bool autoplay;
  final TemplatePreviewPlaybackRegistry? playbackRegistry;

  @override
  Widget build(BuildContext context) {
    final registry = playbackRegistry;
    if (registry != null) {
      return ListenableBuilder(
        listenable: registry,
        builder: (context, _) {
          final controller = registry._read(
            template.templateId,
            template.mediaVersion,
          );
          if (controller == null || !controller.value.isInitialized) {
            return placeholder;
          }
          return RepaintBoundary(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          );
        },
      );
    }
    final candidates = <String?>[
      template.feedLoopLowUrl,
      template.feedLoopMediumUrl,
      if (isVideoUrl(template.thumbnailUrl)) template.thumbnailUrl,
      if (isVideoUrl(template.animatedPreviewUrl)) template.animatedPreviewUrl,
      if (template.detailPreviewIsVideo) template.detailPreviewUrl,
      if (isVideoPreview(template.previewAsset)) template.previewAsset?.url,
    ];
    final urls = candidates.map(parseSafeGenerationMediaUri).whereType<Uri>();
    if (urls.isEmpty) return placeholder;
    return IgnorePointer(
      child: _NetworkVideoPreview(
        url: urls.first.toString(),
        playbackIdentity: 'thumbnail:${template.templateId}',
        mediaVersion: template.mediaVersion,
        isActive: isActive,
        autoplay: autoplay,
        useSharedPreviewCache: true,
        showPlaybackControl: false,
        placeholder: placeholder,
        controllerFactory: controllerFactory,
      ),
    );
  }
}
