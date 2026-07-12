import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

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
  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    try {
      final repository = ref.read(templatesRepositoryProvider);
      final template = await repository.fetchTemplate(
        widget.templateId,
        forceRefresh: true,
      );
      if (!mounted) return;

      context.appNavigator.replace(
        TemplatePreviewDestination(
          templateId: widget.templateId,
          payload: TemplatePreviewRouteArgs(
            template: template,
            hasPremiumAccess: false,
            isAuthenticated: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.appNavigator.go(const TemplatesDestination());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
