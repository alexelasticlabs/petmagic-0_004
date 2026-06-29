import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

final appPermissionCoordinatorProvider = Provider<AppPermissionCoordinator>((
  ref,
) {
  return AppPermissionCoordinator();
});

final mediaPermissionFeedbackCoordinatorProvider =
    Provider<MediaPermissionFeedbackCoordinator>((ref) {
      return MediaPermissionFeedbackCoordinator(
        ref.read(appPermissionCoordinatorProvider),
      );
    });

enum MediaPermissionFlow {
  galleryPhoto,
  mediaLibrary,
  cameraPhoto,
  cameraVideo,
  microphoneVideo,
}

class MediaPermissionFeedback {
  const MediaPermissionFeedback({
    required this.granted,
    required this.dedupeKey,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final bool granted;
  final String dedupeKey;
  final String? title;
  final String? message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
}

class MediaPermissionFeedbackCoordinator {
  const MediaPermissionFeedbackCoordinator(this._permissionCoordinator);

  final AppPermissionCoordinator _permissionCoordinator;

  Future<MediaPermissionFeedback> request(
    BuildContext context,
    MediaPermissionFlow flow,
  ) {
    return requestWithText(
      AppLocalizations.of(context),
      permission: _requiredPermission(flow),
      flow: flow,
    );
  }

  Future<MediaPermissionFeedback> requestPermission(
    BuildContext context, {
    required AppPermissionType permission,
    required MediaPermissionFlow flow,
  }) {
    return requestWithText(
      AppLocalizations.of(context),
      permission: permission,
      flow: flow,
    );
  }

  Future<MediaPermissionFeedback> requestWithText(
    AppLocalizations text, {
    required AppPermissionType permission,
    required MediaPermissionFlow flow,
  }) async {
    try {
      final status = await _permissionCoordinator.requestOnDemand(permission);
      return mapStatusFromText(text, flow: flow, status: status);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Permissions.Media',
        operation: 'request',
        message: 'Media permission request failed.',
        context: <String, Object?>{
          'flow': flow.name,
          'permission': permission.name,
        },
        error: error,
        stackTrace: stackTrace,
      );
      return fallbackFromText(text, flow: flow);
    }
  }

  MediaPermissionFeedback mapStatus(
    BuildContext context, {
    required MediaPermissionFlow flow,
    required AppPermissionStatus status,
  }) {
    final text = AppLocalizations.of(context);
    return mapStatusFromText(text, flow: flow, status: status);
  }

  MediaPermissionFeedback mapStatusFromText(
    AppLocalizations text, {
    required MediaPermissionFlow flow,
    required AppPermissionStatus status,
  }) {
    if (status.granted) {
      return MediaPermissionFeedback(
        granted: true,
        dedupeKey: 'permission:${flow.name}:granted',
      );
    }

    final blocked =
        status.state == AppPermissionState.permanentlyDenied ||
        status.state == AppPermissionState.restricted;
    final spec = _copy(text, flow: flow, blocked: blocked);
    return MediaPermissionFeedback(
      granted: false,
      dedupeKey:
          'permission:${flow.name}:${blocked ? 'blocked' : status.state.name}',
      title: text.permissionsAccessNeededTitle,
      message: spec.message,
      actionLabel: blocked ? text.permissionsOpenSettingsAction : null,
      onAction: blocked
          ? () async {
              await _permissionCoordinator.openSettings();
            }
          : null,
    );
  }

  MediaPermissionFeedback fallback(
    BuildContext context, {
    required MediaPermissionFlow flow,
  }) {
    final text = AppLocalizations.of(context);
    return fallbackFromText(text, flow: flow);
  }

  MediaPermissionFeedback fallbackFromText(
    AppLocalizations text, {
    required MediaPermissionFlow flow,
  }) {
    final spec = _copy(text, flow: flow, blocked: true);
    return MediaPermissionFeedback(
      granted: false,
      dedupeKey: 'permission:${flow.name}:fallback',
      title: text.permissionsAccessNeededTitle,
      message: spec.message,
      actionLabel: text.permissionsOpenSettingsAction,
      onAction: () async {
        await _permissionCoordinator.openSettings();
      },
    );
  }

  void show(
    BuildContext context,
    MediaPermissionFeedback feedback, {
    PetMagicToastTone tone = PetMagicToastTone.warning,
  }) {
    final message = feedback.message?.trim();
    if (feedback.granted || message == null || message.isEmpty) {
      return;
    }

    PetMagicToast.show(
      context,
      title: feedback.title,
      message: message,
      tone: tone,
      dedupeKey: feedback.dedupeKey,
      action: feedback.actionLabel == null || feedback.onAction == null
          ? null
          : PetMagicNotificationAction(
              label: feedback.actionLabel!,
              onPressed: feedback.onAction!,
            ),
    );
  }

  AppPermissionType _requiredPermission(MediaPermissionFlow flow) {
    return switch (flow) {
      MediaPermissionFlow.galleryPhoto => AppPermissionType.photos,
      MediaPermissionFlow.mediaLibrary => AppPermissionType.photos,
      MediaPermissionFlow.cameraPhoto => AppPermissionType.camera,
      MediaPermissionFlow.cameraVideo => AppPermissionType.camera,
      MediaPermissionFlow.microphoneVideo => AppPermissionType.microphone,
    };
  }

  _MediaPermissionCopy _copy(
    AppLocalizations text, {
    required MediaPermissionFlow flow,
    required bool blocked,
  }) {
    return switch (flow) {
      MediaPermissionFlow.galleryPhoto => _MediaPermissionCopy(
        message: blocked
            ? text.permissionsGalleryAccessBlockedMessage
            : text.permissionsGalleryAccessDeniedMessage,
      ),
      MediaPermissionFlow.mediaLibrary => _MediaPermissionCopy(
        message: blocked
            ? text.permissionsMediaAccessBlockedMessage
            : text.permissionsMediaAccessDeniedMessage,
      ),
      MediaPermissionFlow.cameraPhoto => _MediaPermissionCopy(
        message: blocked
            ? text.permissionsCameraAccessBlockedMessage
            : text.permissionsCameraAccessDeniedMessage,
      ),
      MediaPermissionFlow.cameraVideo => _MediaPermissionCopy(
        message: blocked
            ? text.permissionsCameraVideoAccessBlockedMessage
            : text.permissionsCameraVideoAccessDeniedMessage,
      ),
      MediaPermissionFlow.microphoneVideo => _MediaPermissionCopy(
        message: blocked
            ? text.permissionsMicrophoneAccessBlockedMessage
            : text.permissionsMicrophoneAccessDeniedMessage,
      ),
    };
  }
}

class _MediaPermissionCopy {
  const _MediaPermissionCopy({required this.message});

  final String message;
}
