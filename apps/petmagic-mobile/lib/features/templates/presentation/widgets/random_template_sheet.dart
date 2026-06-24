import 'package:flutter/material.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

typedef RandomTemplateFinder =
    Future<TemplateItem?> Function(RandomTemplateSettings settings);

Future<TemplateItem?> showRandomTemplateSettingsSheet(
  BuildContext context, {
  required TemplateType? initialType,
  required String? initialCategory,
  required List<String> categories,
  required RandomTemplateFinder onFind,
}) {
  return showPetMagicModalBottomSheet<TemplateItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
    ),
    builder: (sheetContext, bottomInset) => _RandomTemplateSettingsSheet(
      initialType: initialType,
      initialCategory: initialCategory,
      categories: categories,
      bottomInset: bottomInset,
      onFind: onFind,
    ),
  );
}

class RandomTemplateSettings {
  const RandomTemplateSettings({
    required this.type,
    required this.category,
    required this.access,
  });

  final TemplateType? type;
  final String? category;
  final TemplateRandomAccess access;
}

enum _RandomTemplateSheetStatus { idle, loading, empty, error }

class _RandomTemplateSettingsSheet extends StatefulWidget {
  const _RandomTemplateSettingsSheet({
    required this.initialType,
    required this.initialCategory,
    required this.categories,
    required this.bottomInset,
    required this.onFind,
  });

  final TemplateType? initialType;
  final String? initialCategory;
  final List<String> categories;
  final double bottomInset;
  final RandomTemplateFinder onFind;

  @override
  State<_RandomTemplateSettingsSheet> createState() =>
      _RandomTemplateSettingsSheetState();
}

