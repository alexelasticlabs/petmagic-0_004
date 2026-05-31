import 'package:flutter/material.dart';

enum PetMagicToastTone { success, warning, info }

final class PetMagicToast {
  const PetMagicToast._();
  static const Duration _dedupeWindow = Duration(milliseconds: 2500);
  static String? _lastMessage;
  static PetMagicToastTone? _lastTone;
  static DateTime? _lastShownAt;

  static void show(
    BuildContext context, {
    required String message,
    PetMagicToastTone tone = PetMagicToastTone.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final now = DateTime.now();
    final wasRecentlyShown =
        _lastMessage == message &&
        _lastTone == tone &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) <= _dedupeWindow;
    if (wasRecentlyShown) {
      return;
    }

    _lastMessage = message;
    _lastTone = tone;
    _lastShownAt = now;

    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = switch (tone) {
      PetMagicToastTone.success => isLight
          ? const Color(0xFF0F9D6B)
          : const Color(0xFF0C8A5D),
      PetMagicToastTone.warning => isLight
          ? const Color(0xFFCC4258)
          : const Color(0xFFB9394D),
      PetMagicToastTone.info => isLight
          ? const Color(0xFF2E6FCF)
          : const Color(0xFF275FB2),
    };
    final icon = switch (tone) {
      PetMagicToastTone.success => Icons.check_circle_rounded,
      PetMagicToastTone.warning => Icons.error_rounded,
      PetMagicToastTone.info => Icons.info_rounded,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          elevation: 0,
          margin: EdgeInsets.fromLTRB(
            14,
            0,
            14,
            MediaQuery.viewPaddingOf(context).bottom + 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: duration,
          content: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.96)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
