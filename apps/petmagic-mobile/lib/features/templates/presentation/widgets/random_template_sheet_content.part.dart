part of 'random_template_sheet.dart';

class _RandomTemplateSheetContent extends StatelessWidget {
  const _RandomTemplateSheetContent({
    required this.bottomInset,
    required this.categories,
    required this.type,
    required this.category,
    required this.access,
    required this.status,
    required this.onSelectType,
    required this.onSelectCategory,
    required this.onSelectAccess,
    required this.onResetFilters,
    required this.onFindRandomTemplate,
  });

  final double bottomInset;
  final List<String> categories;
  final TemplateType? type;
  final String? category;
  final TemplateRandomAccess access;
  final _RandomTemplateSheetStatus status;
  final ValueChanged<TemplateType?> onSelectType;
  final ValueChanged<String?> onSelectCategory;
  final ValueChanged<TemplateRandomAccess> onSelectAccess;
  final VoidCallback onResetFilters;
  final VoidCallback onFindRandomTemplate;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLoading = status == _RandomTemplateSheetStatus.loading;

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.viewPaddingOf(context).bottom,
                ),
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
                            Row(
                              children: [
                                Icon(
                                  Icons.casino_rounded,
                                  color: colors.accentInk,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    text.randomTemplateAction,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: colors.textStrong,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: colors.textSoft,
                                    size: 24,
                                  ),
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).closeButtonTooltip,
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
                                  selected: type == null,
                                  enabled: !isLoading,
                                  onTap: () => onSelectType(null),
                                ),
                                _RandomTemplateChip(
                                  label: text.videosFilter,
                                  icon: Icons.play_circle_outline_rounded,
                                  selected: type == TemplateType.video,
                                  enabled: !isLoading,
                                  onTap: () => onSelectType(TemplateType.video),
                                ),
                                _RandomTemplateChip(
                                  label: text.imagesFilter,
                                  icon: Icons.image_outlined,
                                  selected: type == TemplateType.image,
                                  enabled: !isLoading,
                                  onTap: () => onSelectType(TemplateType.image),
                                ),
                              ],
                            ),
                            _RandomTemplateSection(
                              title: text.randomTemplateCategoryLabel,
                              children: [
                                _RandomTemplateChip(
                                  label: text.allFilter,
                                  selected: category == null,
                                  enabled: !isLoading,
                                  onTap: () => onSelectCategory(null),
                                ),
                                for (final currentCategory in categories)
                                  _RandomTemplateChip(
                                    label: currentCategory,
                                    selected: category == currentCategory,
                                    enabled: !isLoading,
                                    onTap: () =>
                                        onSelectCategory(currentCategory),
                                  ),
                              ],
                            ),
                            _RandomTemplateSection(
                              title: text.randomTemplateAccessLabel,
                              children: [
                                _RandomTemplateChip(
                                  label: text.randomTemplateAccessAvailable,
                                  selected:
                                      access == TemplateRandomAccess.available,
                                  enabled: !isLoading,
                                  onTap: () => onSelectAccess(
                                    TemplateRandomAccess.available,
                                  ),
                                ),
                                _RandomTemplateChip(
                                  label: text.randomTemplateAccessFree,
                                  selected: access == TemplateRandomAccess.free,
                                  enabled: !isLoading,
                                  onTap: () =>
                                      onSelectAccess(TemplateRandomAccess.free),
                                ),
                                _RandomTemplateChip(
                                  label: text.randomTemplateAccessPremium,
                                  selected:
                                      access == TemplateRandomAccess.premium,
                                  enabled: !isLoading,
                                  onTap: () => onSelectAccess(
                                    TemplateRandomAccess.premium,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSwitcher(
                              duration: AppTheme.motionFast,
                              child: status == _RandomTemplateSheetStatus.empty
                                  ? _RandomTemplateStatusMessage(
                                      key: const ValueKey('random-empty'),
                                      title: text.randomTemplateNoMatches,
                                      message: text.randomTemplateNoMatchesHint,
                                      actionLabel:
                                          text.randomTemplateResetFilters,
                                      onAction: onResetFilters,
                                    )
                                  : status == _RandomTemplateSheetStatus.error
                                  ? _RandomTemplateStatusMessage(
                                      key: const ValueKey('random-error'),
                                      title: text.randomTemplateLoadFailed,
                                      message: text.randomTemplateNoMatchesHint,
                                      actionLabel: text.retryAction,
                                      onAction: onFindRandomTemplate,
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
                        onPressed: isLoading ? null : onFindRandomTemplate,
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
      ),
    );
  }
}
