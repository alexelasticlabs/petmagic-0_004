import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/features/startup/presentation/widgets/startup_chrome.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  static const routePath = '/onboarding';

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;
  int _pageIndex = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final pages = [
      _OnboardingContent(
        icon: Icons.auto_awesome_rounded,
        accentRank: 0,
        title: text.startupOnboardingPageOneTitle,
        subtitle: text.startupOnboardingPageOneSubtitle,
        highlights: [
          text.startupOnboardingPageOneHighlightOne,
          text.startupOnboardingPageOneHighlightTwo,
          text.startupOnboardingPageOneHighlightThree,
        ],
      ),
      _OnboardingContent(
        icon: Icons.movie_creation_outlined,
        accentRank: 1,
        title: text.startupOnboardingPageTwoTitle,
        subtitle: text.startupOnboardingPageTwoSubtitle,
        highlights: [
          text.startupOnboardingPageTwoHighlightOne,
          text.startupOnboardingPageTwoHighlightTwo,
          text.startupOnboardingPageTwoHighlightThree,
        ],
      ),
      _OnboardingContent(
        icon: Icons.stars_rounded,
        accentRank: 2,
        title: text.startupOnboardingPageThreeTitle,
        subtitle: text.startupOnboardingPageThreeSubtitle,
        highlights: [
          text.startupOnboardingPageThreeHighlightOne,
          text.startupOnboardingPageThreeHighlightTwo,
          text.startupOnboardingPageThreeHighlightThree,
        ],
      ),
    ];
    final isLastPage = _pageIndex == pages.length - 1;

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
            StartupBackdrop(accentRank: _pageIndex),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandHeader(
                      actionLabel: text.profileSignInAction,
                      onAction: _openSignIn,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: pages.length,
                        onPageChanged: (value) {
                          setState(() => _pageIndex = value);
                        },
                        itemBuilder: (context, index) {
                          return _OnboardingHero(
                            content: pages[index],
                            fastStartLabel: text.startupMiniFeatureFastStart,
                            petFirstLabel: text.startupMiniFeaturePetFirst,
                            upgradeLaterLabel:
                                text.startupMiniFeatureUpgradeLater,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _OnboardingFooter(
                      pageIndex: _pageIndex,
                      pageCount: pages.length,
                      primaryLabel: isLastPage
                          ? text.startupOnboardingActionStart
                          : text.startupOnboardingActionNext,
                      secondaryLabel: text.startupOnboardingActionContinueGuest,
                      isBusy: _isSubmitting,
                      onPrimaryPressed: () async {
                        if (_isSubmitting) {
                          return;
                        }

                        if (!isLastPage) {
                          await _pageController.nextPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                          return;
                        }

                        setState(() => _isSubmitting = true);
                        await ref
                            .read(appLaunchControllerProvider.notifier)
                            .continueAsGuest();
                        if (!context.mounted) {
                          return;
                        }
                        context.go(TemplatesPage.routePath);
                      },
                      onSecondaryPressed: () async {
                        if (_isSubmitting) {
                          return;
                        }
                        setState(() => _isSubmitting = true);
                        await ref
                            .read(appLaunchControllerProvider.notifier)
                            .continueAsGuest();
                        if (!context.mounted) {
                          return;
                        }
                        context.go(TemplatesPage.routePath);
                      },
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

  Future<void> _openSignIn() async {
    if (_isSubmitting) {
      return;
    }

    final router = GoRouter.of(context);
    setState(() => _isSubmitting = true);
    await ref.read(appLaunchControllerProvider.notifier).markOnboardingSeen();
    if (!context.mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    router.go(AuthEntryPage.routePath);
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.icon,
    required this.accentRank,
    required this.title,
    required this.subtitle,
    required this.highlights,
  });

  final IconData icon;
  final int accentRank;
  final String title;
  final String subtitle;
  final List<String> highlights;
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({
    required this.content,
    required this.fastStartLabel,
    required this.petFirstLabel,
    required this.upgradeLaterLabel,
  });

  final _OnboardingContent content;
  final String fastStartLabel;
  final String petFirstLabel;
  final String upgradeLaterLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.displaySmall;
    final subtitleStyle = Theme.of(context).textTheme.bodyLarge;
    final accent = switch (content.accentRank % 3) {
      0 => colors.accent,
      1 => colors.blue,
      _ => colors.gold,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.24),
                          accent.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.52, 1],
                      ),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 156,
                        height: 156,
                        decoration: BoxDecoration(
                          color: colors.surfaceGlass,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.16),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Icon(content.icon, color: accent, size: 74),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  content.title,
                  style: titleStyle?.copyWith(
                    color: colors.textStrong,
                    fontSize: 31,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  content.subtitle,
                  style: subtitleStyle?.copyWith(
                    color: colors.textSoft,
                    fontSize: 14.5,
                    height: 1.34,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final highlight in content.highlights)
                      _HighlightChip(label: highlight, accent: accent),
                  ],
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surfaceGlass,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          _MiniFeature(
                            icon: Icons.rocket_launch_outlined,
                            label: fastStartLabel,
                            accent: accent,
                          ),
                          const SizedBox(width: 12),
                          _MiniFeature(
                            icon: Icons.favorite_outline_rounded,
                            label: petFirstLabel,
                            accent: colors.purple,
                          ),
                          const SizedBox(width: 12),
                          _MiniFeature(
                            icon: null,
                            leading: const PremiumCrownIcon(size: 22),
                            label: upgradeLaterLabel,
                            accent: colors.gold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.pageIndex,
    required this.pageCount,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.isBusy,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final int pageIndex;
  final int pageCount;
  final String primaryLabel;
  final String secondaryLabel;
  final bool isBusy;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < pageCount; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: index == pageIndex ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == pageIndex
                            ? colors.accent
                            : colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onPrimaryPressed,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(primaryLabel),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isBusy ? null : onSecondaryPressed,
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({
    this.icon,
    this.leading,
    required this.label,
    required this.accent,
  });

  final IconData? icon;
  final Widget? leading;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Expanded(
      child: Column(
        children: [
          leading ?? Icon(icon, color: accent, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
