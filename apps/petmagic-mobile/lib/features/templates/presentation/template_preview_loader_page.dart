import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';

class TemplatePreviewLoaderPage extends ConsumerStatefulWidget {
  const TemplatePreviewLoaderPage({required this.templateId, super.key});

  static const routePath = '/templates/preview';

  final String templateId;

  @override
  ConsumerState<TemplatePreviewLoaderPage> createState() =>
      _TemplatePreviewLoaderPageState();
}

class _TemplatePreviewLoaderPageState
    extends ConsumerState<TemplatePreviewLoaderPage> {
  int _requestToken = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void didUpdateWidget(covariant TemplatePreviewLoaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateId != widget.templateId) {
      _loadTemplate();
    }
  }

  @override
  void dispose() {
    _requestToken++;
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    final requestToken = ++_requestToken;
    final templateId = widget.templateId;
    setState(() {
      _error = null;
    });
    try {
      final repository = ref.read(templatesRepositoryProvider);
      final template = await repository.fetchTemplate(
        templateId,
        forceRefresh: true,
        analyticsSource: TemplatePreviewSource.deepLink.analyticsValue,
      );
      if (!mounted || requestToken != _requestToken) {
        return;
      }

      context.appNavigator.go(
        TemplatesDestination(
          category: template.category,
          payload: TemplatePreviewSession.single(
            template,
            source: TemplatePreviewSource.deepLink,
            initialDetailResolved: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted || requestToken != _requestToken) {
        return;
      }
      AppLogger.warn(
        feature: 'Templates.PreviewLoader',
        operation: 'load_template',
        message: 'Could not resolve the template preview deep link.',
        context: {'templateId': templateId},
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = error;
      });
    }
  }

  void _leaveLoader() {
    if (context.appNavigator.canPop()) {
      context.appNavigator.pop();
      return;
    }
    context.appNavigator.go(const TemplatesDestination());
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final canPop = context.appNavigator.canPop();
    return Scaffold(
      body: SafeArea(
        child: _error != null
            ? PetMagicAsyncStateView(
                key: const ValueKey('template-preview-loader-error'),
                icon: Icons.cloud_off_rounded,
                title: text.templatesErrorTitle,
                message: text.templatesRequestFailedError,
                actionLabel: text.retryAction,
                onAction: _loadTemplate,
                footer: TextButton.icon(
                  key: const ValueKey('template-preview-loader-exit'),
                  onPressed: _leaveLoader,
                  icon: Icon(
                    canPop ? Icons.arrow_back_rounded : Icons.grid_view_rounded,
                  ),
                  label: Text(
                    canPop
                        ? MaterialLocalizations.of(context).backButtonTooltip
                        : text.createHubBrowseAction,
                  ),
                ),
              )
            : Center(
                child: Semantics(
                  label: text.templateFlowLoadingPreview,
                  child: const CircularProgressIndicator(
                    key: ValueKey('template-preview-loader-loading'),
                  ),
                ),
              ),
      ),
    );
  }
}
