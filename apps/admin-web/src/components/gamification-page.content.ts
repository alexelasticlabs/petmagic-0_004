import { type Locale } from "@/lib/i18n";

export type GamificationPageText = {
  workspaceEyebrow: string;
  workspaceTitle: string;
  description: string;
  refreshAction: string;
  refreshingAction: string;
  lastUpdatedLabel: string;
  loadingTitle: string;
  loadingDescription: string;
  errorTitle: string;
  errorDescription: string;
  retryAction: string;
  partialErrorTitle: string;
  metricsRegionLabel: string;
  usersWithProgressLabel: string;
  usersWithProgressHint: string;
  activeStreaksLabel: string;
  activeStreaksHint: string;
  achievementsUnlockedLabel: string;
  achievementDefinitionsHint: string;
  challengeCompletionsLabel: string;
  challengeParticipantsHint: string;
  challengesTitle: string;
  challengesDescription: string;
  challengeColumn: string;
  targetColumn: string;
  participantsColumn: string;
  completedColumn: string;
  completionColumn: string;
  tableScrollHint: string;
  noChallengesTitle: string;
  noChallengesDescription: string;
  achievementsTitle: string;
  achievementsDescription: string;
  achievementColumn: string;
  categoryColumn: string;
  rarityColumn: string;
  requirementColumn: string;
  rewardColumn: string;
  unlockedColumn: string;
  secretLabel: string;
  noAchievementsTitle: string;
  noAchievementsDescription: string;
  diagnosticsTitle: string;
  diagnosticsDescription: string;
  userIdLabel: string;
  userIdPlaceholder: string;
  searchAction: string;
  searchingAction: string;
  invalidUserId: string;
  lookupPrompt: string;
  lookupError: string;
  noUsersFound: string;
  openUser360Action: string;
  versionLabel: string;
  historyTitle: string;
  historyDescription: string;
  noHistory: string;
  historyStreakLabel: string;
  historyAchievementLabel: string;
  historyChallengeLabel: string;
  historyCreditedLabel: string;
  historyPendingLabel: string;
  historyNoRewardLabel: string;
  historyInProgressLabel: string;
  historyRecordedLabel: string;
  streakTitle: string;
  currentStreakLabel: string;
  longestStreakLabel: string;
  freezesLabel: string;
  lastActiveLabel: string;
  noStreakLabel: string;
  diagnosticsEmptyStreakDescription: string;
  petsLabel: string;
  userAchievementsLabel: string;
  userChallengesLabel: string;
  resetStreakAction: string;
  resetDialogTitle: string;
  resetDialogDescription: string;
  reasonLabel: string;
  dialogReasonLabel: string;
  reasonPlaceholder: string;
  reasonHint: string;
  reasonRequired: string;
  reasonTooLong: string;
  confirmResetAction: string;
  cancelAction: string;
  resetSuccess: string;
  resetError: string;
  yesLabel: string;
  noLabel: string;
  dayUnit: string;
  sparkUnit: string;
};

