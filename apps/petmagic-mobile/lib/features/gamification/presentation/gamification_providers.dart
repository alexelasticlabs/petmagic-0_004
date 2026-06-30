import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';

const _gamificationProviderCacheTtl = Duration(minutes: 5);

final gamificationSummaryProvider =
    FutureProvider.autoDispose<GamificationSummaryModel>((ref) {
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

final petProgressProvider = FutureProvider.autoDispose
    .family<PetProgressModel, String>((ref, petId) {
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
          cancelToken.cancel('pet_progress_provider_disposed');
        }
      });
      return ref
          .watch(gamificationRepositoryProvider)
          .fetchPetProgress(petId, cancelToken: cancelToken);
    });

final achievementsProvider = FutureProvider.autoDispose<List<AchievementModel>>(
  (ref) {
    final cancelToken = CancelToken();
    ref.onDispose(cancelToken.cancel);
    return ref
        .watch(gamificationRepositoryProvider)
        .fetchAchievements(cancelToken: cancelToken);
  },
);

final dailyStreakProvider = FutureProvider.autoDispose<StreakModel?>((ref) {
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
      cancelToken.cancel('daily_streak_provider_disposed');
    }
  });
  return ref
      .watch(gamificationRepositoryProvider)
      .fetchStreak(cancelToken: cancelToken);
});

final weeklyChallengesProvider =
    FutureProvider.autoDispose<List<WeeklyChallengeModel>>((ref) {
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
          cancelToken.cancel('weekly_challenges_provider_disposed');
        }
      });
      return ref
          .watch(gamificationRepositoryProvider)
          .fetchCurrentChallenges(cancelToken: cancelToken);
    });
