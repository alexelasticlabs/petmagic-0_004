import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_design_components.dart';

class CreateHubPage extends ConsumerStatefulWidget {
  const CreateHubPage({this.initialSource, super.key});

  static const routePath = '/create';
  static const sourceQueryParameter = 'source';
  static const petsSource = 'pets';

  final String? initialSource;

  @override
  ConsumerState<CreateHubPage> createState() => _CreateHubPageState();
}

class _CreateHubPageState extends ConsumerState<CreateHubPage> {
  bool _handledInitialSource = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialSource ||
        widget.initialSource != CreateHubPage.petsSource) {
      return;
    }
    _handledInitialSource = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPets();
    });
  }

  void _openTemplates() {
    context.appNavigator.go(const TemplatesDestination());
  }

  void _openPets() {
    final authenticated = ref.read(appLaunchControllerProvider).isAuthenticated;
    if (authenticated) {
      context.appNavigator.push(const PetsDestination());
      return;
    }
    context.appNavigator.go(
      const AuthDestination(redirectPath: '/create?source=pets'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final authenticated = ref.watch(
      appLaunchControllerProvider.select((state) => state.isAuthenticated),
    );

    return PetMagicPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PetMagicHeroCard(
            eyebrow: text.navCreate,
            title: text.createHubTitle,
            subtitle: text.createHubSubtitle,
            imageAsset: 'assets/auth/petmagic-auth-hero.png',
          ),
          const SizedBox(height: PetMagicSpacing.xl),
          PetMagicActionCard(
            icon: Icons.auto_awesome_rounded,
            title: text.createHubBrowseAction,
            subtitle: text.startupWelcomeTemplatesSubtitle,
            onPressed: _openTemplates,
          ),
          const SizedBox(height: PetMagicSpacing.sm),
          PetMagicActionCard(
            icon: Icons.pets_rounded,
            title: text.createHubPetsAction,
            subtitle: text.petsActionSheetMyPetsSubtitle,
            accentColor: colors.purple,
            onPressed: _openPets,
          ),
          const SizedBox(height: PetMagicSpacing.xl),
          PetMagicFlowSteps(
            labels: [
              text.startupWelcomeTemplatesTitle,
              text.startupWelcomeAiTitle,
              text.templateFlowCreateMagicAction,
            ],
          ),
          if (!authenticated) ...[
            const SizedBox(height: PetMagicSpacing.lg),
            Semantics(
              liveRegion: false,
              child: Container(
                padding: const EdgeInsets.all(PetMagicSpacing.md),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(PetMagicRadii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_open_rounded, color: colors.accent),
                    const SizedBox(width: PetMagicSpacing.sm),
                    Expanded(
                      child: Text(
                        text.createHubGuestHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
