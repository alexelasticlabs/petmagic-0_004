part of 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';

const int _kPhotoCostSpark = 6;
const int _kVideoCostSpark = 33;

class _RewardsOverviewCard extends StatelessWidget {
  const _RewardsOverviewCard({
    required this.wallet,
    required this.isClaimingAd,
    required this.onClaimAd,
  });

  final WalletStateModel? wallet;
  final bool isClaimingAd;
  final VoidCallback onClaimAd;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final remaining = wallet?.adRewardsRemainingToday ?? 0;
    final isLimitReached = remaining <= 0;

    return _RewardStatusCard(
      icon: Icons.play_circle_outline_rounded,
      title: text.walletAdRewardCompactTitle,
      subtitle: isLimitReached
          ? text.walletAdDailyLimitReached
          : text.walletAdRewardCompactDescription,
      rewardAmount: 15,
      remainingLabel: text.walletAdRewardRemaining(remaining),
      actionLabel: text.walletWatchAdAction,
      onTap: isLimitReached || isClaimingAd ? null : onClaimAd,
      isLoading: isClaimingAd,
    );
  }
}

class _RewardStatusCard extends StatelessWidget {
  const _RewardStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rewardAmount,
    required this.remainingLabel,
    required this.actionLabel,
    required this.onTap,
    required this.isLoading,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int rewardAmount;
  final String remainingLabel;
  final String actionLabel;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final accent = colors.accent;

    return ProfileGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          final badgeIcon = Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accent.withValues(alpha: 0.26)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.surfaceStrong,
                      colors.surfaceStrong.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              Positioned(
                right: -10,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: colors.surfaceStrong,
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    '+$rewardAmount',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );

          final actionButton = OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              backgroundColor: colors.surfaceStrong.withValues(alpha: 0.35),
              disabledBackgroundColor: colors.surfaceStrong,
              foregroundColor: colors.textStrong,
              disabledForegroundColor: colors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: colors.border.withValues(alpha: 0.84)),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onTap,
            icon: Icon(
              isLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.play_arrow_rounded,
              size: 16,
            ),
            label: Text(isLoading ? '...' : actionLabel),
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badgeIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 11.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      actionButton,
                      const SizedBox(height: 4),
                      Text(
                        remainingLabel,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              badgeIcon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remainingLabel,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 146, child: actionButton),
            ],
          );
        },
      ),
    );
  }
}

class _PromoCodeForm extends StatefulWidget {
  const _PromoCodeForm({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final Future<String?> Function(String code) onSubmit;

  @override
  State<_PromoCodeForm> createState() => _PromoCodeFormState();
}

class _PromoCodeFormState extends State<_PromoCodeForm> {
  late final TextEditingController _controller;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    final text = AppLocalizations.of(context);
    if (code.isEmpty) {
      setState(() {
        _isSuccess = false;
        _message = text.walletPromoInputPlaceholder;
      });
      return;
    }

    if (widget.isSubmitting) {
      return;
    }

    setState(() {
      _message = null;
    });

    final error = await widget.onSubmit(code);
    if (!mounted) {
      return;
    }

    setState(() {
      if (error == null) {
        _isSuccess = true;
        _message = text.walletPromoSuccessMessage;
        _controller.clear();
      } else {
        _isSuccess = false;
        _message = _friendlyError(text, error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number_rounded,
                color: colors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.walletPromoTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text.walletPromoSubtitle,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surfaceStrong.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.9),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => unawaited(_submit()),
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: text.walletPromoInputPlaceholder,
                      hintStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: widget.isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.surfaceStrong.withValues(
                      alpha: 0.95,
                    ),
                    disabledForegroundColor: colors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: widget.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 20),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _isSuccess
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: _isSuccess ? colors.accent : colors.gold,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isSuccess ? colors.textStrong : colors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
