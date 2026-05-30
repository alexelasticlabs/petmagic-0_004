import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/profile/data/notification_preferences_storage.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_feedback_mapper.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';

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

  NotificationPreferences? _preferences;
  AuthorizationStatus? _pushAuthorizationStatus;
  List<AppPermissionStatus> _devicePermissions = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRequestingPermission = false;

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
    } catch (_) {
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
    final statuses = await _permissionCoordinator.readStatuses();
    if (!mounted) {
      return;
    }
    setState(() {
      _devicePermissions = statuses;
    });
  }

  Future<void> _update(NotificationPreferences next) async {
    final previous = _preferences;

    setState(() {
      _preferences = next;
      _isSaving = true;
    });

    try {
      await _storage.save(scope: widget.scope, preferences: next);
    } catch (_) {
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
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      if (!mounted) {
        return;
      }

      setState(() {
        _pushAuthorizationStatus = settings.authorizationStatus;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pushAuthorizationStatus = null;
      });
    }
  }

  Future<void> _requestPushPermission() async {
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRequestingPermission = false;
      });
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

  Future<void> _requestCorePermissions() async {
    setState(() {
      _isRequestingPermission = true;
    });
    try {
      await _permissionCoordinator.requestOnDemand(AppPermissionType.camera);
      await _permissionCoordinator.requestOnDemand(AppPermissionType.photos);
      await _permissionCoordinator.requestOnDemand(AppPermissionType.files);
      await _refreshPushPermissionStatus();
      await _refreshDevicePermissions();
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
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
      AppPermissionType.photos => text.profileNotificationsDevicePhotos,
      AppPermissionType.files => text.profileNotificationsDeviceFiles,
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
                      subtitle: 'Когда AI-фото готово к просмотру',
                      value: _preferences!.pushPhotoReady,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushPhotoReady: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.video_camera_back_outlined,
                      label: text.profileNotificationsPushVideoReady,
                      subtitle: 'Когда AI-видео завершило обработку',
                      value: _preferences!.pushVideoReady,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushVideoReady: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.error_outline_rounded,
                      label: text.profileNotificationsPushGenerationErrors,
                      subtitle: 'Если генерация завершилась с ошибкой',
                      value: _preferences!.pushGenerationErrors,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushGenerationErrors: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.alarm_outlined,
                      label: text.profileNotificationsPushReminders,
                      subtitle: 'Напоминания об использовании приложения',
                      value: _preferences!.pushReminders,
                      enabled: !_isSaving,
                      onChanged: (value) =>
                          _update(_preferences!.copyWith(pushReminders: value)),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.auto_awesome_outlined,
                      label: text.profileNotificationsPushNewTemplates,
                      subtitle: 'Новые стили и шаблоны генерации',
                      value: _preferences!.pushNewTemplates,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushNewTemplates: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.receipt_long_outlined,
                      label: text.profileNotificationsPushPurchasesAndSubscriptions,
                      subtitle: 'Подтверждения оплат и статус подписки',
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
                      subtitle: 'Скидки, акции и промо-предложения',
                      value: _preferences!.emailOffersAndDiscounts,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(emailOffersAndDiscounts: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.newspaper_rounded,
                      label: text.profileNotificationsEmailNews,
                      subtitle: 'Обновления приложения и новые функции',
                      value: _preferences!.emailNews,
                      enabled: !_isSaving,
                      onChanged: (value) =>
                          _update(_preferences!.copyWith(emailNews: value)),
                    ),
                    _NotificationToggleRow(
                      icon: Icons.notifications_active_outlined,
                      label: text.profileNotificationsEmailAccountAlerts,
                      subtitle: 'Уведомления безопасности и о смене данных',
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
                          onPressed: _isRequestingPermission
                              ? null
                              : _requestCorePermissions,
                          child: Text(
                            _isRequestingPermission
                                ? text.profileLoadingAction
                                : text.profileNotificationsRequestDevicePermissions,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _isRequestingPermission
                              ? null
                              : () => _permissionCoordinator.openSettings(),
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

class _NotificationsDetailHeader extends StatelessWidget {
  const _NotificationsDetailHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final router = GoRouter.of(context);

    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (router.canPop()) {
              router.pop();
              return;
            }

            router.go('/profile/settings');
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textStrong,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.subtitle,
    this.enabled = true,
    this.showDivider = true,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final activeColor = value ? colors.accent : colors.textMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.75),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: activeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: colors.accent,
              activeTrackColor: colors.accent.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushPermissionStatusCard extends StatelessWidget {
  const _PushPermissionStatusCard({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final AuthorizationStatus? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isAllowed = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    final isDenied = status == AuthorizationStatus.denied;
    final chipColor = isAllowed
        ? colors.accent
        : isDenied
            ? colors.danger
            : colors.textMuted;
    final chipIcon = isAllowed
        ? Icons.notifications_active_rounded
        : isDenied
            ? Icons.notifications_off_outlined
            : Icons.notifications_none_rounded;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(chipIcon, size: 20, color: chipColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: chipColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              isAllowed ? '✓' : isDenied ? '✗' : '?',
              style: TextStyle(
                color: chipColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DevicePermissionRow extends StatelessWidget {
  const _DevicePermissionRow({
    required this.name,
    required this.stateLabel,
    required this.state,
  });

  final String name;
  final String stateLabel;
  final AppPermissionState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isOk = state == AppPermissionState.granted ||
        state == AppPermissionState.limited;
    final chipColor = isOk ? colors.accent : colors.textMuted;

    return Row(
      children: [
        Icon(
          isOk ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: chipColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          stateLabel,
          style: TextStyle(
            color: chipColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
