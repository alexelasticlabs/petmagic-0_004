import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';

class TemplatePreviewRouteArgs {
  const TemplatePreviewRouteArgs({
    required this.template,
    required this.hasPremiumAccess,
    required this.isAuthenticated,
  });

  final TemplateItem template;
  final bool hasPremiumAccess;
  final bool isAuthenticated;
}

class TemplatePreviewPage extends ConsumerStatefulWidget {
  const TemplatePreviewPage({
    required this.template,
    this.hasPremiumAccess = false,
    this.isAuthenticated = false,
    super.key,
  });

  static const routePath = '/templates/preview';

  final TemplateItem template;
  final bool hasPremiumAccess;
  final bool isAuthenticated;

  @override
  ConsumerState<TemplatePreviewPage> createState() =>
      _TemplatePreviewPageState();
}

class _TemplatePreviewPageState extends ConsumerState<TemplatePreviewPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final livePremiumAccess =
        ref.watch(templatePremiumAccessProvider) || widget.hasPremiumAccess;
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select(
        (state) => state.isAuthenticated || widget.isAuthenticated,
      ),
    );
    final isPremiumLocked = widget.template.isPremium && !livePremiumAccess;
    final colors = context.petMagicColors;

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
          child: TemplateDetailContent(
            template: widget.template,
            scrollController: _scrollController,
            isPremiumLocked: isPremiumLocked,
            onUnlockPremium: isPremiumLocked
                ? () => _handleUnlockPremium(isAuthenticated)
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _handleUnlockPremium(bool isAuthenticated) async {
    if (isAuthenticated) {
      if (!mounted) {
        return;
      }

      context.push(PremiumPage.routePath);
      return;
    }

    await showAuthRequiredSheet(context, redirectPath: PremiumPage.routePath);
  }
}
