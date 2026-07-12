import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/gamification/domain/gamification_models.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  throw StateError(
    'GamificationRepository is not bound. Add the app composition overrides.',
  );
});

abstract interface class GamificationRepository {
  Future<GamificationSummaryModel> fetchSummary({CancelToken? cancelToken});
  Future<List<AchievementModel>> fetchAchievements({CancelToken? cancelToken});
}
