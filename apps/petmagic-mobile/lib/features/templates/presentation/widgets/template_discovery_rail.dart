import 'dart:math' as math;

import 'discovery_collection_style.dart';

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_media.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_rail_navigation.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_snap_physics.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

part 'template_discovery_rail_heading.part.dart';
part 'template_discovery_rail_tile.part.dart';
part 'template_discovery_rail_badges.part.dart';

class TemplateDiscoveryRail extends StatelessWidget {
  const TemplateDiscoveryRail({
    required this.section,
    required this.sectionIndex,
    required this.moreLabel,
    required this.onMorePressed,
    required this.onTemplatePressed,
    required this.playbackManager,
    this.previewControllerFactory,
    super.key,
  });

  final TemplateDiscoverySection section;
  final int sectionIndex;
  final String moreLabel;
  final VoidCallback onMorePressed;
  final ValueChanged<TemplateItem> onTemplatePressed;
  final TemplateFeedPlaybackManager playbackManager;
  final TemplatePreviewControllerFactory? previewControllerFactory;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final tileWidth = compact ? 132.0 : 148.0;
    final previewHeight = tileWidth * 1.5;
    final textScaler = MediaQuery.textScalerOf(context);
    // Captions use the platform's reading face, leaving Comfortaa for headings.
    final titleStyle =
        Typography.material2021(
          platform: Theme.of(context).platform,
        ).black.titleSmall!.copyWith(
          inherit: false,
          color: colors.textStrong,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: 0,
        );
    var titleHeight = 0.0;
    for (final template in section.items) {
      final painter = TextPainter(
        text: TextSpan(text: template.title, style: titleStyle),
        maxLines: 2,
        ellipsis: '…',
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: tileWidth - 4);
      titleHeight = math.max(titleHeight, painter.height);
      painter.dispose();
    }
    final footerHeight = 8 + titleHeight.ceilToDouble();
    final contentWidth =
        section.items.length * (tileWidth + 9) - 9 + PetMagicSpacing.sm * 2;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiscoverySectionHeading(
            category: section.category,
            title: section.displayTitle,
            identity: section.identity,
            moreLabel: moreLabel,
            onMorePressed: onMorePressed,
          ),
          if (section.subtitle case final subtitle?)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PetMagicSpacing.sm,
              ),
              child: Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSoft),
              ),
            ),
          const SizedBox(height: PetMagicSpacing.xs),
          DiscoveryRailViewport(
            key: PageStorageKey('discovery-rail-position-${section.identity}'),
            showIndicator: contentWidth > MediaQuery.sizeOf(context).width,
            child: SizedBox(
              height: previewHeight + footerHeight,
              child: ListView.separated(
                key: ValueKey('discovery-rail-${section.identity}'),
                scrollDirection: Axis.horizontal,
                physics: DiscoverySnapPhysics(
                  itemExtent: tileWidth + 9,
                  parent: const BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: PetMagicSpacing.sm,
                ),
                itemCount: section.items.length,
                findItemIndexCallback: (key) {
                  final index = section.items.indexWhere(
                    (item) => ValueKey(item.templateId) == key,
                  );
                  return index < 0 ? null : index;
                },
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final template = section.items[index];
                  return SizedBox(
                    key: ValueKey(template.templateId),
                    width: tileWidth,
                    child: _DiscoveryTemplateTile(
                      template: template,
                      category: section.category,
                      paletteIndex: sectionIndex + index,
                      previewHeight: previewHeight,
                      titleStyle: titleStyle,
                      playbackManager: playbackManager,
                      previewControllerFactory: previewControllerFactory,
                      onPressed: () => onTemplatePressed(template),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
