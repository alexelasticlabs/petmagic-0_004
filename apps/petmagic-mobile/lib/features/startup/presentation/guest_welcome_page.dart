import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/onboarding_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/widgets/startup_chrome.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

class GuestWelcomePage extends ConsumerWidget {
  const GuestWelcomePage({super.key});

  static const routePath = '/welcome';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final titleStyle = Theme.of(context).textTheme.displaySmall;
    final subtitleStyle = Theme.of(context).textTheme.bodyLarge;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: Stack(
          children: [
            const StartupBackdrop(accentRank: 0),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandHeader(
                      actionLabel: text.startupWelcomeViewOnboarding,
                      onAction: () => context.go(OnboardingPage.routePath),
                    ),
                    const Spacer(),
                    Text(
                      text.startupWelcomeTitle,
                      style: titleStyle?.copyWith(
                        color: colors.textStrong,
                        fontSize: 34,
                        height: 1.02,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      text.startupWelcomeSubtitle,
                      style: subtitleStyle?.copyWith(
                        color: colors.textSoft,
                        fontSize: 14.5,
                        height: 1.34,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surfaceGlass,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: colors.border),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow,
                                blurRadius: 24,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              _FeatureTile(
                                icon: Icons.video_collection_outlined,
                                title: text.startupWelcomeTemplatesTitle,
                                subtitle: text.startupWelcomeTemplatesSubtitle,
                              ),
                              const SizedBox(width: 12),
                              _FeatureTile(
                                icon: Icons.auto_fix_high_rounded,
                                title: text.startupWelcomeAiTitle,
                                subtitle: text.startupWelcomeAiSubtitle,
                              ),
                              const SizedBox(width: 12),
                              _FeatureTile(
                                icon: Icons.favorite_rounded,
                                title: text.startupWelcomeShareTitle,
                                subtitle: text.startupWelcomeShareSubtitle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await ref
                              .read(appLaunchControllerProvider.notifier)
                              .continueAsGuest();
                          if (!context.mounted) {
                            return;
                          }
                          context.go(TemplatesPage.routePath);
                        },
                        child: Text(text.startupWelcomeContinueGuest),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go(AuthEntryPage.routePath),
                        child: Text(text.profileSignInAction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: colors.accent, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textStrong,
              fontSize: 13.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontSize: 11.2,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
