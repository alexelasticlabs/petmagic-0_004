import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

class GenerationsGalleryPage extends ConsumerStatefulWidget {
  const GenerationsGalleryPage({super.key});

  static const routePath = '/creations';

  @override
  ConsumerState<GenerationsGalleryPage> createState() =>
      _GenerationsGalleryPageState();
}

class _GenerationsGalleryPageState
    extends ConsumerState<GenerationsGalleryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(generationHistoryControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: RefreshIndicator.adaptive(
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
                                'Галерея',
                                style: Theme.of(context).textTheme.headlineSmall
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
                          'Все ваши AI-результаты и генерации в процессе.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSoft, height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        _FilterBar(selected: state.filter),
                      ],
                    ),
                  ),
                ),
                if (state.isLoading && state.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  )
                else if (state.errorMessage != null && state.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(message: state.errorMessage!),
                  )
                else if (state.items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      petMagicBottomNavInset(context) + 22,
                    ),
                    sliver: SliverList.separated(
                      itemCount: state.items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _GenerationCard(generation: state.items[index]),
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

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});

  final GenerationHistoryFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = <(GenerationHistoryFilter, String)>[
      (GenerationHistoryFilter.all, 'Все'),
      (GenerationHistoryFilter.active, 'В процессе'),
      (GenerationHistoryFilter.ready, 'Готовые'),
      (GenerationHistoryFilter.failed, 'Ошибки'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              selected: selected == filter.$1,
              label: Text(filter.$2),
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

class _GenerationCard extends ConsumerWidget {
  const _GenerationCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final outputUrl = generation.outputUrl;
    final sourceUrl = generation.sourceImageAsset?.url;
    final previewUrl = generation.isCompleted ? outputUrl : sourceUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        if (generation.isUnread) {
          ref
              .read(generationHistoryControllerProvider.notifier)
              .markRead(generation.generationId);
        }
        context.go(
          '${GenerationStatusPage.routePrefix}/${generation.generationId}',
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceGlass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: generation.isUnread
                ? colors.accent.withValues(alpha: 0.7)
                : colors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 82,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: previewUrl == null || previewUrl.isEmpty
                      ? _ThumbnailPlaceholder(generation: generation)
                      : CachedNetworkImage(
                          imageUrl: previewUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              _ThumbnailPlaceholder(generation: generation),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            generation.templateTitle ?? 'PetMagic result',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.textStrong,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                ),
                          ),
                        ),
                        if (generation.isUnread) const _UnreadDot(),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _StatusLine(generation: generation),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: generation.effectiveProgressPercent / 100,
                        color: _statusColor(colors, generation),
                        backgroundColor: colors.border.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _updatedLabel(generation.updatedAtUtc),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Icon(
          _statusIcon(generation),
          size: 16,
          color: _statusColor(colors, generation),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _statusLabel(generation),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnreadPill extends StatelessWidget {
  const _UnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
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
          '$count новых',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
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
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 42, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Здесь появятся ваши результаты',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите шаблон и загрузите фото питомца, чтобы создать первый результат.',
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

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return 'Готово';
  }
  if (generation.isFailed) {
    return generation.refundedAtUtc != null
        ? 'Ошибка, токены возвращены'
        : 'Ошибка';
  }
  return switch (generation.stage) {
    'queued' => 'В очереди',
    'preprocessing' => 'Подготавливаем фото',
    'generating' => 'Создаем результат',
    'finalizing' => 'Сохраняем файл',
    _ => 'В процессе',
  };
}

String _updatedLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Обновлено $hour:$minute';
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
