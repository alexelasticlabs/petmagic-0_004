import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:share_plus/share_plus.dart';

class GenerationsGalleryPage extends ConsumerStatefulWidget {
  const GenerationsGalleryPage({super.key});

  static const routePath = '/creations';

  @override
  ConsumerState<GenerationsGalleryPage> createState() =>
      _GenerationsGalleryPageState();
}

class _GenerationsGalleryPageState
    extends ConsumerState<GenerationsGalleryPage> {
  bool _readyExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(generationHistoryControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(generationHistoryControllerProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _GalleryAtmosphere()),
              RefreshIndicator.adaptive(
                color: colors.accent,
                onRefresh: () => ref
                    .read(generationHistoryControllerProvider.notifier)
                    .load(refresh: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    text.navCreations,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: colors.textStrong,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                if (state.unreadCount > 0)
                                  _UnreadPill(count: state.unreadCount),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _subtitleForFilter(text, state.filter),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _FilterBar(selected: state.filter),
                          ],
                        ),
                      ),
                    ),
                    ..._buildContentSlivers(context, text, state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    AppLocalizations text,
    GenerationHistoryState state,
  ) {
    final filteredItems = _itemsForSelectedFilter(state.items, state.filter);

    if (state.isLoading && filteredItems.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }
    if (state.errorMessage != null && filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(message: state.errorMessage!),
        ),
      ];
    }
    if (filteredItems.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
      ];
    }

    final bottomInset = petMagicBottomNavInset(context) + 22;

    if (state.filter == GenerationHistoryFilter.all) {
      final activeItems = state.items
          .where((item) => !item.isTerminal)
          .toList(growable: false);
      final readyItems = state.items
          .where((item) => item.isCompleted)
          .toList(growable: false);
      final failedItems = state.items
          .where((item) => item.isFailed)
          .toList(growable: false);

      final slivers = <Widget>[];
      if (activeItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionActive,
            activeItems.length,
          ),
        );
        slivers.add(_activeListSliver(activeItems));
      }
      if (readyItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionReady,
            readyItems.length,
          ),
        );
        slivers.add(_readyGridSliver(readyItems));
      }
      if (failedItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionFailed,
            failedItems.length,
          ),
        );
        slivers.add(_failedListSliver(failedItems));
      }
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottomInset)));
      return slivers;
    }

    if (state.filter == GenerationHistoryFilter.ready) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset),
          sliver: SliverGrid.builder(
            itemCount: filteredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) =>
                _ReadyGridCard(generation: filteredItems[index]),
          ),
        ),
      ];
    }

    if (state.filter == GenerationHistoryFilter.active) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: const SliverToBoxAdapter(child: _ActiveInfoCard()),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _ActiveCard(generation: filteredItems[index]),
          ),
        ),
      ];
    }

    if (state.filter == GenerationHistoryFilter.failed) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _FailedCard(generation: filteredItems[index]),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset),
        sliver: SliverList.separated(
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final generation = filteredItems[index];
            if (generation.isFailed) {
              return _FailedCard(generation: generation);
            }
            return _ActiveCard(generation: generation);
          },
        ),
      ),
    ];
  }

  List<TemplateGenerationResult> _itemsForSelectedFilter(
    List<TemplateGenerationResult> items,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => items,
      GenerationHistoryFilter.active =>
        items.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        items.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        items.where((item) => item.isFailed).toList(growable: false),
    };
  }

  Widget _sectionHeaderSliver(String title, int count) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      sliver: SliverToBoxAdapter(
        child: _SectionHeader(title: title, count: count),
      ),
    );
  }

  Widget _activeListSliver(List<TemplateGenerationResult> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ActiveCard(generation: items[index]),
      ),
    );
  }

  Widget _failedListSliver(List<TemplateGenerationResult> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _FailedCard(generation: items[index]),
      ),
    );
  }

  Widget _readyGridSliver(List<TemplateGenerationResult> readyItems) {
    final visibleCount = _readyExpanded
        ? readyItems.length
        : (readyItems.length > 4 ? 4 : readyItems.length);
    final visibleItems = readyItems.take(visibleCount).toList(growable: false);
    final hiddenCount = readyItems.length - visibleItems.length;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverGrid.builder(
            itemCount: visibleItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) =>
                _ReadyGridCard(generation: visibleItems[index]),
          ),
          if (hiddenCount > 0 || _readyExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ShowMoreButton(
                  expanded: _readyExpanded,
                  hiddenCount: hiddenCount,
                  onPressed: () =>
                      setState(() => _readyExpanded = !_readyExpanded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});

  final GenerationHistoryFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final filters = <(GenerationHistoryFilter, String)>[
      (GenerationHistoryFilter.all, text.allFilter),
      (GenerationHistoryFilter.active, text.generationStatusFilterActive),
      (GenerationHistoryFilter.ready, text.generationStatusFilterReady),
      (GenerationHistoryFilter.failed, text.generationStatusFilterFailed),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              selected: selected == filter.$1,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected == filter.$1
                      ? colors.accent.withValues(alpha: 0.5)
                      : colors.border.withValues(alpha: 0.7),
                ),
              ),
              selectedColor: colors.accent.withValues(alpha: 0.2),
              backgroundColor: colors.surfaceGlass,
              label: Text(
                filter.$2,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected == filter.$1
                      ? colors.accent
                      : colors.textSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onSelected: (_) => ref
                  .read(generationHistoryControllerProvider.notifier)
                  .load(filter: filter.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _GalleryAtmosphere extends StatelessWidget {
  const _GalleryAtmosphere();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(
              size: 260,
              color: colors.accent.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 170,
            right: -110,
            child: _GlowBlob(
              size: 300,
              color: colors.blue.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -60,
            child: _GlowBlob(
              size: 220,
              color: colors.purple.withValues(alpha: 0.11),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onPressed,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Ink(
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceGlass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: Center(
          child: Text(
            expanded
                ? text.generationStatusCollapseAction
                : text.generationStatusShowMoreAction(hiddenCount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveInfoCard extends StatelessWidget {
  const _ActiveInfoCard();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: colors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.generationStatusActiveInfoHint,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewUrl = _previewUrl(generation);

    void openGeneration() {
      if (generation.isUnread) {
        ref
            .read(generationHistoryControllerProvider.notifier)
            .markRead(generation.generationId);
      }
      context.go(
        '${GenerationStatusPage.routePrefix}/${generation.generationId}',
      );
    }

    return _CardEntrance(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: openGeneration,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: generation.isUnread
                  ? colors.accent.withValues(alpha: 0.7)
                  : colors.border.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: previewUrl == null || previewUrl.isEmpty
                              ? _ThumbnailPlaceholder(generation: generation)
                              : CachedNetworkImage(
                                  imageUrl: previewUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      _ThumbnailPlaceholder(
                                        generation: generation,
                                      ),
                                ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: _TypeBadge(generation: generation),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        generation.templateTitle ??
                            text.generationStatusResultTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_typeLabel(text, generation)} · ${generation.tokenCost} PawSpark',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stageStatusLabel(text, generation),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _statusColor(colors, generation),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value:
                                    generation.effectiveProgressPercent / 100,
                                color: colors.accent,
                                backgroundColor: colors.border.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${generation.effectiveProgressPercent}%',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _estimatedTimeLabel(text, generation),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: openGeneration,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accent.withValues(
                              alpha: 0.22,
                            ),
                            foregroundColor: colors.accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(text.generationStatusOpenStatusAction),
                        ),
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
  }
}

class _ReadyGridCard extends ConsumerWidget {
  const _ReadyGridCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewUrl = _previewUrl(generation);

    Future<void> openGeneration() async {
      if (generation.isUnread) {
        await ref
            .read(generationHistoryControllerProvider.notifier)
            .markRead(generation.generationId);
      }
      if (!context.mounted) {
        return;
      }
      context.go(
        '${GenerationStatusPage.routePrefix}/${generation.generationId}',
      );
    }

    return _CardEntrance(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openGeneration,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: previewUrl == null || previewUrl.isEmpty
                            ? _ThumbnailPlaceholder(generation: generation)
                            : CachedNetworkImage(
                                imageUrl: previewUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    _ThumbnailPlaceholder(
                                      generation: generation,
                                    ),
                              ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _TypeBadge(generation: generation),
                    ),
                    if (_isVideoGeneration(generation) &&
                        generation.outputVideoDurationSeconds != null)
                      Positioned(
                        left: 8,
                        top: 34,
                        child: _DurationBadge(
                          seconds: generation.outputVideoDurationSeconds!,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            generation.templateTitle ??
                                text.generationStatusResultTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.textStrong,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_typeLabel(text, generation)} · ${generation.tokenCost} PawSpark',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formattedDate(text, generation.updatedAtUtc),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _showReadyCardActions(context, text, ref, generation),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedCard extends ConsumerWidget {
  const _FailedCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final previewUrl = _previewUrl(generation);
    final failureReason = _failureReasonMessage(text, generation);

    void openGeneration() {
      if (generation.isUnread) {
        ref
            .read(generationHistoryControllerProvider.notifier)
            .markRead(generation.generationId);
      }
      context.go(
        '${GenerationStatusPage.routePrefix}/${generation.generationId}',
      );
    }

    void pickAnotherPhoto() {
      context.go(TemplatesPage.routePath);
    }

    void openSupport() {
      context.go(SupportChatPage.routePath);
    }

    return _CardEntrance(
      child: Ink(
        decoration: BoxDecoration(
          color: colors.surfaceGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: previewUrl == null || previewUrl.isEmpty
                                ? _ThumbnailPlaceholder(generation: generation)
                                : CachedNetworkImage(
                                    imageUrl: previewUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        _ThumbnailPlaceholder(
                                          generation: generation,
                                        ),
                                  ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          top: 6,
                          child: _TypeBadge(generation: generation),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          generation.templateTitle ??
                              text.generationStatusResultTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_typeLabel(text, generation)} · ${generation.tokenCost} PawSpark',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          text.generationStatusFailedTitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.danger,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (generation.refundedAtUtc != null ||
                            generation.tokenCost > 0)
                          Text(
                            text.generationStatusTokensRefundedShort,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        _showFailedCardActions(context, text, ref, generation),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceStrong.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.7),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: colors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          failureReason,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.textSoft, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: pickAnotherPhoto,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.backgroundBottom,
                ),
                child: Text(text.generationStatusPickAnotherPhotoAction),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: openSupport,
                child: Text(text.generationStatusContactSupportAction),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: openGeneration,
                  child: Text(text.generationStatusOpenStatusAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardEntrance extends StatelessWidget {
  const _CardEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.92, end: 1),
      child: child,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            child: animatedChild,
          ),
        );
      },
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text.generationStatusUnreadCount(count),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Icon(
        _statusIcon(generation),
        color: _statusColor(colors, generation),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 42, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            text.generationStatusEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.generationStatusEmptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String _subtitleForFilter(
  AppLocalizations text,
  GenerationHistoryFilter filter,
) {
  return switch (filter) {
    GenerationHistoryFilter.all => text.generationStatusSubtitleAll,
    GenerationHistoryFilter.active => text.generationStatusSubtitleActive,
    GenerationHistoryFilter.ready => text.generationStatusSubtitleReady,
    GenerationHistoryFilter.failed => text.generationStatusSubtitleFailed,
  };
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 42, color: colors.danger),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => ref
                .read(generationHistoryControllerProvider.notifier)
                .load(refresh: true),
            child: Text(text.retryAction),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isVideo = _isVideoGeneration(generation);
    final background = isVideo
        ? colors.purple.withValues(alpha: 0.78)
        : colors.blue.withValues(alpha: 0.78);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          isVideo ? text.videoLabel : text.imageLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});

  final double seconds;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = seconds.round();
    final minutes = totalSeconds ~/ 60;
    final restSeconds = totalSeconds % 60;
    final label =
        '${minutes.toString().padLeft(2, '0')}:${restSeconds.toString().padLeft(2, '0')}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _typeLabel(AppLocalizations text, TemplateGenerationResult generation) {
  return _isVideoGeneration(generation) ? text.videoLabel : text.imageLabel;
}

String _stageStatusLabel(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.effectiveProgressPercent >= 95) {
    return text.generationStatusEtaFinalizing;
  }

  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'uploading' => text.templateFlowStepProcessPhoto,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'processing' => text.templateFlowStepCreateMagic,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' => text.templateFlowStepFinalTouches,
    _ => text.templateFlowStepCreateMagic,
  };
}

String _estimatedTimeLabel(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  if (generation.stage == 'queued') {
    return text.generationStatusEtaStartsSoon;
  }
  if ((generation.estimatedDurationLabel ?? '').isNotEmpty) {
    return text.generationStatusEtaEstimated(
      generation.estimatedDurationLabel!,
    );
  }
  return text.generationStatusEtaNotifyHint;
}

String _failureReasonMessage(
  AppLocalizations text,
  TemplateGenerationResult generation,
) {
  final code = (generation.failureCode ?? '').toLowerCase();
  final message = (generation.failureMessage ?? '').toLowerCase();
  final combined = '$code $message';

  if (combined.contains('photo') ||
      combined.contains('face') ||
      combined.contains('pet') ||
      combined.contains('quality')) {
    return text.generationStatusFailurePhotoHint;
  }

  return text.generationStatusFailureTechnicalHint;
}

String _formattedDate(AppLocalizations text, DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final dayDiff = today.difference(date).inDays;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  if (dayDiff == 0) {
    return text.generationStatusDateToday('$hour:$minute');
  }
  if (dayDiff == 1) {
    return text.generationStatusDateYesterday('$hour:$minute');
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  return '$day.$month.$year, $hour:$minute';
}

IconData _statusIcon(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return Icons.check_circle_rounded;
  }
  if (generation.isFailed) {
    return Icons.error_outline_rounded;
  }
  return Icons.auto_awesome_rounded;
}

Color _statusColor(PetMagicColors colors, TemplateGenerationResult generation) {
  if (generation.isFailed) {
    return colors.danger;
  }
  if (generation.isCompleted) {
    return colors.accent;
  }
  return colors.gold;
}

String? _previewUrl(TemplateGenerationResult generation) {
  if (generation.isCompleted &&
      generation.outputUrl != null &&
      generation.outputUrl!.isNotEmpty) {
    return generation.outputUrl;
  }
  if (generation.sourceImageAsset?.url != null &&
      generation.sourceImageAsset!.url.isNotEmpty) {
    return generation.sourceImageAsset!.url;
  }
  if (generation.normalizedImageUrl != null &&
      generation.normalizedImageUrl!.isNotEmpty) {
    return generation.normalizedImageUrl;
  }
  return null;
}

bool _isVideoGeneration(TemplateGenerationResult generation) {
  final type = generation.templateType?.toLowerCase() ?? '';
  return type.contains('video') ||
      generation.outputVideoDurationSeconds != null;
}

Future<void> _showReadyCardActions(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final colors = context.petMagicColors;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: colors.surface,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(text.generationStatusOpenStatusAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (generation.isUnread) {
                  ref
                      .read(generationHistoryControllerProvider.notifier)
                      .markRead(generation.generationId);
                }
                context.go(
                  '${GenerationStatusPage.routePrefix}/${generation.generationId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(text.generationStatusSaveAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_saveGenerationToDevice(context, text, generation));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: Text(text.supportChatShareAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final outputUrl = generation.outputUrl;
                if (outputUrl == null || outputUrl.isEmpty) {
                  _notifySoon(
                    context,
                    text.generationStatusResultUnavailableForShare,
                  );
                  return;
                }
                SharePlus.instance.share(ShareParams(text: outputUrl));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(text.generationStatusDeleteAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _notifySoon(context, text.generationStatusDeleteSoonMessage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(text.generationStatusReportProblemAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(SupportChatPage.routePath);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showFailedCardActions(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final colors = context.petMagicColors;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: colors.surface,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: Text(text.generationStatusOpenStatusAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (generation.isUnread) {
                  ref
                      .read(generationHistoryControllerProvider.notifier)
                      .markRead(generation.generationId);
                }
                context.go(
                  '${GenerationStatusPage.routePrefix}/${generation.generationId}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_search_rounded),
              title: Text(text.generationStatusPickAnotherPhotoAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(TemplatesPage.routePath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded),
              title: Text(text.generationStatusContactSupportAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(SupportChatPage.routePath);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _saveGenerationToDevice(
  BuildContext context,
  AppLocalizations text,
  TemplateGenerationResult generation,
) async {
  final outputUrl = generation.outputUrl;
  if (outputUrl == null || outputUrl.isEmpty) {
    _notifySoon(context, text.generationStatusResultUnavailableForSave);
    return;
  }

  final fileName = _buildGenerationFileName(generation, outputUrl);
  final extension = extractFileExtension(fileName);
  final allowedExtensions = extension == null ? null : <String>[extension];

  try {
    final bytes = await downloadFileBytes(outputUrl);
    final wasSaved = await saveBytesToDevice(
      bytes: bytes,
      dialogTitle: text.generationStatusSaveFileDialogTitle,
      fileName: fileName,
      allowedExtensions: allowedExtensions,
    );

    if (!context.mounted) {
      return;
    }

    if (!wasSaved) {
      return;
    }

    _notifySoon(context, text.generationStatusFileSavedMessage);
  } on Object {
    if (!context.mounted) {
      return;
    }

    _notifySoon(context, text.generationStatusFileSaveFailedMessage);
  }
}

String _buildGenerationFileName(
  TemplateGenerationResult generation,
  String outputUrl,
) {
  final normalizedTitle = sanitizeFileName(
    generation.templateTitle,
    fallback: 'petmagic_result',
  );
  final extensionFromRemote = extensionFromUrl(outputUrl);
  final extension = extensionFromRemote.isEmpty
      ? (_isVideoGeneration(generation) ? 'mp4' : 'jpg')
      : extensionFromRemote;
  return '${normalizedTitle}_${generation.generationId}.$extension';
}

void _notifySoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
