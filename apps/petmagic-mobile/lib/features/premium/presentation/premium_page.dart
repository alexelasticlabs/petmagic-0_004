import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:petmagic_mobile/features/premium/data/premium_models.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';

// ─── Color constants ────────────────────────────────────────────────────────
const _kDarkBg = Color(0xFF090A10);
const _kDarkSurface = Color(0xFF13141F);
const _kDarkText = Colors.white;
const _kDarkSubtitle = Color(0xFFD7D8E3);
const _kDarkAccent = Color(0xFFF7CD5A);
const _kDarkBorder = Color(0xFF232431);
const _kDarkFreeBg = Color(0xFF0F1019);

const _kLightBg = Color(0xFFF6F7FB);
const _kLightSurface = Color(0xFFFFFFFF);
const _kLightText = Color(0xFF171723);
const _kLightSubtitle = Color(0xFF595C70);
const _kLightAccent = Color(0xFF7C4DFF);
const _kLightBorder = Color(0xFFEBEDF5);
const _kLightFreeBg = Color(0xFFF0F1F7);

class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key});

  static const routePath = '/profile/premium';

  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage>
    with WidgetsBindingObserver {
  bool _shouldReloadOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(premiumControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && _shouldReloadOnResume) {
      _shouldReloadOnResume = false;
      final controller = ref.read(premiumControllerProvider.notifier);
      if (ref.read(premiumControllerProvider).isAwaitingCheckoutVerification) {
        unawaited(controller.verifyCheckoutStatus());
        return;
      }
      controller.load(refresh: true);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumControllerProvider);
    final controller = ref.read(premiumControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? _kDarkBg : _kLightBg;
    final accent = isDark ? _kDarkAccent : _kLightAccent;

    ref.listen(premiumControllerProvider, (previous, next) {
      final externalUrl = next.externalUrl;
      if (externalUrl == null || externalUrl.isEmpty) return;

      final openedForCheckout = previous?.isBuying == true &&
          next.selectedProvider == PremiumPaymentProvider.stripe;

      if (openedForCheckout) {
        controller.markCheckoutOpened(
          wasPremiumBeforeCheckout: previous?.isPremium ?? false,
        );
      }

      controller.consumeExternalUrl();
      _openExternalUrl(externalUrl);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: state.isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : _PremiumBody(
                state: state,
                controller: controller,
                isDark: isDark,
                onOpenUrl: _openExternalUrl,
              ),
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────
class _PremiumBody extends StatelessWidget {
  const _PremiumBody({
    required this.state,
    required this.controller,
    required this.isDark,
    required this.onOpenUrl,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;
  final Future<void> Function(String) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        _Header(state: state, controller: controller, isDark: isDark),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroBlock(isDark: isDark),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ComparisonCard(isDark: isDark),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PlansSection(
                  state: state,
                  controller: controller,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 24),
              _BenefitsSection(isDark: isDark),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CtaButton(
                  state: state,
                  controller: controller,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Footer(
                  isDark: isDark,
                  state: state,
                  controller: controller,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.controller,
    required this.isDark,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? _kDarkText : _kLightText;
    final accent = isDark ? _kDarkAccent : _kLightAccent;

    return SliverSafeArea(
      bottom: false,
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.close_rounded, color: textColor, size: 16),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: state.isRestoring ? null : controller.restorePurchases,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: state.isRestoring
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: accent,
                          ),
                        )
                      : Icon(Icons.refresh_rounded, size: 14, color: accent),
                  label: Text(
                    'Restore purchases',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero block ──────────────────────────────────────────────────────────────
class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final assetName = isDark
        ? 'assets/branding/premium-hero-dark.png'
        : 'assets/branding/premium-hero-light.png';

    // Height of the hero: ~220–240 px regardless of screen.
    const heroHeight = 220.0;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Decorative glow behind dog ──
          if (isDark)
            Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              width: 260,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.centerRight,
                    radius: 0.9,
                    colors: [
                      const Color(0xFF4A1FBF).withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // ── Dog image — right side only, fits height ──
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: heroHeight * 0.88, // keep aspect ~square
            child: Image.asset(
              assetName,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),

          // ── Text — left side ──
          Positioned(
            left: 16,
            top: 12,
            right: heroHeight * 0.88 - 8, // don't overlap dog
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: textColor,
                    ),
                    children: [
                      const TextSpan(text: 'Make\nyour pet\n'),
                      TextSpan(
                        text: 'go viral',
                        style: TextStyle(color: accent),
                      ),
                      TextSpan(
                        text: ' ✦',
                        style: TextStyle(
                          color: accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Monthly generations, premium templates, priority queue & no watermark.',
                  style: TextStyle(
                    fontSize: 13,
                    color: sub,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comparison Card ─────────────────────────────────────────────────────────
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final freeBg = isDark ? _kDarkFreeBg : _kLightFreeBg;
    final surface = isDark ? _kDarkSurface : _kLightSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        color: surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: IntrinsicHeight(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Free column
                  Expanded(
                    child: Container(
                      color: freeBg,
                      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Free',
                              style: TextStyle(
                                color: sub,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _cmpRow(false, 'Limited templates', isDark, sub),
                          _cmpRow(false, 'Standard queue', isDark, sub),
                          _cmpRow(false, 'Watermark on videos', isDark, sub),
                          _cmpRow(false, 'Lower rewards', isDark, sub),
                        ],
                      ),
                    ),
                  ),
                  // Premium column
                  Expanded(
                    child: Container(
                      color: surface,
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Premium',
                              style: TextStyle(
                                color: accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _cmpRow(true, 'Premium templates', isDark, textColor, accent: accent),
                          _cmpRow(true, 'Priority queue', isDark, textColor, accent: accent),
                          _cmpRow(true, 'No watermark', isDark, textColor, accent: accent),
                          _cmpRow(true, 'Bigger rewards', isDark, textColor, accent: accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Divider
              Container(width: 1, color: border),
              // VS bubble
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1D1F2D) : const Color(0xFFE6E8F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: isDark ? Colors.white : _kLightText,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cmpRow(bool premium, String label, bool isDark, Color textColor, {Color? accent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            premium ? Icons.check_circle_rounded : Icons.close_rounded,
            size: 15,
            color: premium ? accent : (isDark ? const Color(0xFF3A3B4E) : const Color(0xFFBEC0D0)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plans Section ────────────────────────────────────────────────────────────
class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.state,
    required this.controller,
    required this.isDark,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? _kDarkText : _kLightText;

    if (state.plans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            'Choose your plan',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...state.plans.map((plan) => _PlanCard(
              plan: plan,
              isSelected: state.selectedPlanCode == plan.planCode,
              isDark: isDark,
              onTap: () => controller.selectPlan(plan.planCode),
            )),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final PremiumPlanModel plan;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? _kDarkAccent : _kLightAccent;
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final surface = isDark ? _kDarkSurface : _kLightSurface;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    final isYearly = plan.billingInterval.toLowerCase().contains('year') ||
        plan.planCode.toLowerCase().contains('annual');
    final title = isYearly ? 'Premium Yearly' : 'Premium Monthly';
    final priceStr = '\$${plan.priceAmount.toStringAsFixed(2)}';
    final interval = isYearly ? '/ year' : '/ month';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.05) : surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? accent : (isDark ? const Color(0xFF3A3B4E) : const Color(0xFFBEC0D0)),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isYearly ? 'Cancel anytime.' : 'Flexible. Cancel anytime.',
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                          if (isYearly) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'SAVE 33%',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          priceStr,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          interval,
                          style: TextStyle(color: sub, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // BEST VALUE badge — top right corner
              if (isYearly)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : accent.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: Text(
                      'BEST VALUE',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF13141F) : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Benefits Section ─────────────────────────────────────────────────────────
class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({required this.isDark});

  final bool isDark;

  static const _items = [
    _BenefitItem(icon: Icons.flash_on_rounded, title: '30 AI\ngenerations', sub: 'every month', color: Color(0xFF6B4BFF)),
    _BenefitItem(icon: Icons.photo_library_rounded, title: 'Premium\ntemplates', sub: 'exclusive', color: Color(0xFFFF9F43)),
    _BenefitItem(icon: Icons.rocket_launch_rounded, title: 'Priority\nvideo queue', sub: 'faster results', color: Color(0xFFFF6B9D)),
    _BenefitItem(icon: Icons.verified_user_rounded, title: 'No\nwatermark', sub: 'clean exports', color: Color(0xFF4CA1AF)),
    _BenefitItem(icon: Icons.diamond_rounded, title: 'Bigger\nrewards', sub: 'daily bonuses', color: Color(0xFFFFD700)),
  ];

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? _kDarkText : _kLightText;
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final surface = isDark ? _kDarkSurface : _kLightSurface;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              'What you get',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: const [0.0, 0.04, 0.93, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, i) {
                final item = _items[i];
                return Container(
                  width: 110,
                  margin: EdgeInsets.only(right: i < _items.length - 1 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.color.withValues(alpha: 0.15),
                        ),
                        child: Icon(item.icon, color: item.color, size: 26),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.sub,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sub,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitItem {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String sub;
  final Color color;
}

// ─── CTA Button ───────────────────────────────────────────────────────────────
class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.state,
    required this.controller,
    required this.isDark,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final btnTextColor = isDark ? const Color(0xFF13141F) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isDark
            ? const LinearGradient(colors: [Color(0xFFFFE07C), Color(0xFFFFB300)])
            : const LinearGradient(colors: [Color(0xFF9D6FFF), Color(0xFF6D28D9)]),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFFFFB300) : const Color(0xFF7C4DFF)).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: state.isBuying ? null : controller.startCheckout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: btnTextColor,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: state.isBuying
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: btnTextColor, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: btnTextColor, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Start Premium',
                    style: TextStyle(
                      color: btnTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({
    required this.isDark,
    required this.state,
    required this.controller,
  });

  final bool isDark;
  final PremiumState state;
  final PremiumController controller;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? _kDarkSubtitle : _kLightSubtitle;
    final accent = isDark ? const Color(0xFFAA8FFF) : _kLightAccent;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: sub),
            const SizedBox(width: 5),
            Text(
              'Secure payment via App Store / Google Play',
              style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Payment will be charged to your App Store / Google Play account. '
          'Subscription renews automatically unless cancelled before the renewal date.',
          textAlign: TextAlign.center,
          style: TextStyle(color: sub.withValues(alpha: 0.7), fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 8,
          children: [
            _Link(text: 'Restore purchases', accent: accent, onTap: state.isRestoring ? null : controller.restorePurchases),
            Text(' • ', style: TextStyle(color: sub, fontSize: 11)),
            _Link(text: 'Terms of Use', accent: accent, url: 'https://petmagic.app/terms'),
            Text(' • ', style: TextStyle(color: sub, fontSize: 11)),
            _Link(text: 'Privacy Policy', accent: accent, url: 'https://petmagic.app/privacy'),
          ],
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.text, required this.accent, this.url, this.onTap});

  final String text;
  final Color accent;
  final String? url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (url != null ? () => launchUrl(Uri.parse(url!)) : null),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: accent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
