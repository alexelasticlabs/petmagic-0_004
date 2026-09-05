import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_state_illustration.dart';

Future<void> showAuthRequiredSheet(
  BuildContext context, {
  String? redirectPath,
  String? title,
  String? message,
  bool showSignUp = false,
}) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  final navigator = context.appNavigator;
  final normalizedRedirectPath = normalizeAuthRedirectPath(redirectPath);

  return showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext, bottomInset) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.border),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                20 + MediaQuery.viewPaddingOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: PetMagicStateIllustration(
                      icon: Icons.pets_rounded,
                      size: 88,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title ?? text.authRequiredTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message ?? text.authRequiredMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(color: colors.textSoft, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      navigator.go(
                        AuthDestination(redirectPath: normalizedRedirectPath),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 19),
                    label: Text(text.profileSignInAction),
                  ),
                  if (showSignUp) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        navigator.go(
                          RegisterDestination(
                            redirectPath: normalizedRedirectPath,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(text.authSignUpAction),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accentInk,
                    ),
                    child: Text(text.authRequiredContinueBrowsing),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
