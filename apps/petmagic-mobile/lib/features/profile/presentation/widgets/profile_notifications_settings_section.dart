import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/profile/data/notification_preferences_storage.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

part 'profile_notifications_settings_widgets.part.dart';

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
    extends ConsumerState<ProfileNotificationsSettingsSection> {
  final NotificationPreferencesStorage _storage =
      NotificationPreferencesStorage();
  final AppPermissionCoordinator _permissionCoordinator =
      AppPermissionCoordinator();
  late final PushTokenRegistrar _pushTokenRegistrar = PushTokenRegistrar(
    templateRepository: ref.read(templateGenerationRepositoryProvider),
    supportRepository: ref.read(supportChatRepositoryProvider),
    walletRepository: ref.read(walletRepositoryProvider),
  );

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
    _load();
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
      final previousToken = await _pushTokenRegistrar.readRegisteredToken();
      if (!mounted) {
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty || !mounted) {
        return;
      }

      final registered = await _pushTokenRegistrar.registerToken(
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

    await _pushTokenRegistrar.unregisterToken(
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

    final cachedToken = await _pushTokenRegistrar.readRegisteredToken();
    if (!mounted) {
      return;
    }

    final token = cachedToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty || !mounted) {
      return;
    }

    await _pushTokenRegistrar.unregisterToken(
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
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, widget.bottomInset),
          children: [
            _NotificationsDetailHeader(
              title: widget.title,
              subtitle: widget.subtitle,
            ),
            const SizedBox(height: 22),
            if (widget.errorMessage != null) ...[
              ProfileGlassCard(
                child: Text(
                  mapProfileFeedbackMessage(widget.errorMessage!, text),
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_isLoading || _preferences == null)
              ProfileGlassCard(
                child: Text(
                  text.profileNotificationsLoading,
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else ...[
              ProfileSectionLabel(label: text.profileNotificationsPushSection),
              const SizedBox(height: 8),
              ProfileGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NotificationToggleRow(
                      icon: Icons.image_outlined,
                      label: text.profileNotificationsPushPhotoReady,
                      subtitle: text.profileNotificationsPushPhotoReadySubtitle,
                      value: _preferences!.pushPhotoReady,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushPhotoReady: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.video_camera_back_outlined,
                      label: text.profileNotificationsPushVideoReady,
                      subtitle: text.profileNotificationsPushVideoReadySubtitle,
                      value: _preferences!.pushVideoReady,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushVideoReady: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.error_outline_rounded,
                      label: text.profileNotificationsPushGenerationErrors,
                      subtitle:
                          text.profileNotificationsPushGenerationErrorsSubtitle,
                      value: _preferences!.pushGenerationErrors,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushGenerationErrors: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.alarm_outlined,
                      label: text.profileNotificationsPushReminders,
                      subtitle: text.profileNotificationsPushRemindersSubtitle,
                      value: _preferences!.pushReminders,
                      enabled: !_isSaving,
                      onChanged: (value) =>
                          _update(_preferences!.copyWith(pushReminders: value)),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.auto_awesome_outlined,
                      label: text.profileNotificationsPushNewTemplates,
                      subtitle:
                          text.profileNotificationsPushNewTemplatesSubtitle,
                      value: _preferences!.pushNewTemplates,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushNewTemplates: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.receipt_long_outlined,
                      label: text
                          .profileNotificationsPushPurchasesAndSubscriptions,
                      subtitle: text
                          .profileNotificationsPushPurchasesAndSubscriptionsSubtitle,
                      value: _preferences!.pushPurchasesAndSubscriptions,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(
                          pushPurchasesAndSubscriptions: value,
                        ),
                      ),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionLabel(label: text.profileNotificationsEmailSection),
              const SizedBox(height: 8),
              ProfileGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NotificationToggleRow(
                      icon: Icons.local_offer_outlined,
                      label: text.profileNotificationsEmailOffers,
                      subtitle: text.profileNotificationsEmailOffersSubtitle,
                      value: _preferences!.emailOffersAndDiscounts,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(emailOffersAndDiscounts: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.newspaper_rounded,
                      label: text.profileNotificationsEmailNews,
                      subtitle: text.profileNotificationsEmailNewsSubtitle,
                      value: _preferences!.emailNews,
                      enabled: !_isSaving,
                      onChanged: (value) =>
                          _update(_preferences!.copyWith(emailNews: value)),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.notifications_active_outlined,
                      label: text.profileNotificationsEmailAccountAlerts,
                      subtitle:
                          text.profileNotificationsEmailAccountAlertsSubtitle,
                      value: _preferences!.emailAccountAlerts,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(emailAccountAlerts: value),
                      ),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionLabel(
                label: text.profileNotificationsDeviceSection,
              ),
              const SizedBox(height: 8),
              ProfileGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PushPermissionStatusCard(
                      label: text.profileNotificationsPushPermissionLabel,
                      value: _pushPermissionLabel(text),
                      status: _pushAuthorizationStatus,
                    ),
                    if (_devicePermissions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: colors.border.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            children: [
                              for (final permission in _devicePermissions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _DevicePermissionRow(
                                    name: _devicePermissionName(
                                      text,
                                      permission.type,
                                    ),
                                    stateLabel: _devicePermissionStateLabel(
                                      text,
                                      permission.state,
                                    ),
                                    state: permission.state,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: _isRequestingPermission
                              ? null
                              : _refreshPushPermissionStatus,
                          child: Text(text.profileNotificationsRefreshStatus),
                        ),
                        FilledButton(
                          onPressed: _isRequestingPermission
                              ? null
                              : _requestPushPermission,
                          child: Text(
                            _isRequestingPermission
                                ? text.profileLoadingAction
                                : text.profileNotificationsRequestPermission,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              _isRequestingPermission || _isOpeningSettings
                              ? null
                              : _openDeviceSettings,
                          child: Text(text.supportChatOpenSettingsAction),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
