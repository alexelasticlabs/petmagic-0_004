/// Estimates decide admission; the same allowance caps actual response bodies
/// through TemplateMediaCache, independently of server metadata accuracy.
class TemplatePreviewPrefetchPolicy {
  const TemplatePreviewPrefetchPolicy({
    required this.enabled,
    required this.videoAhead,
    required this.imageAhead,
    required this.behind,
    required this.maxEstimatedBytes,
    required this.maxFileBytes,
    required this.allowDetailPrefetch,
  });

  static const wifi = TemplatePreviewPrefetchPolicy(
    enabled: true,
    videoAhead: 4,
    imageAhead: 2,
    behind: 1,
    maxEstimatedBytes: 16 * 1024 * 1024,
    maxFileBytes: 8 * 1024 * 1024,
    allowDetailPrefetch: true,
  );
  static const cellular = TemplatePreviewPrefetchPolicy(
    enabled: true,
    videoAhead: 2,
    imageAhead: 1,
    behind: 0,
    maxEstimatedBytes: 4 * 1024 * 1024,
    maxFileBytes: 2 * 1024 * 1024,
    allowDetailPrefetch: false,
  );
  static const disabled = TemplatePreviewPrefetchPolicy(
    enabled: false,
    videoAhead: 0,
    imageAhead: 0,
    behind: 0,
    maxEstimatedBytes: 0,
    maxFileBytes: 0,
    allowDetailPrefetch: false,
  );

  final bool enabled;
  final int videoAhead;
  final int imageAhead;
  final int behind;
  final int maxEstimatedBytes;
  final int maxFileBytes;
  final bool allowDetailPrefetch;

  @override
  bool operator ==(Object other) =>
      other is TemplatePreviewPrefetchPolicy &&
      enabled == other.enabled &&
      videoAhead == other.videoAhead &&
      imageAhead == other.imageAhead &&
      behind == other.behind &&
      maxEstimatedBytes == other.maxEstimatedBytes &&
      maxFileBytes == other.maxFileBytes &&
      allowDetailPrefetch == other.allowDetailPrefetch;

  @override
  int get hashCode => Object.hash(
    enabled,
    videoAhead,
    imageAhead,
    behind,
    maxEstimatedBytes,
    maxFileBytes,
    allowDetailPrefetch,
  );
}
