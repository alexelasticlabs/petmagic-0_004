import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:url_launcher/url_launcher.dart';

part 'subscription_management_content.part.dart';
part 'subscription_management_sections.part.dart';
part 'subscription_management_progress.part.dart';
part 'subscription_management_shared.part.dart';
part 'subscription_management_visuals.part.dart';

class SubscriptionManagementPage extends ConsumerStatefulWidget {
  const SubscriptionManagementPage({super.key});

  static const routePath = '/profile/subscription/manage';

  @override
  ConsumerState<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends ConsumerState<SubscriptionManagementPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(text.profileSubscriptionTitle)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: SubscriptionManagementPage.routePath,
              ),
            ),
          ),
        ),
      );
    }

    final summaryAsync = ref.watch(premiumSubscriptionSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(text.profileSubscriptionTitle)),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text.premiumManageFailed, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(premiumSubscriptionSummaryProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(text.retryAction),
                  ),
                ],
              ),
            ),
          ),
          data: (summary) => _SubscriptionContent(
            summary: summary,
            isProcessing: _isProcessing,
            onManage: () => _openManageTarget(summary.manageSubscriptionAction),
            onRestore: _restorePurchases,
            onChangePayment: () =>
                _openManageTarget(summary.manageSubscriptionAction),
            onCancel: _cancelAtPeriodEnd,
          ),
        ),
      ),
    );
  }

  Future<void> _openManageTarget(String manageSubscriptionAction) async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(premiumSubscriptionManagementServiceProvider);
      final url = await service.createManagementUrl(manageSubscriptionAction);
      if (!mounted) {
        return;
      }

      final uri = parseSafePremiumExternalUri(url);
      if (uri == null) {
        if (mounted) {
          PetMagicToast.show(
            context,
            message: AppLocalizations.of(context).premiumManageFailed,
            tone: PetMagicToastTone.warning,
          );
        }
        return;
      }

      var launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (error, stackTrace) {
        _logSubscriptionLaunchFailure(
          mode: LaunchMode.inAppBrowserView.name,
          uri: uri,
          error: error,
          stackTrace: stackTrace,
        );
        launched = false;
      }
      if (!mounted) {
        return;
      }

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (error, stackTrace) {
          _logSubscriptionLaunchFailure(
            mode: LaunchMode.externalApplication.name,
            uri: uri,
            error: error,
            stackTrace: stackTrace,
          );
          launched = false;
        }
      }
      if (!launched && mounted) {
        PetMagicToast.show(
          context,
          message: AppLocalizations.of(context).premiumManageFailed,
          tone: PetMagicToastTone.warning,
        );
      }
    } catch (error, stackTrace) {
      _logSubscriptionActionFailure('open_manage_target', error, stackTrace);
      _showSubscriptionActionFailed();
    } finally {
      if (mounted) {
        ref.invalidate(premiumSubscriptionSummaryProvider);
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelAtPeriodEnd() async {
    if (_isProcessing) {
      return;
    }

    final summary = ref.read(premiumSubscriptionSummaryProvider).value;
    final text = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = summary?.currentPeriodEndUtc != null
        ? DateFormat.yMMMd(
            locale,
          ).format(summary!.currentPeriodEndUtc!.toLocal())
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CancelConfirmDialog(text: text, periodEndDateStr: dateStr),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(premiumSubscriptionManagementServiceProvider);
      await service.requestCancelAtPeriodEnd();
      if (!mounted) {
        return;
      }

      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(profileControllerProvider);
      ref.invalidate(premiumControllerProvider);
      if (mounted) {
        PetMagicToast.show(
          context,
          message: AppLocalizations.of(context).subscriptionAutoRenewOff,
          tone: PetMagicToastTone.success,
        );
      }
    } catch (error, stackTrace) {
      _logSubscriptionActionFailure('cancel_at_period_end', error, stackTrace);
      _showSubscriptionActionFailed();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ref.read(premiumControllerProvider.notifier).restorePurchases();
      if (!mounted) {
        return;
      }

      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(profileControllerProvider);
      // Read updated summary to determine snackbar message
      final updated = await ref.read(premiumSubscriptionSummaryProvider.future);
      if (mounted) {
        final text = AppLocalizations.of(context);
        final message = updated.isPremium
            ? text.subscriptionRestoreSuccessMessage
            : text.subscriptionRestoreNoneFoundMessage;
        PetMagicToast.show(
          context,
          message: message,
          tone: updated.isPremium
              ? PetMagicToastTone.success
              : PetMagicToastTone.info,
        );
      }
    } catch (error, stackTrace) {
      _logSubscriptionActionFailure('restore_purchases', error, stackTrace);
      _showSubscriptionActionFailed();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSubscriptionActionFailed() {
    if (!mounted) {
      return;
    }

    PetMagicToast.show(
      context,
      message: AppLocalizations.of(context).premiumManageFailed,
      tone: PetMagicToastTone.warning,
    );
  }

  void _logSubscriptionActionFailure(
    String action,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.warn(
      feature: 'Premium.SubscriptionManagement',
      operation: action,
      message: 'Subscription management action failed',
      context: {'action': action},
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logSubscriptionLaunchFailure({
    required String mode,
    required Uri uri,
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.warn(
      feature: 'Premium.SubscriptionManagement',
      operation: 'launch_manage_target',
      message: 'Subscription management launch mode failed',
      context: {
        'mode': mode,
        'scheme': uri.scheme,
        'host': uri.host,
        'port': uri.hasPort ? uri.port : null,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}
