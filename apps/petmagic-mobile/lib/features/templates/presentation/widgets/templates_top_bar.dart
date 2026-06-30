import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';

class TemplatesTopBarSlot extends ConsumerWidget {
  const TemplatesTopBarSlot({
    super.key,
    required this.onAuthPressed,
    required this.onRewardsPressed,
    required this.onTopUpPressed,
    required this.onWalletPressed,
  });

  final VoidCallback onAuthPressed;
  final VoidCallback onRewardsPressed;
  final VoidCallback onTopUpPressed;
  final VoidCallback onWalletPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenBalance = ref.watch(
      walletControllerProvider.select(
        (walletState) => walletState.wallet?.balance ?? 0,
      ),
    );
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select(
        (launchState) => launchState.isAuthenticated,
      ),
    );

    return _TopBar(
      isAuthenticated: isAuthenticated,
      tokenBalance: tokenBalance,
      onAuthPressed: onAuthPressed,
      onRewardsPressed: onRewardsPressed,
      onTopUpPressed: onTopUpPressed,
      onWalletPressed: onWalletPressed,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isAuthenticated,
    required this.tokenBalance,
    required this.onAuthPressed,
    required this.onRewardsPressed,
    required this.onTopUpPressed,
    required this.onWalletPressed,
  });

  final bool isAuthenticated;
  final int tokenBalance;
  final VoidCallback onAuthPressed;
  final VoidCallback onRewardsPressed;
  final VoidCallback onTopUpPressed;
  final VoidCallback onWalletPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Row(
      children: [
        Icon(Icons.pets_rounded, color: colors.accent, size: 28),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'PetMagic',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.comfortaa(
              color: colors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (!isAuthenticated)
          OutlinedButton.icon(
            onPressed: onAuthPressed,
            icon: const Icon(Icons.login_rounded, size: 17),
            label: Text(text.profileSignInAction),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
            ),
          )
        else ...[
          _GiftButton(tooltip: text.giftTooltip, onPressed: onRewardsPressed),
          const SizedBox(width: 8),
          _TokenBalance(
            balance: tokenBalance,
            addTooltip: text.addTokensTooltip,
            onAddPressed: onTopUpPressed,
            onPressed: onWalletPressed,
          ),
        ],
      ],
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderButton(
            icon: Icons.card_giftcard_rounded,
            color: colors.gold,
            onPressed: onPressed,
          ),
          Positioned(
            top: -4,
            right: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.danger,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenBalance extends StatelessWidget {
  const _TokenBalance({
    required this.balance,
    required this.addTooltip,
    required this.onAddPressed,
    required this.onPressed,
  });

  final int balance;
  final String addTooltip;
  final VoidCallback onAddPressed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderActionSurface(
            onPressed: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PawSparkIcon(size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$balance',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textStrong,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 32, color: colors.border),
          Tooltip(
            message: addTooltip,
            child: _HeaderActionSurface(
              onPressed: onAddPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Icon(
                  Icons.add_rounded,
                  color: colors.textStrong,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return _HeaderActionSurface(
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceGlass,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 18),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _HeaderActionSurface extends StatelessWidget {
  const _HeaderActionSurface({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PetMagicInteractiveSurface(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      scaleDown: 0.97,
      child: child,
    );
  }
}
