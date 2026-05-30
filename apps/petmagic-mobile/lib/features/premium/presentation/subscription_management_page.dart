import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final summaryAsync = ref.watch(premiumSubscriptionSummaryProvider);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Scaffold(
      appBar: AppBar(title: Text(text.profileSubscriptionTitle)),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(text.premiumManageFailed),
            ),
          ),
          data: (summary) {
            final nextBilling = summary.currentPeriodEndUtc == null
                ? text.walletPending
                : DateFormat.yMMMd(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(summary.currentPeriodEndUtc!.toLocal());
            final renewalStatus = !summary.isPremium
                ? 'inactive'
                : summary.cancelAtPeriodEnd == true
                ? 'cancel_at_period_end'
                : 'auto_renew';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ProfileGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        label: text.profileSubscriptionStatusLabel,
                        value: summary.status,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: text.profileSubscriptionProviderLabel,
                        value: _providerLabel(summary.provider, text),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: text.profileSubscriptionNextBillingLabel,
                        value: nextBilling,
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(label: 'Renewal', value: renewalStatus),
                      if (summary.planName != null) ...[
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: text.premiumChoosePlanTitle,
                          value: summary.planName!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      _isProcessing ||
                          !summary.canManageSubscription ||
                          !summary.isPremium
                      ? null
                      : () =>
                            _openManageTarget(summary.manageSubscriptionAction),
                  child: Text(text.premiumManageAction),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isProcessing ? null : _restorePurchases,
                  child: Text(text.premiumRestoreAction),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => context.push(PremiumPage.routePath),
                  child: Text(text.premiumChoosePlanTitle),
                ),
                if (summary.provider ==
                        PremiumSubscriptionProviderView.stripe &&
                    summary.isPremium) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _isProcessing || !summary.canManageSubscription
                        ? null
                        : () => _openManageTarget(
                            summary.manageSubscriptionAction,
                          ),
                    child: const Text('Update payment method'),
                  ),
                ],
                if (summary.provider ==
                        PremiumSubscriptionProviderView.stripe &&
                    summary.isPremium &&
                    summary.cancelAtPeriodEnd != true) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _isProcessing ? null : _cancelAtPeriodEnd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.danger,
                      side: BorderSide(
                        color: colors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text('Cancel subscription'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openManageTarget(String manageSubscriptionAction) async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(premiumSubscriptionManagementServiceProvider);
      final url = await service.createManagementUrl(manageSubscriptionAction);
      final uri = Uri.parse(url);
      var launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        launched = false;
      }
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelAtPeriodEnd() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(premiumSubscriptionManagementServiceProvider);
      await service.requestCancelAtPeriodEnd();
      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(profileControllerProvider);
      ref.invalidate(premiumControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-renew disabled for current period.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(premiumControllerProvider.notifier).restorePurchases();
      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(profileControllerProvider);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _providerLabel(
    PremiumSubscriptionProviderView provider,
    AppLocalizations text,
  ) {
    return switch (provider) {
      PremiumSubscriptionProviderView.appStore => text.premiumPaymentApple,
      PremiumSubscriptionProviderView.googlePlay =>
        text.premiumPaymentGooglePlay,
      PremiumSubscriptionProviderView.stripe => text.premiumPaymentStripe,
      PremiumSubscriptionProviderView.unknown => text.premiumPaymentStripe,
    };
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: colors.textStrong,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
