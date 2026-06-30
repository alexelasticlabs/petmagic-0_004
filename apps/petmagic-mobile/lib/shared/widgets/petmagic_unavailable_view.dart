import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';

class PetMagicUnavailableView extends StatelessWidget {
  const PetMagicUnavailableView({
    required this.kind,
    required this.onRetry,
    this.footer,
    this.padding,
    super.key,
  });

  final AppUnavailableKind kind;
  final VoidCallback onRetry;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);

    return PetMagicAsyncStateView(
      icon: kind == AppUnavailableKind.offline
          ? Icons.wifi_off_rounded
          : Icons.cloud_off_rounded,
      title: kind == AppUnavailableKind.offline
          ? text.appUnavailableOfflineTitle
          : text.appUnavailableServerTitle,
      message: kind == AppUnavailableKind.offline
          ? text.appUnavailableOfflineMessage
          : text.appUnavailableServerMessage,
      actionLabel: text.retryAction,
      onAction: onRetry,
      footer: footer,
      padding: padding,
    );
  }
}
