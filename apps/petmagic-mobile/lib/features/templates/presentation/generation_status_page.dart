import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
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
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

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
              padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset),
              children: [
                _Header(
                  title: generation?.templateTitle ?? 'Статус генерации',
                  subtitle: generation == null
                      ? null
                      : '${_typeLabel(generation)} • ${generation.tokenCost} ${_tokensLabel(generation.tokenCost)}',
                  onBack: () => context.go('/creations'),
                  onMenu: generation == null
                      ? null
                      : () => _openActionsSheet(generation),
                ),
                const SizedBox(height: 18),
                if (_isLoading && generation == null)
                  const _LoadingCard()
                else if (_errorMessage != null && generation == null)
                  _ErrorCard(message: _errorMessage!, onRetry: () => _load())
                else if (generation != null) ...[
                  _StatusHero(generation: generation),
                  const SizedBox(height: 14),
                  if (generation.isCompleted) ...[
                    _ResultCard(generation: generation),
                    const SizedBox(height: 14),
                    _ReadyActionsRow(
                      onSave: _saveSoon,
                      onShare: () => _shareResult(generation),
                      onDelete: _deleteSoon,
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      rows: [
                        ('Шаблон', generation.templateTitle ?? 'Без названия'),
                        (
                          'Создано',
                          _formatDateTime(
                            generation.completedAtUtc ?? generation.updatedAtUtc,
                          ),
                        ),
                        ('Тип', _typeLabel(generation)),
                        (
                          'Стоимость',
                          '${generation.tokenCost} ${_tokensLabel(generation.tokenCost)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FeedbackCard(
                      isSubmitting: _isSubmittingFeedback,
                      onRatingSelected: _handleRatingSelected,
                    ),
                  ] else if (generation.isFailed) ...[
                    _FailureCard(generation: generation),
                    const SizedBox(height: 14),
                    _FailedActions(
                      onPickAnotherPhoto: () => context.go(TemplatesPage.routePath),
                      onRetry: _retrySoon,
                      onSupport: () => context.go(SupportChatPage.routePath),
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      rows: [
                        ('Шаблон', generation.templateTitle ?? 'Без названия'),
                        ('Тип', _typeLabel(generation)),
                        ('Попытка', '${generation.attemptCount}'),
                        (
                          'Стоимость',
                          '${generation.tokenCost} ${_tokensLabel(generation.tokenCost)}',
                        ),
                      ],
                    ),
                  ] else ...[
                    _StageCard(generation: generation),
                    const SizedBox(height: 14),
                    _BackgroundHintCard(generation: generation),
                    const SizedBox(height: 14),
                    _ActiveActions(
                      onContinue: () => context.go('/templates'),
                      onCancel: _cancelSoon,
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      rows: [
                        ('Шаблон', generation.templateTitle ?? 'Без названия'),
                        ('Начато', _formatDateTime(generation.createdAtUtc)),
                        ('Тип', _typeLabel(generation)),
                        (
                          'Стоимость',
                          '${generation.tokenCost} ${_tokensLabel(generation.tokenCost)}',
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActionsSheet(TemplateGenerationResult generation) async {
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
              if (generation.isCompleted) ...[
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Сохранить'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _saveSoon();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Поделиться'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareResult(generation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Удалить'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteSoon();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Сообщить о проблеме'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(SupportChatPage.routePath);
                  },
                ),
              ] else if (generation.isFailed) ...[
                ListTile(
                  leading: const Icon(Icons.image_search_rounded),
                  title: const Text('Выбрать другое фото'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(TemplatesPage.routePath);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Попробовать снова'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _retrySoon();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Сообщить в поддержку'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(SupportChatPage.routePath);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Открыть галерею'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/creations');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: const Text('Отменить генерацию'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _cancelSoon();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _saveSoon() {
    _showInfo('Сохранение появится в ближайшем обновлении.');
  }

  void _deleteSoon() {
    _showInfo('Удаление из истории скоро добавим.');
  }

  void _cancelSoon() {
    _showInfo('Отмена генерации появится в ближайшем обновлении.');
  }

  void _retrySoon() {
    _showInfo('Попробуйте выбрать фото и запустить генерацию снова.');
    context.go(TemplatesPage.routePath);
  }

  void _shareResult(TemplateGenerationResult generation) {
    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo('Результат пока недоступен для шаринга.');
      return;
    }

    SharePlus.instance.share(ShareParams(text: outputUrl));
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

      if (generation.isUnread) {
        unawaited(
          ref
              .read(generationHistoryControllerProvider.notifier)
              .markRead(generation.generationId),
        );
      }

      if (generation.isTerminal) {
        _pollTimer?.cancel();
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

    final result = await showPetMagicModalBottomSheet<_FeedbackResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context, bottomInset) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const _NegativeFeedbackSheet(),
      ),
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
  const _Header({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.onMenu,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.textStrong,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onMenu != null)
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.more_vert_rounded),
            color: colors.textStrong,
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
          if (!generation.isTerminal)
            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 7,
                        color: _statusColor(colors, generation),
                        backgroundColor: colors.border.withValues(alpha: 0.6),
                      ),
                      Center(
                        child: Text(
                          '$progress%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _etaLabel(generation),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.danger),
              const SizedBox(width: 8),
              Text(
                'Не удалось создать',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _failureReasonMessage(generation),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            generation.refundedAtUtc != null
                ? 'Токены возвращены на ваш баланс.'
                : 'Если ошибка повторится, напишите в поддержку.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
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

class _ReadyActionsRow extends StatelessWidget {
  const _ReadyActionsRow({
    required this.onSave,
    required this.onShare,
    required this.onDelete,
  });

  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(
          icon: Icons.download_rounded,
          label: 'Скачать',
          onTap: onSave,
        ),
        const SizedBox(width: 8),
        _ActionTile(
          icon: Icons.share_rounded,
          label: 'Поделиться',
          onTap: onShare,
        ),
        const SizedBox(width: 8),
        _ActionTile(
          icon: Icons.delete_outline_rounded,
          label: 'Удалить',
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _FailedActions extends StatelessWidget {
  const _FailedActions({
    required this.onPickAnotherPhoto,
    required this.onRetry,
    required this.onSupport,
  });

  final VoidCallback onPickAnotherPhoto;
  final VoidCallback onRetry;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onPickAnotherPhoto,
          child: const Text('Выбрать другое фото'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Попробовать снова')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onSupport,
          child: const Text('Сообщить в поддержку'),
        ),
      ],
    );
  }
}

class _ActiveActions extends StatelessWidget {
  const _ActiveActions({required this.onContinue, required this.onCancel});

  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onContinue,
          child: const Text('Продолжить в приложении'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onCancel,
          child: const Text('Отменить генерацию'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, size: 18, color: colors.textStrong),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w700,
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Детали',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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

String _typeLabel(TemplateGenerationResult generation) {
  return _isVideo(generation) ? 'Видео' : 'Изображение';
}

String _tokensLabel(int value) {
  final last = value % 10;
  final lastTwo = value % 100;
  if (last == 1 && lastTwo != 11) {
    return 'токен';
  }
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return 'токена';
  }
  return 'токенов';
}

String _formatDateTime(DateTime value) {
  const months = <String>[
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]}, $hour:$minute';
}

String _etaLabel(TemplateGenerationResult generation) {
  final estimated = generation.estimatedDurationLabel;
  if (estimated != null && estimated.isNotEmpty) {
    return 'Примерно $estimated осталось';
  }

  if (generation.stage == 'queued') {
    return 'Ожидание в очереди';
  }
  if (generation.stage == 'finalizing') {
    return 'Почти готово';
  }
  return 'Примерно 1-2 мин осталось';
}

String _failureReasonMessage(TemplateGenerationResult generation) {
  final code = (generation.failureCode ?? '').toLowerCase();
  final message = (generation.failureMessage ?? '').toLowerCase();
  final combined = '$code $message';

  if (combined.contains('photo') ||
      combined.contains('face') ||
      combined.contains('pet') ||
      combined.contains('quality')) {
    return 'Фото не подошло для этого шаблона. Попробуйте выбрать фото, где питомец хорошо виден.';
  }

  return 'Произошла техническая ошибка при генерации.';
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
