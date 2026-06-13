import 'package:flutter/widgets.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_types.dart';

export 'package:petmagic_mobile/shared/notifications/petmagic_notification_types.dart'
    show PetMagicNotificationAction, PetMagicToastTone;

final class PetMagicToast {
  const PetMagicToast._();

  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    PetMagicToastTone tone = PetMagicToastTone.info,
    Duration duration = const Duration(seconds: 3),
    String? dedupeKey,
    PetMagicNotificationAction? action,
  }) {
    PetMagicNotificationCenter.instance.enqueue(
      message,
      title: title,
      tone: tone,
      duration: duration,
      dedupeKey: dedupeKey,
      action: action,
    );
  }
}