const gamificationPageText: Record<Locale, GamificationPageText> = {
  ru: {
    workspaceEyebrow: "Вовлечение",
    workspaceTitle: "Gamification",
    description:
      "Контроль прогресса пользователей, серий активности, достижений и текущих недельных испытаний.",
    refreshAction: "Обновить",
    refreshingAction: "Обновляем...",
    lastUpdatedLabel: "Последнее обновление",
    loadingTitle: "Загрузка Gamification",
    loadingDescription: "Получаем актуальные метрики, испытания и определения достижений.",
    errorTitle: "Не удалось загрузить Gamification",
    errorDescription: "Данные временно недоступны. Повторите запрос.",
    retryAction: "Повторить",
    partialErrorTitle: "Часть данных Gamification временно недоступна",
    metricsRegionLabel: "Ключевые метрики Gamification",
    usersWithProgressLabel: "Пользователи с прогрессом",
    usersWithProgressHint: "Питомцев с отслеживаемым прогрессом",
    activeStreaksLabel: "Активные серии",
    activeStreaksHint: "Пользователи с текущей серией ежедневной активности",
    achievementsUnlockedLabel: "Открыто достижений",
    achievementDefinitionsHint: "Доступные определения достижений",
    challengeCompletionsLabel: "Завершено испытаний",
    challengeParticipantsHint: "Участники текущих недельных испытаний",
    challengesTitle: "Текущие испытания",
    challengesDescription:
      "Фактическое участие и выполнение испытаний активной календарной недели.",
    challengeColumn: "Испытание",
    targetColumn: "Цель",
    participantsColumn: "Участники",
    completedColumn: "Завершили",
    completionColumn: "Выполнение",
    tableScrollHint: "Прокрутите таблицу по горизонтали, чтобы увидеть все столбцы.",
    noChallengesTitle: "Текущих испытаний нет",
    noChallengesDescription: "API не вернул испытания для активной недели.",
    achievementsTitle: "Определения достижений",
    achievementsDescription:
      "Настроенные определения, требования, награды и фактическое число открытий.",
    achievementColumn: "Достижение",
    categoryColumn: "Категория",
    rarityColumn: "Редкость",
    requirementColumn: "Требование",
    rewardColumn: "Награда",
    unlockedColumn: "Открыли",
    secretLabel: "Скрытое",
    noAchievementsTitle: "Определений достижений нет",
    noAchievementsDescription: "API не вернул ни одного определения достижения.",
    diagnosticsTitle: "Диагностика пользователя",
    diagnosticsDescription:
      "Найдите пользователя по имени или email и проверьте его серию, прогресс питомцев, достижения и испытания.",
    userIdLabel: "Поиск пользователя",
    userIdPlaceholder: "Имя или email",
    searchAction: "Найти",
    searchingAction: "Ищем...",
    invalidUserId: "Введите минимум 2 символа имени или email.",
    lookupPrompt: "Найдите и выберите пользователя, чтобы загрузить его Gamification-профиль.",
    lookupError: "Не удалось загрузить Gamification-профиль пользователя.",
    noUsersFound: "Пользователи по этому запросу не найдены.",
    openUser360Action: "Открыть User 360",
    versionLabel: "Версия",
    historyTitle: "История прогресса и наград",
    historyDescription:
      "Последние дни активности, достижения и испытания с состоянием начисления награды.",
    noHistory: "История Gamification для пользователя пока пуста.",
    historyStreakLabel: "День серии",
    historyAchievementLabel: "Достижение",
    historyChallengeLabel: "Испытание",
    historyCreditedLabel: "Награда начислена",
    historyPendingLabel: "Начисление ожидается",
    historyNoRewardLabel: "Без награды",
    historyInProgressLabel: "В процессе",
    historyRecordedLabel: "Активность зафиксирована",
    streakTitle: "Серия активности",
    currentStreakLabel: "Текущая серия",
    longestStreakLabel: "Лучшая серия",
    freezesLabel: "Доступно заморозок",
    lastActiveLabel: "Последняя активность",
    noStreakLabel: "Серия не создана",
    diagnosticsEmptyStreakDescription:
      "У пользователя нет записи ежедневной серии; сброс недоступен.",
    petsLabel: "Прогресс питомцев",
    userAchievementsLabel: "Достижения пользователя",
    userChallengesLabel: "Испытания пользователя",
    resetStreakAction: "Сбросить серию",
    resetDialogTitle: "Сбросить серию пользователя?",
    resetDialogDescription:
      "Запись ежедневной серии будет удалена. Действие необратимо и сохраняется в audit log.",
    reasonLabel: "Причина аудита",
    dialogReasonLabel: "Причина сброса серии",
    reasonPlaceholder: "Опишите проверенную причину сброса",
    reasonHint: "Обязательно, от 1 до 500 символов.",
    reasonRequired: "Укажите причину сброса.",
    reasonTooLong: "Причина не должна превышать 500 символов.",
    confirmResetAction: "Подтвердить сброс",
    cancelAction: "Отмена",
    resetSuccess: "Серия пользователя сброшена.",
    resetError: "Не удалось сбросить серию пользователя.",
    yesLabel: "Да",
    noLabel: "Нет",
    dayUnit: "дн.",
    sparkUnit: "PawSpark",
  },
  en: {
    workspaceEyebrow: "Engagement",
    workspaceTitle: "Gamification",
    description:
      "Monitor user progress, activity streaks, achievements, and current weekly challenges.",
    refreshAction: "Refresh",
    refreshingAction: "Refreshing...",
    lastUpdatedLabel: "Last updated",
    loadingTitle: "Loading Gamification",
    loadingDescription: "Fetching current metrics, challenges, and achievement definitions.",
    errorTitle: "Failed to load Gamification",
    errorDescription: "The data is temporarily unavailable. Retry the request.",
    retryAction: "Retry",
    partialErrorTitle: "Some Gamification data is temporarily unavailable",
    metricsRegionLabel: "Key Gamification metrics",
    usersWithProgressLabel: "Users with progress",
    usersWithProgressHint: "Pets with tracked progress",
    activeStreaksLabel: "Active streaks",
    activeStreaksHint: "Users with a current daily activity streak",
    achievementsUnlockedLabel: "Achievements unlocked",
    achievementDefinitionsHint: "Available achievement definitions",
    challengeCompletionsLabel: "Challenge completions",
    challengeParticipantsHint: "Participants in current weekly challenges",
    challengesTitle: "Current challenges",
    challengesDescription:
      "Actual participation and completion for challenges in the active calendar week.",
    challengeColumn: "Challenge",
    targetColumn: "Target",
    participantsColumn: "Participants",
    completedColumn: "Completed",
    completionColumn: "Completion",
    tableScrollHint: "Scroll the table horizontally to view all columns.",
    noChallengesTitle: "No current challenges",
    noChallengesDescription: "The API returned no challenges for the active week.",
    achievementsTitle: "Achievement definitions",
    achievementsDescription:
      "Configured definitions, requirements, rewards, and actual unlock counts.",
    achievementColumn: "Achievement",
    categoryColumn: "Category",
    rarityColumn: "Rarity",
    requirementColumn: "Requirement",
    rewardColumn: "Reward",
    unlockedColumn: "Unlocked by",
    secretLabel: "Secret",
    noAchievementsTitle: "No achievement definitions",
    noAchievementsDescription: "The API returned no achievement definitions.",
    diagnosticsTitle: "User diagnostics",
    diagnosticsDescription:
      "Find a user by name or email and inspect streaks, pet progress, achievements, and challenges.",
    userIdLabel: "User search",
    userIdPlaceholder: "Name or email",
    searchAction: "Search",
    searchingAction: "Searching...",
    invalidUserId: "Enter at least 2 characters of a name or email.",
    lookupPrompt: "Find and select a user to load their Gamification profile.",
    lookupError: "Failed to load the user's Gamification profile.",
    noUsersFound: "No users matched this search.",
    openUser360Action: "Open User 360",
    versionLabel: "Version",
    historyTitle: "Progress and reward history",
    historyDescription:
      "Recent activity days, achievements, and challenges with their reward settlement state.",
    noHistory: "This user has no Gamification history yet.",
    historyStreakLabel: "Streak day",
    historyAchievementLabel: "Achievement",
    historyChallengeLabel: "Challenge",
    historyCreditedLabel: "Reward credited",
    historyPendingLabel: "Credit pending",
    historyNoRewardLabel: "No reward",
    historyInProgressLabel: "In progress",
    historyRecordedLabel: "Activity recorded",
    streakTitle: "Activity streak",
    currentStreakLabel: "Current streak",
    longestStreakLabel: "Longest streak",
    freezesLabel: "Freezes available",
    lastActiveLabel: "Last active",
    noStreakLabel: "No streak record",
    diagnosticsEmptyStreakDescription:
      "This user has no daily streak record, so reset is unavailable.",
    petsLabel: "Pet progress",
    userAchievementsLabel: "User achievements",
    userChallengesLabel: "User challenges",
    resetStreakAction: "Reset streak",
    resetDialogTitle: "Reset this user's streak?",
    resetDialogDescription:
      "The daily streak record will be deleted. This action cannot be undone and is written to the audit log.",
    reasonLabel: "Audit reason",
    dialogReasonLabel: "Streak reset reason",
    reasonPlaceholder: "Describe the verified reason for this reset",
    reasonHint: "Required, from 1 to 500 characters.",
    reasonRequired: "Provide a reset reason.",
    reasonTooLong: "The reason must not exceed 500 characters.",
    confirmResetAction: "Confirm reset",
    cancelAction: "Cancel",
    resetSuccess: "The user's streak was reset.",
    resetError: "Failed to reset the user's streak.",
    yesLabel: "Yes",
    noLabel: "No",
    dayUnit: "days",
    sparkUnit: "PawSpark",
  },
};

export function getGamificationText(locale: Locale): GamificationPageText {
  return gamificationPageText[locale];
}
