import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_models.dart';

enum AchievementFilter { all, unlocked, inProgress, secret }

List<AchievementModel> applyAchievementFilter(
  List<AchievementModel> achievements,
  AchievementFilter filter,
) {
  switch (filter) {
    case AchievementFilter.all:
      return achievements;
    case AchievementFilter.unlocked:
      return achievements.where((item) => item.isUnlocked).toList();
    case AchievementFilter.inProgress:
      return achievements
          .where(
            (item) =>
                !item.isUnlocked &&
                (!item.isSecret || item.currentProgress > 0),
          )
          .toList();
    case AchievementFilter.secret:
      return achievements.where((item) => item.isSecret).toList();
  }
}

AchievementModel? findNextAchievement(List<AchievementModel> achievements) {
  final locked =
      achievements
          .where(
            (item) =>
                !item.isUnlocked &&
                (!item.isSecret || item.currentProgress > 0),
          )
          .toList()
        ..sort((left, right) {
          final progressDelta = right.progressPercent.compareTo(
            left.progressPercent,
          );
          if (progressDelta != 0) {
            return progressDelta;
          }

          return right.currentProgress.compareTo(left.currentProgress);
        });

  return locked.isEmpty ? null : locked.first;
}

AppUnavailableKind? classifyAchievementsUnavailable({
  required Object? error,
  required bool hasInternet,
}) {
  final raw = achievementsErrorMessage(error);
  if (raw == null) {
    return null;
  }

  return classifyAppUnavailable(raw: raw, hasInternet: hasInternet);
}

String? achievementsErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }

  if (error is AppException) {
    final message = error.message.trim();
    return message.isEmpty ? 'gamification.request_failed' : message;
  }

  if (error is String) {
    final message = error.trim();
    return message.isEmpty ? 'gamification.request_failed' : message;
  }

  return 'gamification.request_failed';
}

String mapAchievementsLoadMessage(String? raw, AppLocalizations text) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  if (authMessage != null) {
    return authMessage;
  }

  return text.gamificationLoadFailed;
}

bool isAchievementsLegalAcceptanceFailure(String? raw) {
  return isLegalAcceptanceRequiredError(raw);
}
