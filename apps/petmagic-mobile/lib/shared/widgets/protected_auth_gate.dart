import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';

class ProtectedAuthGate extends StatelessWidget {
  const ProtectedAuthGate({
    required this.subtitle,
    required this.onSignIn,
    this.title,
    this.onSignUp,
    super.key,
  });

  final String? title;
  final String subtitle;
  final VoidCallback onSignIn;
  final VoidCallback? onSignUp;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return PetMagicAsyncStateView(
      icon: Icons.pets_rounded,
      title: title ?? text.authRequiredTitle,
      message: subtitle,
      actionLabel: text.profileSignInAction,
      actionIcon: Icons.login_rounded,
      onAction: onSignIn,
      footer: onSignUp == null
          ? null
          : OutlinedButton(
              onPressed: onSignUp,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(text.authSignUpAction),
            ),
    );
  }
}
