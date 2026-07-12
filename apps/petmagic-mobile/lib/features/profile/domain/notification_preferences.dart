class NotificationPreferences {
  const NotificationPreferences({
    required this.pushPhotoReady,
    required this.pushVideoReady,
    required this.pushGenerationErrors,
    required this.pushReminders,
    required this.pushNewTemplates,
    required this.pushPurchasesAndSubscriptions,
    required this.emailOffersAndDiscounts,
    required this.emailNews,
    required this.emailAccountAlerts,
  });

  const NotificationPreferences.defaults()
    : this(
        pushPhotoReady: true,
        pushVideoReady: true,
        pushGenerationErrors: true,
        pushReminders: true,
        pushNewTemplates: true,
        pushPurchasesAndSubscriptions: true,
        emailOffersAndDiscounts: false,
        emailNews: false,
        emailAccountAlerts: true,
      );

  final bool pushPhotoReady;
  final bool pushVideoReady;
  final bool pushGenerationErrors;
  final bool pushReminders;
  final bool pushNewTemplates;
  final bool pushPurchasesAndSubscriptions;
  final bool emailOffersAndDiscounts;
  final bool emailNews;
  final bool emailAccountAlerts;

  NotificationPreferences copyWith({
    bool? pushPhotoReady,
    bool? pushVideoReady,
    bool? pushGenerationErrors,
    bool? pushReminders,
    bool? pushNewTemplates,
    bool? pushPurchasesAndSubscriptions,
    bool? emailOffersAndDiscounts,
    bool? emailNews,
    bool? emailAccountAlerts,
  }) {
    return NotificationPreferences(
      pushPhotoReady: pushPhotoReady ?? this.pushPhotoReady,
      pushVideoReady: pushVideoReady ?? this.pushVideoReady,
      pushGenerationErrors: pushGenerationErrors ?? this.pushGenerationErrors,
      pushReminders: pushReminders ?? this.pushReminders,
      pushNewTemplates: pushNewTemplates ?? this.pushNewTemplates,
      pushPurchasesAndSubscriptions:
          pushPurchasesAndSubscriptions ?? this.pushPurchasesAndSubscriptions,
      emailOffersAndDiscounts:
          emailOffersAndDiscounts ?? this.emailOffersAndDiscounts,
      emailNews: emailNews ?? this.emailNews,
      emailAccountAlerts: emailAccountAlerts ?? this.emailAccountAlerts,
    );
  }

  Map<String, dynamic> toJson() => {
    'pushPhotoReady': pushPhotoReady,
    'pushVideoReady': pushVideoReady,
    'pushGenerationErrors': pushGenerationErrors,
    'pushReminders': pushReminders,
    'pushNewTemplates': pushNewTemplates,
    'pushPurchasesAndSubscriptions': pushPurchasesAndSubscriptions,
    'emailOffersAndDiscounts': emailOffersAndDiscounts,
    'emailNews': emailNews,
    'emailAccountAlerts': emailAccountAlerts,
  };

  static NotificationPreferences fromJson(
    Map<String, dynamic> json, {
    required bool fallbackMarketingEmails,
  }) {
    return NotificationPreferences(
      pushPhotoReady: json['pushPhotoReady'] as bool? ?? true,
      pushVideoReady: json['pushVideoReady'] as bool? ?? true,
      pushGenerationErrors: json['pushGenerationErrors'] as bool? ?? true,
      pushReminders: json['pushReminders'] as bool? ?? true,
      pushNewTemplates: json['pushNewTemplates'] as bool? ?? true,
      pushPurchasesAndSubscriptions:
          json['pushPurchasesAndSubscriptions'] as bool? ?? true,
      emailOffersAndDiscounts:
          json['emailOffersAndDiscounts'] as bool? ?? fallbackMarketingEmails,
      emailNews: json['emailNews'] as bool? ?? false,
      emailAccountAlerts: json['emailAccountAlerts'] as bool? ?? true,
    );
  }
}
