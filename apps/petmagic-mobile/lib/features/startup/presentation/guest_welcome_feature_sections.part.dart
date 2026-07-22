part of 'guest_welcome_page.dart';

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
