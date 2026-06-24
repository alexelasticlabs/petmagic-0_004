import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

class TemplatePreviewLoaderPage extends ConsumerStatefulWidget {
  const TemplatePreviewLoaderPage({
    required this.templateId,
    super.key,
  });

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
      final template = await repository.fetchTemplate(widget.templateId);
      if (!mounted) return;

      context.pushReplacement(
        '${TemplatePreviewPage.routePath}/${widget.templateId}',
        extra: TemplatePreviewRouteArgs(
          template: template,
          hasPremiumAccess: false,
          isAuthenticated: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.go(TemplatesPage.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
