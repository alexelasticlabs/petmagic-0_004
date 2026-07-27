import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/app_media_cache_manager.dart';
import 'package:petmagic_mobile/app/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/session/session_epoch.dart';
import 'package:petmagic_mobile/features/gamification/application/gamification_providers.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/features/pets/application/pet_profile_providers.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_store_purchase_recovery_store.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/payments/store_product_availability_cache.dart';

typedef SessionMediaCacheCleaner = Future<void> Function();

final sessionMediaCacheCleanerProvider = Provider<SessionMediaCacheCleaner>((
  ref,
) {
  return _clearSessionMediaCaches;
});

final sessionScopeResetProvider = Provider<void>((ref) {
  ref.listen<AppLaunchState>(appLaunchControllerProvider, (previous, next) {
    final authChanged = previous?.isAuthenticated != next.isAuthenticated;
    final completedSignedOutStartup =
        previous?.isLoading == true && !next.isLoading && !next.isAuthenticated;
    if (!authChanged && !completedSignedOutStartup) {
      return;
    }

    Future.microtask(() {
      if (!ref.mounted) {
        return;
      }

      ref.read(sessionEpochProvider.notifier).advance();
      ref.invalidate(templateGenerationRepositoryProvider);
      ref.invalidate(walletControllerProvider);
      ref.invalidate(templatesControllerProvider);
      ref.invalidate(generationHistoryControllerProvider);
      ref.invalidate(templateGenerationControllerProvider);
      ref.invalidate(premiumControllerProvider);
      ref.invalidate(premiumSubscriptionSummaryProvider);
      ref.invalidate(linkedAccountsProvider);
      ref.invalidate(profileControllerProvider);
      ref.invalidate(supportChatControllerProvider);
      ref.invalidate(supportChatRealtimeClientProvider);
      ref.invalidate(petsProvider);
      ref.invalidate(petPhotosProvider);
      ref.invalidate(petGenerationsProvider);
      ref.invalidate(gamificationSummaryProvider);
      ref.invalidate(achievementsProvider);
    });

    if (!next.isAuthenticated) {
      unawaited(
        Future.wait<void>([
          _runBestEffortCleanup(
            'template_generation_cache',
            () => ref
                .read(templateGenerationRepositoryProvider)
                .clearLocalCache(),
          ),
          _runBestEffortCleanup(
            'generation_gallery_downloads',
            () => ref
                .read(generationGalleryStoreProvider)
                .cancelActiveDownloads(),
          ),
          _runBestEffortCleanup(
            'generation_gallery_scopes',
            () => ref.read(generationGalleryStoreProvider).purgeAllScopes(),
          ),
          _runBestEffortCleanup(
            'wallet_store_purchase_recovery_state',
            () => ref
                .read(walletStorePurchaseRecoveryStoreProvider)
                .clearPendingPurchase(),
          ),
          _runBestEffortCleanup(
            'push_token_registration_state',
            PushTokenRegistrar.clearRegistrationState,
          ),
          _runBestEffortCleanup('store_product_availability_cache', () async {
            sharedStoreProductAvailabilityCache.clear();
          }),
          _runBestEffortCleanup(
            'session_media_caches',
            () => ref.read(sessionMediaCacheCleanerProvider)(),
          ),
        ]),
      );
    }
  });
});

Future<void> _clearSessionMediaCaches() async {
  await _runBestEffortCleanup('media_caches', AppMediaCacheManager.clearAll);
}

Future<void> _runBestEffortCleanup(
  String stage,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error, stackTrace) {
    AppLogger.warn(
      feature: 'Startup.SessionCleanup',
      operation: stage,
      message: 'Session cleanup step failed',
      context: {'stage': stage},
      error: error,
      stackTrace: stackTrace,
    );
  }
}
