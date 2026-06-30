import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/notifications/push_token_registrar.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_profile_providers.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

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
      ref.invalidate(petProgressProvider);
      ref.invalidate(achievementsProvider);
      ref.invalidate(dailyStreakProvider);
      ref.invalidate(weeklyChallengesProvider);
    });

    if (!next.isAuthenticated) {
      final templateGenerationRepository = ref.read(
        templateGenerationRepositoryProvider,
      );
      final generationGalleryStore = ref.read(generationGalleryStoreProvider);
      final clearMediaCaches = ref.read(sessionMediaCacheCleanerProvider);
      unawaited(
        Future.wait<void>([
          templateGenerationRepository.clearLocalCache(),
          generationGalleryStore.cancelActiveDownloads(),
          generationGalleryStore.purgeAllScopes(),
          _runBestEffortCleanup(
            'push_token_registration_state',
            PushTokenRegistrar.clearRegistrationState,
          ),
          clearMediaCaches(),
        ]),
      );
    }
  });
});

Future<void> _clearSessionMediaCaches() async {
  await Future.wait<void>([
    _runBestEffortCleanup('template_media_cache', TemplateMediaCache.clearAll),
    _runBestEffortCleanup('default_image_cache', () async {
      await DefaultCacheManager().emptyCache();
      imageCache.clear();
      imageCache.clearLiveImages();
    }),
  ]);
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
