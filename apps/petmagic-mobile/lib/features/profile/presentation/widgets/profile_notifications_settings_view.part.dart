part of 'profile_notifications_settings_section.dart';

extension _ProfileNotificationsSettingsView
    on _ProfileNotificationsSettingsSectionState {
  Widget _buildNotificationsSettings(BuildContext context) {
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
                        if (_pushAuthorizationStatus !=
                            AuthorizationStatus.denied)
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
                        FilledButton(
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
