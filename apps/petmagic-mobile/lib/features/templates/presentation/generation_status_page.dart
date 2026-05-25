import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:share_plus/share_plus.dart';

class GenerationStatusPage extends ConsumerStatefulWidget {
  const GenerationStatusPage({required this.generationId, super.key});

  static const routePrefix = '/generations';

  final String generationId;

  @override
  ConsumerState<GenerationStatusPage> createState() =>
      _GenerationStatusPageState();
}

class _GenerationStatusPageState extends ConsumerState<GenerationStatusPage> {
  Timer? _pollTimer;
  TemplateGenerationResult? _generation;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_generation?.isTerminal == true) {
        _pollTimer?.cancel();
        return;
      }
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final generation = _generation;

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
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
              children: [
                _Header(
                  title: 'Статус генерации',
                  onBack: () => context.go('/templates'),
                ),
                const SizedBox(height: 18),
                if (_isLoading && generation == null)
                  const _LoadingCard()
                else if (_errorMessage != null && generation == null)
                  _ErrorCard(message: _errorMessage!, onRetry: () => _load())
                else if (generation != null) ...[
                  _StatusHero(generation: generation),
                  const SizedBox(height: 14),
                  _StageCard(generation: generation),
                  const SizedBox(height: 14),
                  if (generation.isCompleted) ...[
                    _ResultCard(generation: generation),
                    const SizedBox(height: 14),
                    _FeedbackCard(
                      isSubmitting: _isSubmittingFeedback,
                      onRatingSelected: _handleRatingSelected,
                    ),
                  ] else if (generation.isFailed)
                    _FailureCard(generation: generation)
                  else
                    _BackgroundHintCard(generation: generation),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/templates'),
                          icon: const Icon(Icons.auto_awesome_motion_rounded),
                          label: const Text('Продолжить'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.go('/creations'),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Галерея'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final generation = await ref
          .read(templateGenerationRepositoryProvider)
          .fetchGeneration(widget.generationId);
      if (!mounted) {
        return;
      }

      setState(() {
        _generation = generation;
        _isLoading = false;
        _errorMessage = null;
      });

      if (generation.isCompleted) {
        _pollTimer?.cancel();
        unawaited(
          ref
              .read(generationHistoryControllerProvider.notifier)
              .markRead(generation.generationId),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _handleRatingSelected(int rating) async {
    final generation = _generation;
    if (generation == null) {
      return;
    }

    if (rating > 1) {
      await _submitFeedback(generation, rating, const [], null);
      return;
    }

    final result = await showModalBottomSheet<_FeedbackResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NegativeFeedbackSheet(),
    );

    if (result == null) {
      return;
    }

    await _submitFeedback(generation, rating, result.reasons, result.comment);
  }

  Future<void> _submitFeedback(
    TemplateGenerationResult generation,
    int rating,
    List<String> reasons,
    String? comment,
  ) async {
    setState(() => _isSubmittingFeedback = true);
    try {
      await ref
          .read(generationHistoryControllerProvider.notifier)
          .submitFeedback(
            generationId: generation.generationId,
            rating: rating,
            selectedReasons: reasons,
            comment: comment,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Спасибо! Ваш отзыв поможет улучшить PetMagic.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.textStrong,
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final progress = generation.effectiveProgressPercent;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _statusIcon(generation),
                color: _statusColor(colors, generation),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  generation.templateTitle ?? 'PetMagic result',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _statusTitle(generation),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress / 100,
              color: _statusColor(colors, generation),
              backgroundColor: colors.border.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            generation.isTerminal
                ? _terminalHint(generation)
                : 'Обычно это занимает несколько минут. Вы можете продолжить пользоваться приложением.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _StageRow(
            label: 'В очереди',
            done: generation.effectiveProgressPercent >= 10,
          ),
          _StageRow(
            label: 'Подготавливаем фото',
            done: generation.effectiveProgressPercent >= 30,
          ),
          _StageRow(
            label: 'Создаем результат',
            done: generation.effectiveProgressPercent >= 65,
          ),
          _StageRow(
            label: 'Сохраняем файл',
            done: generation.effectiveProgressPercent >= 90,
          ),
          _StageRow(label: 'Готово', done: generation.isCompleted),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? colors.accent : colors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: done ? colors.textStrong : colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final outputUrl = generation.outputUrl ?? '';
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: outputUrl.isEmpty
                  ? _MediaPlaceholder(label: 'Результат пока недоступен')
                  : _isVideo(generation)
                  ? _MediaPlaceholder(label: 'Видео готово')
                  : CachedNetworkImage(
                      imageUrl: outputUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const _MediaPlaceholder(
                            label: 'Не удалось загрузить результат',
                          ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: outputUrl.isEmpty
                ? null
                : () => SharePlus.instance.share(ShareParams(text: outputUrl)),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(
              _isVideo(generation) ? 'Поделиться видео' : 'Поделиться',
              style: TextStyle(color: colors.textStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              generation.refundedAtUtc != null
                  ? 'Не удалось создать результат. Мы вернули токены на ваш баланс.'
                  : 'Не удалось создать результат. Попробуйте другое фото или повторите позже.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundHintCard extends StatelessWidget {
  const _BackgroundHintCard({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined, color: colors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Генерация продолжается на сервере. Мы покажем результат в Галерее, когда все будет готово.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSoft,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.isSubmitting,
    required this.onRatingSelected,
  });

  final bool isSubmitting;
  final ValueChanged<int> onRatingSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Как вам результат?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RatingButton(
                label: 'Отлично',
                icon: Icons.favorite_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(3),
              ),
              const SizedBox(width: 8),
              _RatingButton(
                label: 'Нормально',
                icon: Icons.thumb_up_alt_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(2),
              ),
              const SizedBox(width: 8),
              _RatingButton(
                label: 'Не очень',
                icon: Icons.sentiment_dissatisfied_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: colors.accent, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
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

class _NegativeFeedbackSheet extends StatefulWidget {
  const _NegativeFeedbackSheet();

  @override
  State<_NegativeFeedbackSheet> createState() => _NegativeFeedbackSheetState();
}

class _NegativeFeedbackSheetState extends State<_NegativeFeedbackSheet> {
  final _commentController = TextEditingController();
  final _selectedReasons = <String>{};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final reasons = <(String, String)>[
      ('pet_not_similar', 'Питомец плохо похож на себя'),
      ('face_distorted', 'Морда или лицо искажены'),
      ('strange_motion', 'Движение выглядит странно'),
      ('preview_mismatch', 'Результат отличается от превью'),
      ('low_quality', 'Качество получилось низким'),
      ('style_disliked', 'Не понравился стиль'),
      ('other', 'Другое'),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Что можно улучшить?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final reason in reasons)
                      FilterChip(
                        selected: _selectedReasons.contains(reason.$1),
                        label: Text(reason.$2),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedReasons.add(reason.$1);
                            } else {
                              _selectedReasons.remove(reason.$1);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    hintText: 'Расскажите коротко, что не так',
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _FeedbackResult(
                      _selectedReasons.toList(growable: false),
                      _commentController.text.trim().isEmpty
                          ? null
                          : _commentController.text.trim(),
                    ),
                  ),
                  child: const Text('Отправить отзыв'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackResult {
  const _FeedbackResult(this.reasons, this.comment);

  final List<String> reasons;
  final String? comment;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: TextStyle(color: colors.textSoft)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

String _statusTitle(TemplateGenerationResult generation) {
  if (generation.isCompleted) {
    return 'Ваш результат готов';
  }
  if (generation.isFailed) {
    return 'Не удалось создать результат';
  }
  return switch (generation.stage) {
    'queued' => 'В очереди',
    'preprocessing' => 'Подготавливаем фото',
    'generating' => 'Создаем результат',
    'finalizing' => 'Сохраняем файл',
    _ => 'Создаем магию...',
  };
}

String _terminalHint(TemplateGenerationResult generation) {
  if (generation.isFailed) {
    return generation.refundedAtUtc != null
        ? 'Токены возвращены автоматически.'
        : 'Техническая ошибка уже зафиксирована.';
  }
  return 'Откройте результат, поделитесь им или оставьте отзыв.';
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

bool _isVideo(TemplateGenerationResult generation) {
  return generation.templateType?.toLowerCase() == 'video' ||
      (generation.outputUrl ?? '').toLowerCase().endsWith('.mp4');
}
