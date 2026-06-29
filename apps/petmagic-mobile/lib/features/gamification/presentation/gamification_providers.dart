import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';

final gamificationSummaryProvider =
    FutureProvider.autoDispose<GamificationSummaryModel>((ref) {
      ref.keepAlive();
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      return ref
          .watch(gamificationRepositoryProvider)
          .fetchSummary(cancelToken: cancelToken);
    });

final petProgressProvider = FutureProvider.autoDispose
    .family<PetProgressModel, String>((ref, petId) {
      ref.keepAlive();
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
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
  ref.keepAlive();
  final cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);
  return ref
      .watch(gamificationRepositoryProvider)
      .fetchStreak(cancelToken: cancelToken);
});

final weeklyChallengesProvider =
    FutureProvider.autoDispose<List<WeeklyChallengeModel>>((ref) {
      ref.keepAlive();
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      return ref
          .watch(gamificationRepositoryProvider)
          .fetchCurrentChallenges(cancelToken: cancelToken);
    });
