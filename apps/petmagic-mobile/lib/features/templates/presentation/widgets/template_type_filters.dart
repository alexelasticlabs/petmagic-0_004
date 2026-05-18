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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _FilterPill(
                label: text.allFilter,
                selected: selectedType == null,
                onTap: () => onTypeSelected(null),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: text.videosFilter,
                icon: Icons.play_circle_outline_rounded,
                selected: selectedType == TemplateType.video,
                onTap: () => onTypeSelected(TemplateType.video),
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: text.imagesFilter,
                icon: Icons.image_outlined,
                selected: selectedType == TemplateType.image,
                onTap: () => onTypeSelected(TemplateType.image),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _FilterPill(
                label: text.allFilter,
                selected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _FilterPill(
                  label: category,
                  selected: selectedCategory == category,
                  onTap: () => onCategorySelected(
                    selectedCategory == category ? null : category,
                  ),
                ),
              ],
            ],
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
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

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
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.accent : colors.surfaceGlass,
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
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : colors.textStrong,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : colors.textStrong,
                  fontSize: 12,
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
