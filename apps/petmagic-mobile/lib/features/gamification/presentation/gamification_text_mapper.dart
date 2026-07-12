import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';

String mapAchievementsLoadMessage(String? raw, AppLocalizations text) {
  final authMessage = mapCommonAuthFeedbackMessage(text, raw);
  return authMessage ?? text.gamificationLoadFailed;
}

String localizeAchievementTitle(AppLocalizations text, String key) {
  switch (key) {
    case 'achievementFirstMagic':
      return text.achievementFirstMagic;
    case 'achievementApprentice10':
      return text.achievementApprentice10;
    case 'achievementMagician100':
      return text.achievementMagician100;
    case 'achievementArchmage500':
      return text.achievementArchmage500;
    case 'achievementStreak3':
      return text.achievementStreak3;
    case 'achievementStreak7':
      return text.achievementStreak7;
    case 'achievementStreak14':
      return text.achievementStreak14;
    case 'achievementStreak30':
      return text.achievementStreak30;
    case 'achievementPackLeader':
      return text.achievementPackLeader;
    case 'achievementEvolutionBaby':
      return text.achievementEvolutionBaby;
    case 'achievementEvolutionLegendary':
      return text.achievementEvolutionLegendary;
    case 'achievementTrendsetter':
      return text.achievementTrendsetter;
    case 'achievementDailyRitual':
      return text.achievementDailyRitual;
    case 'achievementTemplateCollector':
      return text.achievementTemplateCollector;
    case 'achievementNightOwl':
      return text.achievementNightOwl;
    default:
      return key;
  }
}

String localizeAchievementDescription(AppLocalizations text, String key) {
  switch (key) {
    case 'achievementFirstMagicDesc':
      return text.achievementFirstMagicDesc;
    case 'achievementApprentice10Desc':
      return text.achievementApprentice10Desc;
    case 'achievementMagician100Desc':
      return text.achievementMagician100Desc;
    case 'achievementArchmage500Desc':
      return text.achievementArchmage500Desc;
    case 'achievementStreak3Desc':
      return text.achievementStreak3Desc;
    case 'achievementStreak7Desc':
      return text.achievementStreak7Desc;
    case 'achievementStreak14Desc':
      return text.achievementStreak14Desc;
    case 'achievementStreak30Desc':
      return text.achievementStreak30Desc;
    case 'achievementPackLeaderDesc':
      return text.achievementPackLeaderDesc;
    case 'achievementEvolutionBabyDesc':
      return text.achievementEvolutionBabyDesc;
    case 'achievementEvolutionLegendaryDesc':
      return text.achievementEvolutionLegendaryDesc;
    case 'achievementTrendsetterDesc':
      return text.achievementTrendsetterDesc;
    case 'achievementDailyRitualDesc':
      return text.achievementDailyRitualDesc;
    case 'achievementTemplateCollectorDesc':
      return text.achievementTemplateCollectorDesc;
    case 'achievementNightOwlDesc':
      return text.achievementNightOwlDesc;
    default:
      return key;
  }
}

String localizeChallengeTitle(AppLocalizations text, String key) {
  switch (key) {
    case 'gamificationChallengeGenerateImages':
      return text.gamificationChallengeGenerateImages;
    case 'gamificationChallengeTryTemplates':
      return text.gamificationChallengeTryTemplates;
    case 'gamificationChallengeShareCreations':
      return text.gamificationChallengeShareCreations;
    default:
      return key;
  }
}

String localizeChallengeDescription(AppLocalizations text, String key) {
  switch (key) {
    case 'gamificationChallengeGenerateImagesDesc':
      return text.gamificationChallengeGenerateImagesDesc;
    case 'gamificationChallengeTryTemplatesDesc':
      return text.gamificationChallengeTryTemplatesDesc;
    case 'gamificationChallengeShareCreationsDesc':
      return text.gamificationChallengeShareCreationsDesc;
    default:
      return key;
  }
}
