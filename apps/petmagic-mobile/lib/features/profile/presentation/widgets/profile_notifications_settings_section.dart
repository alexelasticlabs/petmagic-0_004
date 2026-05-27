import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
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

  NotificationPreferences? _preferences;
  AuthorizationStatus? _pushAuthorizationStatus;
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
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = NotificationPreferences.defaults().copyWith(
          emailOffersAndDiscounts: widget.fallbackMarketingEmails,
        );
        _pushAuthorizationStatus = null;
        _isLoading = false;
      });
    }
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
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _pushAuthorizationStatus = settings.authorizationStatus;
    });
  }

  Future<void> _requestPushPermission() async {
    setState(() {
      _isRequestingPermission = true;
    });

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
                      label: text.profileNotificationsPushPhotoReady,
                      value: _preferences!.pushPhotoReady,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushPhotoReady: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      label: text.profileNotificationsPushVideoReady,
                      value: _preferences!.pushVideoReady,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushVideoReady: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      label: text.profileNotificationsPushGenerationErrors,
                      value: _preferences!.pushGenerationErrors,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushGenerationErrors: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      label: text.profileNotificationsPushReminders,
                      value: _preferences!.pushReminders,
                      enabled: !_isSaving,
                      onChanged: (value) =>
                          _update(_preferences!.copyWith(pushReminders: value)),
                    ),
                    _NotificationToggleRow(
                      label: text.profileNotificationsPushNewTemplates,
                      value: _preferences!.pushNewTemplates,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(pushNewTemplates: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      label: text
                          .profileNotificationsPushPurchasesAndSubscriptions,
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
                      label: text.profileNotificationsEmailOffers,
                      value: _preferences!.emailOffersAndDiscounts,
                      enabled: !_isSaving,
                      onChanged: (value) => _update(
                        _preferences!.copyWith(emailOffersAndDiscounts: value),
                      ),
                    ),
                    _NotificationToggleRow(
                      label: text.profileNotificationsEmailNews,
                      value: _preferences!.emailNews,
                      enabled: !_isSaving,
                      onChanged: (value) =>
                          _update(_preferences!.copyWith(emailNews: value)),
                    ),
                    _NotificationToggleRow(
                      label: text.profileNotificationsEmailAccountAlerts,
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
                    _NotificationsInfoRow(
                      label: text.profileNotificationsPushPermissionLabel,
                      value: _pushPermissionLabel(text),
                    ),
                    const SizedBox(height: 8),
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

class _NotificationsInfoRow extends StatelessWidget {
  const _NotificationsInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
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
    this.enabled = true,
    this.showDivider = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
