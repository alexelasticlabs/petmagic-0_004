import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

/// Shared by the viewer and its prefetch queue so both use the same file store.
class TemplatePreviewMediaSelection {
  TemplatePreviewMediaSelection(
    TemplateItem template, {
    required bool expand,
    bool preferLowResolution = true,
  }) {
    final asset = template.previewAsset;
    final assetUrl = parseSafeGenerationMediaUri(asset?.url)?.toString();
    final detailUrl = parseSafeGenerationMediaUri(
      template.detailPreviewUrl,
    )?.toString();
    final kind = template.mediaKind?.trim().toLowerCase();
    String? videoUrl(String? rawUrl) {
      final url = parseSafeGenerationMediaUri(rawUrl)?.toString();
      // Legacy feed payloads also put static thumbnails into loop fields.
      return kind != 'image' && (kind == 'video' || isVideoUrl(url))
          ? url
          : null;
    }

    final lowVideoUrl = videoUrl(template.feedLoopLowUrl);
    final mediumVideoUrl = videoUrl(template.feedLoopMediumUrl);
    final feedVideoUrl = preferLowResolution
        ? lowVideoUrl ?? mediumVideoUrl
        : mediumVideoUrl ?? lowVideoUrl;
    thumbnailUrl = parseSafeGenerationMediaUri(
      template.thumbnailUrl,
    )?.toString();
    mediaUrl = expand ? detailUrl ?? feedVideoUrl ?? assetUrl : assetUrl;
    final usesDetail = expand && detailUrl != null && mediaUrl == detailUrl;
    isVideo = usesDetail
        ? template.detailPreviewIsVideo
        : expand && feedVideoUrl != null && mediaUrl == feedVideoUrl
        ? true
        : mediaUrl != null && mediaUrl == assetUrl
        ? isVideoPreview(asset)
        : isVideoUrl(mediaUrl);
    videoFallbackUrls = expand && isVideo
        ? <String?>{
            feedVideoUrl,
            lowVideoUrl,
            mediumVideoUrl,
          }.whereType<String>().where((url) => url != mediaUrl).toList()
        : const [];
    imageUrl = usesDetail && !isVideo
        ? detailUrl
        : thumbnailUrl != null && !isVideoUrl(thumbnailUrl)
        ? thumbnailUrl
        : mediaUrl != null && !isVideo
        ? mediaUrl
        : null;
    // Legacy payloads can expose the same image as thumbnail and detail.
    // Reuse the feed's thumbnail cache in that case.
    usesDetailImageCache =
        expand && imageUrl == detailUrl && imageUrl != thumbnailUrl;
  }

  late final String? mediaUrl;
  late final String? thumbnailUrl;
  late final String? imageUrl;
  late final bool isVideo;
  late final bool usesDetailImageCache;
  late final List<String> videoFallbackUrls;
}
