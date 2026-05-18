import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

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
        Row(
          children: [
            Expanded(
              child: _FilterPill(
                label: text.allFilter,
                selected: selectedType == null,
                onTap: () => onTypeSelected(null),
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterPill(
                label: text.videosFilter,
                icon: Icons.play_circle_outline_rounded,
                selected: selectedType == TemplateType.video,
                onTap: () => onTypeSelected(TemplateType.video),
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterPill(
                label: text.imagesFilter,
                icon: Icons.image_outlined,
                selected: selectedType == TemplateType.image,
                onTap: () => onTypeSelected(TemplateType.image),
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterPill(
              label: text.allFilter,
              selected: selectedCategory == null,
              onTap: () => onCategorySelected(null),
            ),
            for (final category in normalizedCategories)
              _FilterPill(
                label: category,
                selected: selectedCategory == category,
                onTap: () => onCategorySelected(category),
              ),
          ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 9 : 7,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.96)
                : colors.surfaceGlass,
            borderRadius: BorderRadius.circular(24),
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
                  size: compact ? 15 : 16,
                  color: selected ? Colors.white : colors.textStrong,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : colors.textStrong,
                  fontSize: compact ? 11 : 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
