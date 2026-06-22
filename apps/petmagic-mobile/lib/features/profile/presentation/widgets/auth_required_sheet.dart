import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

Future<void> showAuthRequiredSheet(
  BuildContext context, {
  String? redirectPath,
  String? title,
  String? message,
  bool showSignUp = false,
}) {
  final text = AppLocalizations.of(context);
  final colors = context.petMagicColors;
  final router = GoRouter.of(context);

  return showPetMagicModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext, bottomInset) {
      final content = DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceGlass,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_open_rounded,
                  color: colors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title ?? text.authRequiredTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message ?? text.authRequiredMessage,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    final redirectQuery =
                        redirectPath != null &&
                            redirectPath.isNotEmpty &&
                            redirectPath.startsWith('/')
                        ? '?redirect=${Uri.encodeQueryComponent(redirectPath)}'
                        : '';
                    router.go('${AuthEntryPage.routePath}$redirectQuery');
                  },
                  child: Text(text.profileSignInAction),
                ),
              ),
              if (showSignUp) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      router.go(RegisterEntryPage.routePath);
                    },
                    child: Text(text.authSignUpAction),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(text.authRequiredContinueBrowsing),
                ),
              ),
            ],
          ),
        ),
      );

      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: PerformanceGuard.shouldAvoidBlur(context)
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: content,
                ),
        ),
      );
    },
  );
}
