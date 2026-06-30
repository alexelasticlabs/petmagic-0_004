import 'package:flutter/services.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

abstract final class PetMagicHaptics {
  static bool _loggedUnavailable = false;

  static Future<void> selection() async {
    await _safe(HapticFeedback.selectionClick);
  }

  static Future<void> light() async {
    await _safe(HapticFeedback.lightImpact);
  }

  static Future<void> medium() async {
    await _safe(HapticFeedback.mediumImpact);
  }

  static Future<void> heavy() async {
    await _safe(HapticFeedback.heavyImpact);
  }

  static Future<void> _safe(Future<void> Function() effect) async {
    try {
      await effect();
    } catch (error, stackTrace) {
      if (_loggedUnavailable) {
        return;
      }

      _loggedUnavailable = true;
      AppLogger.warn(
        feature: 'Shared.Haptics',
        operation: 'effect',
        message: 'Haptic feedback unavailable on this device',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
