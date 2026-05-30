import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class TemplateTypeFilters extends StatelessWidget {
  const TemplateTypeFilters({
    required this.selectedType,
    required this.categories,
    required this.selectedCategory,
    required this.onTypeSelected,
    required this.onCategorySelected,
    super.key,
  });

  final TemplateType? selectedType;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<TemplateType?> onTypeSelected;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final normalizedCategories = <String>[];
    final seen = <String>{};

    for (final category in categories) {
      final normalized = category.trim();
      if (normalized.isEmpty) {
        continue;
      }

      if (seen.add(normalized.toLowerCase())) {
        normalizedCategories.add(normalized);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              _FilterPill(
                label: text.allFilter,
                selected: selectedType == null,
                onTap: () => onTypeSelected(null),
                compact: true,
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: text.videosFilter,
                icon: Icons.play_circle_outline_rounded,
                selected: selectedType == TemplateType.video,
                onTap: () => onTypeSelected(TemplateType.video),
                compact: true,
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: text.imagesFilter,
                icon: Icons.image_outlined,
                selected: selectedType == TemplateType.image,
                onTap: () => onTypeSelected(TemplateType.image),
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: normalizedCategories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _FilterPill(
                  label: text.allFilter,
                  selected: selectedCategory == null,
                  onTap: () => onCategorySelected(null),
                  compact: true,
                );
              }

              final category = normalizedCategories[index - 1];
              return _FilterPill(
                label: category,
                selected: selectedCategory == category,
                onTap: () => onCategorySelected(category),
                compact: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final textStyle = Theme.of(context).textTheme.labelMedium;

    return PressableScale(
      onTap: onTap,
      haptic: PressableScaleHaptic.selection,
      borderRadius: BorderRadius.circular(compact ? 18 : 22),
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        curve: AppTheme.motionEmphasized,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.gold.withValues(alpha: 0.82)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surfaceGlass,
                    colors.surface.withValues(alpha: 0.9),
                  ],
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? colors.accent : colors.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.22),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 13 : 15,
                color: selected ? Colors.white : colors.textStrong,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textStyle?.copyWith(
                color: selected ? Colors.white : colors.textStrong,
                fontSize: compact ? 9.8 : 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
