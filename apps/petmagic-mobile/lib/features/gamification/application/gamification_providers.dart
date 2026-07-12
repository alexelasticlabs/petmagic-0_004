import 'dart:async';

// Public gamification application providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/application/gamification_repository.dart';

const _gamificationProviderCacheTtl = Duration(minutes: 5);

final gamificationSummaryProvider =
    FutureProvider.autoDispose<GamificationSummaryModel>((ref) {
      if (!ref.watch(_canLoadPrivateGamificationProvider)) {
        throw const AppException('auth.session_expired');
      }

      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        throw const AppException('gamification.network_unavailable');
      }

      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer?.cancel();
        disposeTimer = Timer(_gamificationProviderCacheTtl, link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      final cancellation = RequestCancellation();
      ref.onDispose(() {
        disposeTimer?.cancel();
        if (!cancellation.isCancelled) {
          cancellation.cancel('gamification_summary_provider_disposed');
        }
      });
      return ref
          .watch(gamificationRepositoryProvider)
          .fetchSummary(cancellation: cancellation);
    });

final achievementsProvider = FutureProvider.autoDispose<List<AchievementModel>>(
  (ref) {
    if (!ref.watch(_canLoadPrivateGamificationProvider)) {
      throw const AppException('auth.session_expired');
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      throw const AppException('gamification.network_unavailable');
    }

    final link = ref.keepAlive();
    Timer? disposeTimer;
    ref.onCancel(() {
      disposeTimer?.cancel();
      disposeTimer = Timer(_gamificationProviderCacheTtl, link.close);
    });
    ref.onResume(() {
      disposeTimer?.cancel();
      disposeTimer = null;
    });
    final cancellation = RequestCancellation();
    ref.onDispose(() {
      disposeTimer?.cancel();
      if (!cancellation.isCancelled) {
        cancellation.cancel('achievements_provider_disposed');
      }
    });
    return ref
        .watch(gamificationRepositoryProvider)
        .fetchAchievements(cancellation: cancellation);
  },
);

final _canLoadPrivateGamificationProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    appLaunchControllerProvider.select((state) => state.isAuthenticated),
  );
});
