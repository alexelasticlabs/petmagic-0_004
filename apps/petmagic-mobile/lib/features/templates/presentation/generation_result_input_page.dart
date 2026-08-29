import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

part 'generation_result_input_page_chrome.part.dart';

part 'generation_result_input_widgets.part.dart';

class GenerationResultInputPage extends ConsumerStatefulWidget {
  const GenerationResultInputPage({
    required this.generationId,
    this.selectedTemplateId,
    super.key,
  });

  static const routePrefix = '/generation-results';
  static String routeFor(String generationId) =>
      '$routePrefix/${Uri.encodeComponent(generationId)}/use-input';

  final String generationId;
  final String? selectedTemplateId;

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
  RequestCancellation? _cancelToken;
  RequestCancellation? _startCancelToken;
  bool _hasOpenedSelectedTemplate = false;

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
    final cancelToken = RequestCancellation();
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
      _openSelectedTemplateIfNeeded();
    } on RequestCancelledException {
      return;
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

  void _openSelectedTemplateIfNeeded() {
    final selectedTemplateId = widget.selectedTemplateId?.trim();
    if (_hasOpenedSelectedTemplate ||
        selectedTemplateId == null ||
        selectedTemplateId.isEmpty) {
      return;
    }

    CompatibleGenerationTemplate? template;
    for (final candidate
        in _compatible?.templates ?? const <CompatibleGenerationTemplate>[]) {
      if (candidate.id == selectedTemplateId) {
        template = candidate;
        break;
      }
    }
    if (template == null || !mounted) {
      return;
    }

    _hasOpenedSelectedTemplate = true;
    final selectedTemplate = template;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_start(selectedTemplate));
      }
    });
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
                      onPressed: () => context.appNavigator.pop(),
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
      context.appNavigator.push(const WalletDestination());
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
    final startCancelToken = RequestCancellation();
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
      unawaited(
        ref
            .read(walletControllerProvider.notifier)
            .syncSnapshot(forceRefresh: true),
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
      context.appNavigator.go(GenerationDestination(generation.generationId));
    } on RequestCancelledException {
      return;
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
    RequestCancellation? cancelToken,
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
