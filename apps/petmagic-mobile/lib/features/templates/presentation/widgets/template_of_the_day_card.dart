import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'template_of_the_day_card_chrome.part.dart';
part 'template_of_the_day_card_media.part.dart';

class TemplateOfTheDayCard extends StatelessWidget {
  const TemplateOfTheDayCard({
    required this.template,
    required this.hasPremiumAccess,
    required this.onPressed,
    super.key,
  });

  final TemplateOfTheDayItem template;
  final bool hasPremiumAccess;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final thumbnailUrl = _normalizeTemplateOfTheDayMediaUrl(
      template.thumbnailUrl,
    );
    final previewMediaUrl = _normalizeTemplateOfTheDayMediaUrl(
      template.previewMediaUrl ?? template.previewAsset?.url,
    );
    final videoPreviewUrl =
        template.isVideo &&
            previewMediaUrl != null &&
            isVideoUrl(previewMediaUrl)
        ? previewMediaUrl
        : null;
    final imageUrl =
        thumbnailUrl ?? (!template.isVideo ? previewMediaUrl : null);
    final isPremiumLocked = template.isPremium && !hasPremiumAccess;
    final visibleTags = template.tags.take(3).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 340 ? 208.0 : 232.0;
        return PetMagicInteractiveSurface(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          scaleDown: 0.985,
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(
                      alpha: isLight ? 0.14 : 0.2,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
                color: colors.backgroundBottom,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null || videoPreviewUrl != null)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, mediaConstraints) {
                            final cacheWidth = _templateMediaCacheDimension(
                              mediaConstraints.maxWidth,
                              MediaQuery.devicePixelRatioOf(context),
                            );

                            if (videoPreviewUrl != null) {
                              return TemplateOfTheDayVideoPreview(
                                previewUrl: videoPreviewUrl,
                                thumbnailUrl: thumbnailUrl,
                                cacheWidth: cacheWidth,
                              );
                            }

                            if (imageUrl != null) {
                              return TemplatePreviewImage(
                                imageUrl: imageUrl,
                                cacheWidth: cacheWidth,
                                fit: BoxFit.cover,
                                placeholder:
                                    const _TemplateOfTheDayMediaFallback(),
                                errorBuilder: (_) =>
                                    const _TemplateOfTheDayMediaFallback(),
                              );
                            }

                            return const _TemplateOfTheDayMediaFallback();
                          },
                        ),
                      )
                    else
                      const _TemplateOfTheDayMediaFallback(),
                    const _TemplateOfTheDayDarkOverlay(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TemplateOfTheDayBadge(
                                icon: Icons.auto_awesome_rounded,
                                label: _templateOfTheDayBadgeLabel(
                                  rawLabel: template.badgeText,
                                  text: text,
                                ),
                              ),
                              _TemplateOfTheDayBadge(
                                icon: template.isVideo
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.image_outlined,
                                label: template.isVideo
                                    ? text.videoLabel
                                    : text.imageLabel,
                                isSubtle: true,
                              ),
                              if (template.isPremium)
                                _TemplateOfTheDayBadge(
                                  icon: Icons.workspace_premium_rounded,
                                  label: text.premiumLabel,
                                  isPremium: true,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            template.title.trim().isEmpty
                                ? text.templateOfTheDaySubtitle
                                : template.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: constraints.maxWidth < 340
                                      ? 17
                                      : 19,
                                  height: 1.03,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.74),
                                      blurRadius: 18,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.subtitle.trim().isEmpty
                                ? text.templateOfTheDaySubtitle
                                : template.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (visibleTags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _TemplateOfTheDayTags(tags: visibleTags),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TemplateOfTheDayCostChip(
                                cost: template.tokenCost,
                              ),
                              _TemplateOfTheDayAction(
                                label: isPremiumLocked
                                    ? text.templateUnlockPremiumAction
                                    : text.templateOfTheDayTryAction,
                                isPremium: template.isPremium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String templateOfTheDayLoadErrorLabel(BuildContext context) {
  return AppLocalizations.of(context).templateOfTheDayLoadFailed;
}

String _templateOfTheDayBadgeLabel({
  required String rawLabel,
  required AppLocalizations text,
}) {
  final trimmed = rawLabel.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'template of the day') {
    return text.templateOfTheDayTitle;
  }

  return trimmed;
}

String? _normalizeTemplateOfTheDayMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
  final parsed = Uri.tryParse(sanitized);
  final String candidate;
  if (parsed?.hasScheme == true) {
    candidate = parsed.toString();
  } else if (sanitized.startsWith('//')) {
    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    final scheme = (baseUri?.scheme.isNotEmpty ?? false)
        ? baseUri!.scheme
        : 'http';
    candidate = '$scheme:$sanitized';
  } else {
    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (baseUri == null) {
      return null;
    }

    final relativePath = sanitized.startsWith('/') ? sanitized : '/$sanitized';
    candidate = baseUri.resolve(relativePath).toString();
  }

  return parseSafeGenerationMediaUri(candidate)?.toString();
}

int? _templateMediaCacheDimension(double logicalSize, double pixelRatio) {
  if (!logicalSize.isFinite || logicalSize <= 0) {
    return null;
  }

  return (logicalSize * pixelRatio).ceil();
}
