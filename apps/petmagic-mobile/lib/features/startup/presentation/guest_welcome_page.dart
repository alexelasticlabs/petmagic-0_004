import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/settings/app_settings_bottom_sheets.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/features/startup/presentation/widgets/startup_chrome.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

part 'guest_welcome_content.part.dart';
part 'guest_welcome_feature_sections.part.dart';

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
    );
    _ctaPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _enterController.stop();
    _ctaPulseController.stop();
    _enterController.dispose();
    _ctaPulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
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
                            fontSize: isCompactViewport ? 13 : 14,
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
                        onSignIn: () =>
                            context.appNavigator.go(const AuthDestination()),
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
                        onSignIn: () =>
                            context.appNavigator.go(const AuthDestination()),
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
    if (PerformanceGuard.shouldDisableDecorativeAnimations(context)) {
      return child;
    }

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
      context.appNavigator.go(const TemplatesDestination());
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
      options: profileLanguageSheetOptions,
      onSelect: (locale) => ref
          .read(appPreferencesControllerProvider.notifier)
          .updateLocale(locale),
    );
  }

  void _syncAnimationState() {
    final disableAnimations =
        PerformanceGuard.shouldDisableDecorativeAnimations(context);

    if (disableAnimations) {
      if (_enterController.value != 1) {
        _enterController.value = 1;
      }
      if (_ctaPulseController.isAnimating) {
        _ctaPulseController.stop();
      }
      return;
    }

    if (!_enterController.isAnimating && _enterController.value < 1) {
      _enterController.forward();
    }
    if (!_ctaPulseController.isAnimating) {
      _ctaPulseController.repeat(reverse: true);
    }
  }
}
