import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';

const _gamificationProviderCacheTtl = Duration(minutes: 5);

final gamificationSummaryProvider =
    FutureProvider.autoDispose<GamificationSummaryModel>((ref) {
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
      final cancelToken = CancelToken();
      ref.onDispose(() {
        disposeTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('gamification_summary_provider_disposed');
        }
      });
      return ref
          .watch(gamificationRepositoryProvider)
          .fetchSummary(cancelToken: cancelToken);
    });

final achievementsProvider = FutureProvider.autoDispose<List<AchievementModel>>(
  (ref) {
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
    final cancelToken = CancelToken();
    ref.onDispose(() {
      disposeTimer?.cancel();
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('achievements_provider_disposed');
      }
    });
    return ref
        .watch(gamificationRepositoryProvider)
        .fetchAchievements(cancelToken: cancelToken);
  },
);
