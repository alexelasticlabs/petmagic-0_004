part of 'premium_page.dart';

class _PremiumBody extends StatelessWidget {
  const _PremiumBody({
    super.key,
    required this.state,
    required this.controller,
    required this.isDark,
    required this.onOpenUrl,
    required this.onStartCheckout,
    required this.onClose,
  });

  final PremiumState state;
  final PremiumController controller;
  final bool isDark;
  final Future<void> Function(String) onOpenUrl;
  final Future<void> Function() onStartCheckout;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        _Header(
          state: state,
          controller: controller,
          isDark: isDark,
          onClose: onClose,
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FadeSlideIn(delayMs: 40, child: _HeroBlock(isDark: isDark)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FadeSlideIn(
                  delayMs: 120,
                  child: _ComparisonCard(isDark: isDark),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FadeSlideIn(
                  delayMs: 190,
                  child: _PlansSection(
                    state: state,
                    controller: controller,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _FadeSlideIn(
                delayMs: 250,
                child: _BenefitsSection(isDark: isDark),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FadeSlideIn(
                  delayMs: 320,
                  child: _CtaButton(
                    state: state,
                    isDark: isDark,
                    onStartCheckout: onStartCheckout,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _FadeSlideIn(
                  delayMs: 380,
                  child: _Footer(
                    isDark: isDark,
                    state: state,
                    controller: controller,
                  ),
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
