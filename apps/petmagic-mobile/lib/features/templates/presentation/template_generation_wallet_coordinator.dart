import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_state.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';

final class TemplateGenerationWalletCoordinator {
  const TemplateGenerationWalletCoordinator({
    required this.readWallet,
    required this.loadWallet,
    required this.hasInternet,
    required this.canUsePrivateApi,
    required this.isDisposed,
  });

  final WalletStateModel? Function() readWallet;
  final Future<void> Function() loadWallet;
  final bool Function() hasInternet;
  final bool Function() canUsePrivateApi;
  final bool Function() isDisposed;

  Future<TemplateGenerationGate> checkGate(TemplateItem template) async {
    if (!canUsePrivateApi()) {
      return const TemplateGenerationGate(
        kind: TemplateGenerationGateKind.notEnoughTokens,
        balance: 0,
        isPremium: false,
      );
    }

    var wallet = readWallet();
    if (wallet == null && hasInternet()) {
      await loadWallet();
      wallet = readWallet();
    }
    wallet ??= const WalletStateModel(
      userId: '',
      balance: 0,
      adRewardsRemainingToday: 0,
      isPremium: false,
      updatedAtUtc: null,
    );

    final kind = template.isPremium && !wallet.isPremium
        ? TemplateGenerationGateKind.premiumRequired
        : wallet.balance < template.tokenCost
        ? TemplateGenerationGateKind.notEnoughTokens
        : TemplateGenerationGateKind.allowed;
    return TemplateGenerationGate(
      kind: kind,
      balance: wallet.balance,
      isPremium: wallet.isPremium,
    );
  }

  Future<void> refreshAfterGeneration() async {
    if (isDisposed() || !canUsePrivateApi() || !hasInternet()) return;
    try {
      await loadWallet();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.GenerationController',
        operation: 'refresh_wallet_after_generation',
        message: 'Wallet refresh failed after generation state change.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
