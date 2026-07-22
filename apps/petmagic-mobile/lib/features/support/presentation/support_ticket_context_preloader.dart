import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';

typedef SupportTicketPreloadFailure =
    void Function(String stage, Object error, StackTrace stackTrace);

final class SupportTicketContextPreloader {
  const SupportTicketContextPreloader();

  Future<void> preload({
    required WidgetRef ref,
    required bool Function() isActive,
    required SupportTicketPreloadFailure onFailure,
  }) async {
    if (!isActive() ||
        !ref.read(appLaunchControllerProvider).isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    final preloadTasks = <Future<void>>[];
    final generationState = ref.read(generationHistoryControllerProvider);
    if (_shouldPreloadGenerationContext(generationState)) {
      preloadTasks.add(
        _runStep(
          stage: 'preload_generation_context',
          load: () =>
              ref.read(generationHistoryControllerProvider.notifier).load(),
          isActive: isActive,
          onFailure: onFailure,
        ),
      );
    }

    final walletState = ref.read(walletControllerProvider);
    if (_shouldPreloadWalletContext(walletState)) {
      preloadTasks.add(
        _runStep(
          stage: 'preload_wallet_context',
          load: () => ref.read(walletControllerProvider.notifier).load(),
          isActive: isActive,
          onFailure: onFailure,
        ),
      );
    }

    final premiumState = ref.read(premiumControllerProvider);
    if (_shouldPreloadPremiumContext(premiumState)) {
      preloadTasks.add(
        _runStep(
          stage: 'preload_premium_context',
          load: () => ref.read(premiumControllerProvider.notifier).load(),
          isActive: isActive,
          onFailure: onFailure,
        ),
      );
    }

    await Future.wait<void>(preloadTasks);
  }

  static bool _shouldPreloadGenerationContext(GenerationHistoryState state) {
    return !state.isLoading &&
        state.items.isEmpty &&
        state.cachedItemsByFilter.isEmpty;
  }

  static bool _shouldPreloadWalletContext(WalletState state) {
    if (state.isLoading || state.isRefreshing || state.hasCompletedFullLoad) {
      return false;
    }

    return state.wallet == null || state.purchases.isEmpty;
  }

  static bool _shouldPreloadPremiumContext(PremiumState state) {
    return !state.isLoading && state.status == null;
  }

  static Future<void> _runStep({
    required String stage,
    required Future<void> Function() load,
    required bool Function() isActive,
    required SupportTicketPreloadFailure onFailure,
  }) async {
    if (!isActive()) {
      return;
    }

    try {
      await load();
    } catch (error, stackTrace) {
      if (isActive()) {
        onFailure(stage, error, stackTrace);
      }
    }
  }
}

String? resolveSupportTicketSubscriptionLabel(
  AppLocalizations text,
  PremiumState state,
) {
  final status = state.status;
  if (status?.isPremium != true) {
    return null;
  }

  final planName = status?.planName?.trim();
  if (planName != null && planName.isNotEmpty) {
    return planName;
  }

  return text.premiumLabel;
}
