import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/profile/application/notification_preferences_port.dart';
import 'package:petmagic_mobile/features/profile/application/push_token_lifecycle_port.dart';
import 'package:petmagic_mobile/features/profile/domain/notification_preferences.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';

part 'profile_notifications_settings_widgets.part.dart';

part 'profile_notifications_settings_view.part.dart';

class ProfileNotificationsSettingsSection extends ConsumerStatefulWidget {
  const ProfileNotificationsSettingsSection({
    required this.title,
    required this.subtitle,
    required this.errorMessage,
    required this.scope,
    required this.fallbackMarketingEmails,
    required this.bottomInset,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? errorMessage;
  final String scope;
  final bool fallbackMarketingEmails;
  final double bottomInset;

  @override
  ConsumerState<ProfileNotificationsSettingsSection> createState() =>
      _ProfileNotificationsSettingsSectionState();
}

class _ProfileNotificationsSettingsSectionState
    extends ConsumerState<ProfileNotificationsSettingsSection>
    with WidgetsBindingObserver {
  NotificationPreferencesStoragePort get _storage =>
      ref.read(notificationPreferencesStorageProvider);
  final AppPermissionCoordinator _permissionCoordinator =
      AppPermissionCoordinator();
  PushTokenLifecyclePort get _pushTokenLifecycle =>
      ref.read(pushTokenLifecyclePortProvider);

  NotificationPreferences? _preferences;
  AuthorizationStatus? _pushAuthorizationStatus;
  List<AppPermissionStatus> _devicePermissions = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRequestingPermission = false;
  bool _isOpeningSettings = false;

  void _logNotificationsFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.warn(
      feature: 'Profile.Notifications.Settings',
      operation: stage,
      message: 'Notification settings step failed',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _isLoading) {
      return;
    }

    unawaited(_refreshPushPermissionStatus());
    unawaited(_refreshDevicePermissions());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final preferences = await _storage.read(
        scope: widget.scope,
        fallbackMarketingEmails: widget.fallbackMarketingEmails,
      );
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = preferences;
        _pushAuthorizationStatus = settings.authorizationStatus;
        _devicePermissions = const [];
        _isLoading = false;
      });
      await _refreshDevicePermissions();
      await _reconcilePushTokenRegistration(settings.authorizationStatus);
    } catch (error, stackTrace) {
      _logNotificationsFailure('load', error, stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = NotificationPreferences.defaults().copyWith(
          emailOffersAndDiscounts: widget.fallbackMarketingEmails,
        );
        _pushAuthorizationStatus = null;
        _devicePermissions = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDevicePermissions() async {
    try {
      final statuses = await _permissionCoordinator.readStatuses(
        types: const [AppPermissionType.notifications],
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _devicePermissions = statuses;
      });
    } catch (error, stackTrace) {
      _logNotificationsFailure('refresh_device_permissions', error, stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _devicePermissions = const [];
      });
    }
  }

  Future<void> _update(NotificationPreferences next) async {
    if (_isSaving) {
      return;
    }

    final previous = _preferences;

    setState(() {
      _preferences = next;
      _isSaving = true;
    });

    try {
      await _storage.save(scope: widget.scope, preferences: next);
    } catch (error, stackTrace) {
      _logNotificationsFailure('save_preferences', error, stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = previous;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _refreshPushPermissionStatus() async {
    if (_isRequestingPermission) {
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      if (!mounted) {
        return;
      }

      setState(() {
        _pushAuthorizationStatus = settings.authorizationStatus;
      });
      await _reconcilePushTokenRegistration(settings.authorizationStatus);
    } catch (error, stackTrace) {
      _logNotificationsFailure('refresh_push_permission', error, stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _pushAuthorizationStatus = null;
      });
    }
  }

  Future<void> _requestPushPermission() async {
    if (_isRequestingPermission) {
      return;
    }

    setState(() {
      _isRequestingPermission = true;
    });

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRequestingPermission = false;
        _pushAuthorizationStatus = settings.authorizationStatus;
      });
      await _reconcilePushTokenRegistration(settings.authorizationStatus);
    } catch (error, stackTrace) {
      _logNotificationsFailure('request_push_permission', error, stackTrace);
      if (!mounted) {
        return;
      }

      setState(() {
        _isRequestingPermission = false;
      });
    }
  }

  Future<void> _registerPushTokenIfAllowed(AuthorizationStatus status) async {
    if (!_isPushPermissionAllowed(status) || !mounted) {
      return;
    }

    try {
      final previousToken = await _pushTokenLifecycle.readRegisteredToken();
      if (!mounted) {
        return;
      }

      final token = await _pushTokenLifecycle.readCurrentDeviceToken();
      if (token == null || token.isEmpty || !mounted) {
        return;
      }

      final registered = await _pushTokenLifecycle.registerToken(
        token: token,
        platform: defaultTargetPlatform.name,
        locale: Localizations.localeOf(context).toLanguageTag(),
        canContinue: () => mounted,
      );
      if (registered && mounted) {
        await _unregisterStalePushToken(previousToken, replacementToken: token);
      }
    } catch (error, stackTrace) {
      _logNotificationsFailure(
        'register_push_token_after_permission',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _unregisterStalePushToken(
    String? staleToken, {
    required String replacementToken,
  }) async {
    final normalizedStaleToken = staleToken?.trim();
    if (normalizedStaleToken == null ||
        normalizedStaleToken.isEmpty ||
        normalizedStaleToken == replacementToken.trim() ||
        !mounted) {
      return;
    }

    await _pushTokenLifecycle.unregisterToken(
      token: normalizedStaleToken,
      clearRegistrationState: false,
      canContinue: () => mounted,
      onFailure: (stage, error, stackTrace) {
        _logNotificationsFailure(
          'unregister_stale_${stage}_token_after_permission_change',
          error,
          stackTrace,
        );
      },
    );
  }

  Future<void> _reconcilePushTokenRegistration(
    AuthorizationStatus status,
  ) async {
    if (_isPushPermissionAllowed(status)) {
      await _registerPushTokenIfAllowed(status);
      return;
    }

    final cachedToken = await _pushTokenLifecycle.readRegisteredToken();
    if (!mounted) {
      return;
    }

    final token =
        cachedToken ?? await _pushTokenLifecycle.readCurrentDeviceToken();
    if (token == null || token.isEmpty || !mounted) {
      return;
    }

    await _pushTokenLifecycle.unregisterToken(
      token: token,
      canContinue: () => mounted,
      onFailure: (stage, error, stackTrace) {
        _logNotificationsFailure(
          'unregister_${stage}_token_after_permission_change',
          error,
          stackTrace,
        );
      },
    );
  }

  bool _isPushPermissionAllowed(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _openDeviceSettings() async {
    if (_isOpeningSettings) {
      return;
    }

    setState(() {
      _isOpeningSettings = true;
    });

    try {
      await _permissionCoordinator.openSettings();
      await _refreshDevicePermissions();
    } catch (error, stackTrace) {
      _logNotificationsFailure('open_device_settings', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningSettings = false;
        });
      }
    }
  }

  String _pushPermissionLabel(AppLocalizations text) {
    return switch (_pushAuthorizationStatus) {
      AuthorizationStatus.authorized =>
        text.profileNotificationsPushPermissionAllowed,
      AuthorizationStatus.denied =>
        text.profileNotificationsPushPermissionDenied,
      AuthorizationStatus.notDetermined =>
        text.profileNotificationsPushPermissionNotDetermined,
      AuthorizationStatus.provisional =>
        text.profileNotificationsPushPermissionProvisional,
      _ => text.profileNotificationsPushPermissionUnknown,
    };
  }

  String _devicePermissionStateLabel(
    AppLocalizations text,
    AppPermissionState state,
  ) {
    return switch (state) {
      AppPermissionState.granted => text.profileNotificationsDeviceAllowed,
      AppPermissionState.limited => text.profileNotificationsDeviceLimited,
      AppPermissionState.denied => text.profileNotificationsDeviceDenied,
      AppPermissionState.permanentlyDenied =>
        text.profileNotificationsDevicePermanentlyDenied,
      AppPermissionState.restricted =>
        text.profileNotificationsDeviceRestricted,
      _ => text.profileNotificationsDeviceUnknown,
    };
  }

  String _devicePermissionName(AppLocalizations text, AppPermissionType type) {
    return switch (type) {
      AppPermissionType.notifications =>
        text.profileNotificationsDeviceNotifications,
      AppPermissionType.camera => text.profileNotificationsDeviceCamera,
      AppPermissionType.microphone => text.profileNotificationsDeviceMicrophone,
      AppPermissionType.photos => text.profileNotificationsDevicePhotos,
      AppPermissionType.videos => text.videoLabel,
    };
  }

  @override
  Widget build(BuildContext context) => _buildNotificationsSettings(context);
}
