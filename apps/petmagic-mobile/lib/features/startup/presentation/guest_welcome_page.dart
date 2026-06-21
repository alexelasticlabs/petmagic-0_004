import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/features/startup/presentation/widgets/startup_chrome.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class GuestWelcomePage extends ConsumerStatefulWidget {
  const GuestWelcomePage({super.key});

  static const routePath = '/welcome';

  @override
  ConsumerState<GuestWelcomePage> createState() => _GuestWelcomePageState();
}

class _GuestWelcomePageState extends ConsumerState<GuestWelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _ctaPulseController;
  bool _isGuestSubmitting = false;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..forward();
    _ctaPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _enterController.dispose();
    _ctaPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final preferences = ref.watch(appPreferencesControllerProvider);
    final resolvedLocale =
        preferences.locale ?? Localizations.localeOf(context);
    final viewport = MediaQuery.sizeOf(context);
    final isShortViewport = viewport.height <= 700;
    final isCompactViewport = viewport.height <= 760;
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
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isCompactViewport ? 18 : 20,
                  isCompactViewport ? 10 : 12,
                  isCompactViewport ? 18 : 20,
                  isShortViewport ? 14 : 18,
                ),
                children: [
                  _animatedEntry(
                    start: 0,
                    end: 0.28,
                    offsetY: 0.015,
                    child: BrandHeader(
                      actionLabel: resolvedLocale.languageCode.toUpperCase(),
                      onAction: () =>
                          _openLanguageSheet(selectedLocale: resolvedLocale),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _animatedEntry(
                    start: 0.08,
                    end: 0.46,
                    child: _WelcomeHeroCard(
                      templatesLabel: text.navTemplates,
                      imageLabel: text.imageLabel,
                      videoLabel: text.videoLabel,
                      compact: isCompactViewport,
                    ),
                  ),
                  SizedBox(height: isCompactViewport ? 12 : 16),
                  _animatedEntry(
                    start: 0.2,
                    end: 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.startupWelcomeTitle,
                          style: titleStyle?.copyWith(
                            color: colors.textStrong,
                            fontSize: isCompactViewport ? 27 : 31,
                            height: 1.04,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: isCompactViewport ? 8 : 10),
                        Text(
                          text.startupWelcomeSubtitle,
                          style: subtitleStyle?.copyWith(
                            color: colors.textSoft,
                            fontSize: isCompactViewport ? 12.9 : 13.8,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompactViewport ? 12 : 14),
                  if (isCompactViewport)
                    _animatedEntry(
                      start: 0.3,
                      end: 0.68,
                      child: _WelcomeCtaBlock(
                        animation: _ctaPulseController,
                        isGuestSubmitting: _isGuestSubmitting,
                        signInLabel: text.profileSignInAction,
                        guestLabel: text.startupWelcomeContinueGuest,
                        guestHint: text.startupWelcomeGuestHint,
                        compact: true,
                        onSignIn: () => context.go(AuthEntryPage.routePath),
                        onContinueAsGuest: _continueAsGuest,
                      ),
                    ),
                  if (isCompactViewport)
                    SizedBox(height: isShortViewport ? 10 : 12),
                  _animatedEntry(
                    start: 0.34,
                    end: 0.74,
                    child: _FeatureMiniCard(
                      icon: Icons.style_rounded,
                      iconColor: colors.accent,
                      title: text.startupWelcomeTemplatesTitle,
                      subtitle: text.startupWelcomeTemplatesSubtitle,
                      compact: isCompactViewport,
                    ),
                  ),
                  SizedBox(height: isCompactViewport ? 6 : 8),
                  _animatedEntry(
                    start: 0.42,
                    end: 0.82,
                    child: _FeatureMiniCard(
                      icon: Icons.add_a_photo_outlined,
                      iconColor: colors.blue,
                      title: text.startupWelcomeAiTitle,
                      subtitle: text.startupWelcomeAiSubtitle,
                      compact: isCompactViewport,
                    ),
                  ),
                  SizedBox(height: isCompactViewport ? 6 : 8),
                  _animatedEntry(
                    start: 0.5,
                    end: 0.9,
                    child: _FeatureMiniCard(
                      icon: Icons.movie_creation_outlined,
                      iconColor: colors.gold,
                      title: text.startupWelcomeShareTitle,
                      subtitle: text.startupWelcomeShareSubtitle,
                      compact: isCompactViewport,
                    ),
                  ),
                  if (!isCompactViewport) ...[
                    const SizedBox(height: 14),
                    _animatedEntry(
                      start: 0.58,
                      end: 1,
                      child: _WelcomeCtaBlock(
                        animation: _ctaPulseController,
                        isGuestSubmitting: _isGuestSubmitting,
                        signInLabel: text.profileSignInAction,
                        guestLabel: text.startupWelcomeContinueGuest,
                        guestHint: text.startupWelcomeGuestHint,
                        onSignIn: () => context.go(AuthEntryPage.routePath),
                        onContinueAsGuest: _continueAsGuest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedEntry({
    required Widget child,
    required double start,
    required double end,
    double offsetY = 0.05,
  }) {
    final curve = CurvedAnimation(
      parent: _enterController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, offsetY),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    if (_isGuestSubmitting) {
      return;
    }

    setState(() => _isGuestSubmitting = true);
    try {
      await ref.read(appLaunchControllerProvider.notifier).continueAsGuest();
      if (!mounted) {
        return;
      }
      context.go(TemplatesPage.routePath);
    } catch (error, stackTrace) {
      _handleStartupActionFailure(
        operation: 'continue_as_guest',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() => _isGuestSubmitting = false);
      }
    }
  }

  void _handleStartupActionFailure({
    required String operation,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.warn(
      feature: 'Startup',
      operation: operation,
      message: 'Startup action failed',
      error: error,
      stackTrace: stackTrace,
    );
    if (!mounted) {
      return;
    }
    PetMagicToast.show(
      context,
      message: AppLocalizations.of(context).authRequestFailed,
      tone: PetMagicToastTone.warning,
    );
  }

  Future<void> _openLanguageSheet({required Locale selectedLocale}) async {
    await showProfileLanguageSheet(
      context: context,
      selectedLocale: selectedLocale,
      options: _languageOptions,
      onSelect: (locale) => ref
          .read(appPreferencesControllerProvider.notifier)
          .updateLocale(locale),
    );
  }
}

const _languageOptions = <ProfileLanguageSheetOption>[
  ProfileLanguageSheetOption(locale: Locale('ru'), nativeLabel: 'Русский'),
  ProfileLanguageSheetOption(locale: Locale('en'), nativeLabel: 'English'),
  ProfileLanguageSheetOption(locale: Locale('de'), nativeLabel: 'Deutsch'),
  ProfileLanguageSheetOption(locale: Locale('es'), nativeLabel: 'Español'),
  ProfileLanguageSheetOption(locale: Locale('fr'), nativeLabel: 'Français'),
  ProfileLanguageSheetOption(locale: Locale('it'), nativeLabel: 'Italiano'),
  ProfileLanguageSheetOption(locale: Locale('pl'), nativeLabel: 'Polski'),
];

class _MagicSignInButton extends StatelessWidget {
  const _MagicSignInButton({
    required this.animation,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final Animation<double> animation;
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final pulse = 1 - ((t - 0.5).abs() * 2);
        final shimmerX = -1.2 + (2.4 * t);

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.blue.withValues(
                          alpha: 0.18 + (0.16 * pulse),
                        ),
                        blurRadius: 20 + (8 * pulse),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(label),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.blue,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: Size.fromHeight(compact ? 46 : 48),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(shimmerX - 0.7, -1),
                            end: Alignment(shimmerX + 0.7, 1),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(
                                alpha: 0.16 + (0.08 * pulse),
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.2, 0.5, 0.8],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 12,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: Colors.white.withValues(
                          alpha: 0.65 + (0.2 * pulse),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeHeroCard extends StatelessWidget {
  const _WelcomeHeroCard({
    required this.templatesLabel,
    required this.imageLabel,
    required this.videoLabel,
    this.compact = false,
  });

  final String templatesLabel;
  final String imageLabel;
  final String videoLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final content = Container(
      height: compact ? 150 : 186,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 10 : 12,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        border: Border.all(color: colors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceGlass.withValues(alpha: 0.96),
            colors.surfaceGlass.withValues(alpha: 0.76),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: compact ? -38 : -44,
            right: compact ? -18 : -22,
            child: BlurOrb(
              color: colors.blue.withValues(alpha: 0.18),
              size: compact ? 116 : 140,
            ),
          ),
          Positioned(
            left: compact ? -14 : -20,
            bottom: compact ? -42 : -56,
            child: BlurOrb(
              color: colors.accent.withValues(alpha: 0.2),
              size: compact ? 132 : 170,
            ),
          ),
          Positioned(
            top: compact ? 4 : 6,
            left: compact ? 8 : 10,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.gold.withValues(alpha: 0.72),
              size: compact ? 14 : 16,
            ),
          ),
          Positioned(
            top: compact ? 26 : 34,
            right: compact ? 22 : 28,
            child: Icon(
              Icons.close_rounded,
              color: colors.blue.withValues(alpha: 0.55),
              size: compact ? 12 : 14,
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _HeroPill(
              icon: Icons.auto_awesome_rounded,
              label: 'AI',
              compact: compact,
            ),
          ),
          Align(
            child: Container(
              width: compact ? 132 : 152,
              height: compact ? 84 : 98,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 20 : 24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.backgroundBottom.withValues(alpha: 0.96),
                    colors.surface.withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.2),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    child: Icon(
                      Icons.pets_rounded,
                      color: colors.accent,
                      size: compact ? 34 : 42,
                    ),
                  ),
                  Positioned(
                    right: compact ? 8 : 10,
                    bottom: compact ? 8 : 10,
                    child: Container(
                      width: compact ? 26 : 30,
                      height: compact ? 26 : 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: compact ? 16 : 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              children: [
                Expanded(
                  child: _HeroFlowChip(
                    icon: Icons.style_rounded,
                    label: templatesLabel,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 5 : 6),
                Expanded(
                  child: _HeroFlowChip(
                    icon: Icons.add_photo_alternate_outlined,
                    label: imageLabel,
                    compact: compact,
                  ),
                ),
                SizedBox(width: compact ? 5 : 6),
                Expanded(
                  child: _HeroFlowChip(
                    icon: Icons.movie_creation_outlined,
                    label: videoLabel,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.42),
            blurRadius: compact ? 22 : 28,
            offset: Offset(0, compact ? 12 : 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        child: PerformanceGuard.shouldAvoidBlur(context)
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: content,
              ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.backgroundBottom.withValues(alpha: 0.78),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.gold, size: compact ? 12 : 14),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11.2 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFlowChip extends StatelessWidget {
  const _HeroFlowChip({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        color: colors.backgroundBottom.withValues(alpha: 0.78),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.textSoft, size: compact ? 12 : 14),
          SizedBox(width: compact ? 3 : 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 10.1 : 10.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureMiniCard extends StatelessWidget {
  const _FeatureMiniCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceGlass.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: iconColor, size: compact ? 16 : 18),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    fontSize: compact ? 12.4 : 13.1,
                  ),
                ),
                SizedBox(height: compact ? 1 : 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    height: 1.22,
                    fontSize: compact ? 10.6 : 11.2,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.close_rounded,
            size: compact ? 10 : 12,
            color: colors.blue.withValues(alpha: 0.34),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.22),
            blurRadius: compact ? 12 : 16,
            offset: Offset(0, compact ? 8 : 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        child: PerformanceGuard.shouldAvoidBlur(context)
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: content,
              ),
      ),
    );
  }
}

class _WelcomeCtaBlock extends StatelessWidget {
  const _WelcomeCtaBlock({
    required this.animation,
    required this.isGuestSubmitting,
    required this.signInLabel,
    required this.guestLabel,
    required this.guestHint,
    required this.onSignIn,
    required this.onContinueAsGuest,
    this.compact = false,
  });

  final Animation<double> animation;
  final bool isGuestSubmitting;
  final String signInLabel;
  final String guestLabel;
  final String guestHint;
  final VoidCallback onSignIn;
  final VoidCallback onContinueAsGuest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _MagicSignInButton(
            animation: animation,
            label: signInLabel,
            onPressed: onSignIn,
            compact: compact,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isGuestSubmitting ? null : onContinueAsGuest,
            icon: const Icon(Icons.pets_rounded, size: 18),
            label: Text(guestLabel),
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        SizedBox(
          width: double.infinity,
          child: Text(
            guestHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontSize: compact ? 11.2 : 11.8,
              height: 1.28,
            ),
          ),
        ),
      ],
    );
  }
}