class _RandomTemplateSettingsSheetState
    extends State<_RandomTemplateSettingsSheet> {
  late TemplateType? _type = widget.initialType;
  late String? _category = _normalizeRandomCategory(widget.initialCategory);
  TemplateRandomAccess _access = TemplateRandomAccess.available;
  _RandomTemplateSheetStatus _status = _RandomTemplateSheetStatus.idle;

  List<String> get _categories {
    final seen = <String>{};
    final result = <String>[];
    for (final category in widget.categories) {
      final normalized = _normalizeRandomCategory(category);
      if (normalized == null) {
        continue;
      }
      if (seen.add(normalized.toLowerCase())) {
        result.add(normalized);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLoading = _status == _RandomTemplateSheetStatus.loading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, widget.bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceGlass.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.border.withValues(alpha: 0.78)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                Icons.casino_rounded,
                                color: colors.accent,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text.randomTemplateAction,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.textStrong,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.randomTemplateSheetDescription,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _RandomTemplateSection(
                            title: text.randomTemplateTypeLabel,
                            children: [
                              _RandomTemplateChip(
                                label: text.allFilter,
                                selected: _type == null,
                                enabled: !isLoading,
                                onTap: () => setState(() => _type = null),
                              ),
                              _RandomTemplateChip(
                                label: text.videosFilter,
                                icon: Icons.play_circle_outline_rounded,
                                selected: _type == TemplateType.video,
                                enabled: !isLoading,
                                onTap: () =>
                                    setState(() => _type = TemplateType.video),
                              ),
                              _RandomTemplateChip(
                                label: text.imagesFilter,
                                icon: Icons.image_outlined,
                                selected: _type == TemplateType.image,
                                enabled: !isLoading,
                                onTap: () =>
                                    setState(() => _type = TemplateType.image),
                              ),
                            ],
                          ),
                          _RandomTemplateSection(
                            title: text.randomTemplateCategoryLabel,
                            children: [
                              _RandomTemplateChip(
                                label: text.allFilter,
                                selected: _category == null,
                                enabled: !isLoading,
                                onTap: () => setState(() => _category = null),
                              ),
                              for (final category in _categories)
                                _RandomTemplateChip(
                                  label: category,
                                  selected: _category == category,
                                  enabled: !isLoading,
                                  onTap: () =>
                                      setState(() => _category = category),
                                ),
                            ],
                          ),
                          _RandomTemplateSection(
                            title: text.randomTemplateAccessLabel,
                            children: [
                              _RandomTemplateChip(
                                label: text.randomTemplateAccessAvailable,
                                selected:
                                    _access == TemplateRandomAccess.available,
                                enabled: !isLoading,
                                onTap: () => setState(
                                  () =>
                                      _access = TemplateRandomAccess.available,
                                ),
                              ),
                              _RandomTemplateChip(
                                label: text.randomTemplateAccessFree,
                                selected: _access == TemplateRandomAccess.free,
                                enabled: !isLoading,
                                onTap: () => setState(
                                  () => _access = TemplateRandomAccess.free,
                                ),
                              ),
                              _RandomTemplateChip(
                                label: text.randomTemplateAccessPremium,
                                selected:
                                    _access == TemplateRandomAccess.premium,
                                enabled: !isLoading,
                                onTap: () => setState(
                                  () => _access = TemplateRandomAccess.premium,
                                ),
                              ),
                            ],
                          ),
                          AnimatedSwitcher(
                            duration: AppTheme.motionFast,
                            child: _status == _RandomTemplateSheetStatus.empty
                                ? _RandomTemplateStatusMessage(
                                    key: const ValueKey('random-empty'),
                                    title: text.randomTemplateNoMatches,
                                    message: text.randomTemplateNoMatchesHint,
                                    actionLabel:
                                        text.randomTemplateResetFilters,
                                    onAction: _resetFilters,
                                  )
                                : _status == _RandomTemplateSheetStatus.error
                                ? _RandomTemplateStatusMessage(
                                    key: const ValueKey('random-error'),
                                    title: text.randomTemplateLoadFailed,
                                    message: text.randomTemplateNoMatchesHint,
                                    actionLabel: text.retryAction,
                                    onAction: _findRandomTemplate,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : _findRandomTemplate,
                      icon: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.textStrong,
                                ),
                              ),
                            )
                          : const Icon(Icons.casino_rounded),
                      label: Text(
                        isLoading
                            ? text.randomTemplateFinding
                            : text.randomTemplateFindAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _findRandomTemplate() async {
    if (_status == _RandomTemplateSheetStatus.loading) {
      return;
    }

    setState(() => _status = _RandomTemplateSheetStatus.loading);
    try {
      final template = await widget.onFind(
        RandomTemplateSettings(
          type: _type,
          category: _category,
          access: _access,
        ),
      );
      if (!mounted) {
        return;
      }
      if (template == null) {
        setState(() => _status = _RandomTemplateSheetStatus.empty);
        return;
      }
      Navigator.of(context).pop(template);
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'templates',
        operation: 'pickRandomTemplate',
        message: 'Failed to pick random template',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = _RandomTemplateSheetStatus.error);
    }
  }

  void _resetFilters() {
    setState(() {
      _type = null;
      _category = null;
      _access = TemplateRandomAccess.available;
      _status = _RandomTemplateSheetStatus.idle;
    });
  }
}

class _RandomTemplateSection extends StatelessWidget {
  const _RandomTemplateSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _RandomTemplateChip extends StatelessWidget {
  const _RandomTemplateChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return PressableScale(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      haptic: PressableScaleHaptic.selection,
      borderRadius: BorderRadius.circular(999),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.18)
              : colors.surfaceStrong.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? colors.accent
                : colors.border.withValues(alpha: 0.58),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: colors.accent),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.accent : colors.textSoft,
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

class _RandomTemplateStatusMessage extends StatelessWidget {
  const _RandomTemplateStatusMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.58)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _normalizeRandomCategory(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

TemplateRandomMode randomModeForTemplateType(TemplateType? type) {
  return switch (type) {
    null => TemplateRandomMode.any,
    TemplateType.image => TemplateRandomMode.image,
    TemplateType.video => TemplateRandomMode.video,
  };
}
