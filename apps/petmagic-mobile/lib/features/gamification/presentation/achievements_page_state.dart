import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
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
  if (error == null) {
    return null;
  }

  return classifyAppUnavailable(
    raw: error.toString(),
    hasInternet: hasInternet,
  );
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
