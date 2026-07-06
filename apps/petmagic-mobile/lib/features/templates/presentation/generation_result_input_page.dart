import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

part 'generation_result_input_page_chrome.part.dart';

class GenerationResultInputPage extends ConsumerStatefulWidget {
  const GenerationResultInputPage({required this.generationId, super.key});

  static const routePrefix = '/generation-results';
  static String routeFor(String generationId) =>
      '$routePrefix/${Uri.encodeComponent(generationId)}/use-input';

  final String generationId;

  @override
  ConsumerState<GenerationResultInputPage> createState() =>
      _GenerationResultInputPageState();
}

enum _ResultTemplateFilter { all, image, video }

const int _parentPreviewCacheWidth = 900;
const int _compatibleTemplateThumbnailCacheWidth = 240;

class _GenerationResultInputPageState
    extends ConsumerState<GenerationResultInputPage> {
  TemplateGenerationResult? _parent;
  CompatibleGenerationTemplates? _compatible;
  _ResultTemplateFilter _filter = _ResultTemplateFilter.all;
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;
  CancelToken? _cancelToken;
  CancelToken? _startCancelToken;

  @override
  void initState() {
    super.initState();
    unawaited(_loadIfOnline());
  }

  @override
  void dispose() {
    _cancelToken?.cancel('generation_result_input_disposed');
    _startCancelToken?.cancel('generation_result_input_start_disposed');
    super.dispose();
  }

  void _cancelActiveWorkForOffline() {
    _cancelToken?.cancel('generation_result_input_offline');
    _cancelToken = null;
    _startCancelToken?.cancel('generation_result_input_start_offline');
    _startCancelToken = null;
    if (_isLoading || _isStarting) {
      setState(() {
        _isLoading = false;
        _isStarting = false;
      });
    }
  }

  Future<void> _load() async {
    _cancelToken?.cancel('generation_result_input_reload');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(templateGenerationRepositoryProvider);
      final results = await Future.wait([
        repository.fetchGeneration(
          widget.generationId,
          cancelToken: cancelToken,
        ),
        repository.fetchCompatibleTemplates(
          widget.generationId,
          cancelToken: cancelToken,
        ),
      ]);
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      setState(() {
        _parent = results[0] as TemplateGenerationResult;
        _compatible = results[1] as CompatibleGenerationTemplates;
        _isLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted || CancelToken.isCancel(error)) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _copy.error;
      });
    } on Object {
      if (!mounted || cancelToken.isCancelled) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _copy.error;
      });
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  Future<void> _loadIfOnline() async {
    if (!mounted) {
      return;
    }
    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      if (_parent == null && _compatible == null && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    await _load();
  }

  _GenerationResultInputCopy get _copy =>
      _GenerationResultInputCopy.forLocale(AppLocalizations.of(context));

  List<CompatibleGenerationTemplate> get _visibleTemplates {
    final templates = _compatible?.templates ?? const [];
    return templates
        .where((template) {
          return switch (_filter) {
            _ResultTemplateFilter.all => true,
            _ResultTemplateFilter.image =>
              template.templateType == TemplateType.image,
            _ResultTemplateFilter.video =>
              template.templateType == TemplateType.video,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final copy = _copy;
    final parent = _parent;
    final visibleTemplates = _visibleTemplates;
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final showOfflineUnavailable =
        parent == null && _compatible == null && !_isLoading && !hasInternet;

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet == next.hasInternet) {
        return;
      }
      if (!next.hasInternet) {
        _cancelActiveWorkForOffline();
        return;
      }
      if (_parent != null && _compatible != null) {
        return;
      }

      unawaited(_loadIfOnline());
    });

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
            onRefresh: () async {
              await PetMagicHaptics.medium();
              await _loadIfOnline();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                petMagicScrollableBottomInset(context),
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: colors.textStrong,
                    ),
                    Expanded(
                      child: Text(
                        copy.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const _ResultInputLoadingCard()
                else if (showOfflineUnavailable)
                  PetMagicUnavailableView(
                    kind: AppUnavailableKind.offline,
                    onRetry: () => unawaited(_loadIfOnline()),
                    padding: EdgeInsets.zero,
                  )
                else if (_error != null)
                  _ResultInputErrorCard(
                    message: _error!,
                    onRetry: _loadIfOnline,
                  )
                else if (parent != null) ...[
                  _ParentPreviewCard(generation: parent, copy: copy),
                  const SizedBox(height: 14),
                  _FilterChips(
                    value: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                    copy: copy,
                  ),
                  const SizedBox(height: 12),
                  if (visibleTemplates.isEmpty)
                    _ResultInputErrorCard(
                      message: copy.empty,
                      onRetry: _loadIfOnline,
                    )
                  else
                    ...visibleTemplates.map(
                      (template) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CompatibleTemplateTile(
                          template: template,
                          isBusy: _isStarting,
                          copy: copy,
                          onTap: () => unawaited(_start(template)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start(CompatibleGenerationTemplate template) async {
    if (_isStarting) {
      return;
    }
    final copy = _copy;
    final wallet = ref.read(walletControllerProvider).wallet;
    if ((wallet?.balance ?? 0) < template.tokenCost) {
      _showInfo(copy.noCredits);
      context.push(WalletPage.routePath);
      return;
    }

    final confirmed = await showPetMagicModalBottomSheet<bool>(
      context: context,
      builder: (context, _) => _ConfirmStartSheet(
        title: template.title,
        cost: template.tokenCost,
        copy: copy,
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    _startCancelToken?.cancel('generation_result_input_start_replaced');
    final startCancelToken = CancelToken();
    _startCancelToken = startCancelToken;
    setState(() => _isStarting = true);
    try {
      final repository = ref.read(templateGenerationRepositoryProvider);
      await _recordEvent(
        template,
        'template_selected',
        cancelToken: startCancelToken,
      );
      if (!mounted || startCancelToken.isCancelled) {
        return;
      }
      final generation = await repository.startGenerationFromResult(
        parentGenerationResultId: widget.generationId,
        templateId: template.id,
        expectedTemplateVersion: template.version,
        cancelToken: startCancelToken,
      );
      if (!mounted || startCancelToken.isCancelled) {
        return;
      }
      await repository.rememberActiveGeneration(
        generationId: generation.generationId,
      );
      if (!mounted || startCancelToken.isCancelled) {
        return;
      }
      await _recordEvent(
        template,
        'generation_started',
        generationId: generation.generationId,
        cancelToken: startCancelToken,
      );
      if (!mounted || startCancelToken.isCancelled) {
        return;
      }
      context.go(GenerationStatusPage.routeFor(generation.generationId));
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || startCancelToken.isCancelled) {
        return;
      }
      if (!mounted) {
        return;
      }
      _showInfo(copy.error);
    } on Object {
      if (!mounted || startCancelToken.isCancelled) {
        return;
      }
      _showInfo(copy.error);
    } finally {
      final isCurrentStart = identical(_startCancelToken, startCancelToken);
      if (isCurrentStart) {
        _startCancelToken = null;
      }
      if (mounted && isCurrentStart) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _recordEvent(
    CompatibleGenerationTemplate template,
    String eventType, {
    String? generationId,
    CancelToken? cancelToken,
  }) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordTemplateAnalyticsEvent(
            templateId: template.id,
            eventType: eventType,
            generationId: generationId ?? widget.generationId,
            cancelToken: cancelToken,
          );
    } on Object {
      // Best-effort analytics must not block generation.
    }
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }
    PetMagicToast.show(context, message: message);
  }
}

class _ParentPreviewCard extends StatelessWidget {
  const _ParentPreviewCard({required this.generation, required this.copy});

  final TemplateGenerationResult generation;
  final _GenerationResultInputCopy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final mediaUrl = parseSafeGenerationMediaUri(generation.outputUrl ?? '');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: mediaUrl == null
                    ? ColoredBox(
                        color: colors.surfaceStrong,
                        child: Center(child: Text(copy.mediaUnavailable)),
                      )
                    : CachedNetworkImage(
                        imageUrl: mediaUrl.toString(),
                        cacheKey: persistentSafeGenerationMediaUrl(
                          mediaUrl.toString(),
                        ),
                        fit: BoxFit.cover,
                        memCacheWidth: _parentPreviewCacheWidth,
                        maxWidthDiskCache: _parentPreviewCacheWidth,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              generation.templateTitle ?? copy.parentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              copy.parentHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSoft,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibleTemplateTile extends StatelessWidget {
  const _CompatibleTemplateTile({
    required this.template,
    required this.isBusy,
    required this.copy,
    required this.onTap,
  });

  final CompatibleGenerationTemplate template;
  final bool isBusy;
  final _GenerationResultInputCopy copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final safeThumb = parseSafeGenerationMediaUri(template.thumbnailUrl ?? '');
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 74,
                  child: safeThumb == null
                      ? ColoredBox(
                          color: colors.surfaceStrong,
                          child: Icon(
                            template.isVideo
                                ? Icons.movie_creation_rounded
                                : Icons.image_rounded,
                            color: colors.textMuted,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: safeThumb.toString(),
                          cacheKey: persistentSafeGenerationMediaUrl(
                            safeThumb.toString(),
                          ),
                          fit: BoxFit.cover,
                          memCacheWidth: _compatibleTemplateThumbnailCacheWidth,
                          maxWidthDiskCache:
                              _compatibleTemplateThumbnailCacheWidth,
                          filterQuality: FilterQuality.medium,
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
                        Icon(
                          template.isVideo
                              ? Icons.play_circle_rounded
                              : Icons.auto_awesome_rounded,
                          size: 16,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            template.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.textStrong,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(
                          label: template.isVideo ? copy.video : copy.image,
                        ),
                        if (template.isRecommended)
                          _MiniBadge(label: copy.recommended),
                        if (template.isPremium)
                          _MiniBadge(label: text.premiumLabel),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${template.tokenCost} ${text.walletBalanceUnit}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultInputErrorCard extends StatelessWidget {
  const _ResultInputErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: TextStyle(color: colors.textSoft)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => unawaited(onRetry()),
              child: Text(text.retryAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationResultInputCopy {
  const _GenerationResultInputCopy({
    required this.title,
    required this.parentTitle,
    required this.parentHint,
    required this.mediaUnavailable,
    required this.all,
    required this.image,
    required this.video,
    required this.recommended,
    required this.empty,
    required this.error,
    required this.noCredits,
    required this.start,
    required this.costBuilder,
  });

  final String title;
  final String parentTitle;
  final String parentHint;
  final String mediaUnavailable;
  final String all;
  final String image;
  final String video;
  final String recommended;
  final String empty;
  final String error;
  final String noCredits;
  final String start;
  final String Function(int credits) costBuilder;

  String cost(int credits) => costBuilder(credits);

  static _GenerationResultInputCopy forLocale(AppLocalizations text) {
    return _GenerationResultInputCopy(
      title: text.generationResultInputTitle,
      parentTitle: text.generationResultInputParentTitle,
      parentHint: text.generationResultInputParentHint,
      mediaUnavailable: text.generationResultInputMediaUnavailable,
      all: text.allFilter,
      image: text.imageLabel,
      video: text.videoLabel,
      recommended: text.generationResultInputRecommendedBadge,
      empty: text.generationResultInputEmpty,
      error: text.generationResultInputError,
      noCredits: text.generationResultInputNoCredits,
      start: text.generationResultInputStartAction,
      costBuilder: text.generationResultInputCostEstimate,
    );
  }
}
