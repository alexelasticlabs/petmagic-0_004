import 'package:flutter/services.dart';

abstract final class PetMagicHaptics {
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
    } catch (_) {
      // Haptics are optional; keep UI interactions resilient on unsupported devices.
    }
  }
}
