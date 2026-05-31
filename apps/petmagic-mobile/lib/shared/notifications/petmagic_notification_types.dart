import 'dart:async';

import 'package:flutter/material.dart';

enum PetMagicToastTone { success, warning, info }

@immutable
final class PetMagicNotificationAction {
  const PetMagicNotificationAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final FutureOr<void> Function() onPressed;
}

@immutable
final class PetMagicNotification {
  const PetMagicNotification({
    required this.id,
    required this.message,
    required this.tone,
    required this.createdAt,
    this.title,
    this.duration = const Duration(seconds: 3),
    this.action,
    this.dedupeKey,
  });

  final String id;
  final String? title;
  final String message;
  final PetMagicToastTone tone;
  final Duration duration;
  final PetMagicNotificationAction? action;
  final String? dedupeKey;
  final DateTime createdAt;

  String get signature {
    final titlePart = title?.trim() ?? '';
    final messagePart = message.trim();
    final dedupePart = dedupeKey?.trim();
    return dedupePart != null && dedupePart.isNotEmpty
        ? dedupePart
        : '${tone.name}|$titlePart|$messagePart';
  }
}
