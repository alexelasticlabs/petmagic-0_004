import type { Locale } from "@/lib/i18n";

export type GenerationCapacityAlertText = {
  title: string;
  message: string;
};

type GenerationCapacityAlertLike = GenerationCapacityAlertText & {
  alertId: string;
};

export type GenerationCapacityPanelText = {
  title: string;
  description: string;
  unavailable: string;
  retry: string;
  refreshProvider: string;
  refreshingProvider: string;
  editPolicy: string;
  admissionOn: string;
  admissionOff: string;
  effectiveCapacity: string;
  providerLimit: string;
  balance: string;
  balanceUnknown: string;
  inFlight: string;
  queued: string;
  imageQueue: string;
  videoQueue: string;
  oldestQueued: string;
  noQueue: string;
  capacityUsage: string;
  nativeSlots: string;
  borrowedSlots: string;
  reservedSlots: string;
  imageInFlight: string;
  videoInFlight: string;
  preprocessingInFlight: string;
  submissionUnknown: string;
  worker: string;
  workerInstances: string;
  workerHeartbeat: string;
  workerProgress: string;
  workerRevision: string;
  schedulerMode: string;
  schedulerV2On: string;
  schedulerV2Off: string;
  lanes: string;
  dispatch: string;
  reconciliation: string;
  mediaImport: string;
  maintenance: string;
  profile: string;
  imageReserved: string;
  imageProtected: string;
  imageMax: string;
  videoReserved: string;
  videoMax: string;
  videoBorrow: string;
  videoPreprocessing: string;
  stages: string;
  noStages: string;
  alerts: string;
  checkedAt: string;
  confirmedAt: string;
  policyRevision: string;
  editTitle: string;
  editDescription: string;
  confirmedLimitLabel: string;
  confirmFalLimitLabel: string;
  confirmFalLimitRequired: string;
  reserveLabel: string;
  ceilingLabel: string;
  admissionLabel: string;
  reasonLabel: string;
  reasonPlaceholder: string;
  reasonRequired: string;
  invalidPolicy: string;
  previewTitle: string;
  previewDescription: string;
  riskyTitle: string;
  riskyDescription: string;
  riskyAcknowledge: string;
  cancel: string;
  save: string;
  saving: string;
  saved: string;
  saveError: string;
  staleConflict: string;
  staleConflictRefreshFailed: string;
  refreshConflict: string;
  refreshingConflict: string;
  snapshotRefreshFailedTitle: string;
  snapshotRefreshFailedDescription: string;
  snapshotTooOldTitle: string;
  snapshotTooOldDescription: string;
  refreshError: string;
  refreshed: string;
  refreshCoalesced: string;
  refreshFailed: string;
  notificationSource: string;
  balanceStateLabels: Record<"fresh" | "stale" | "unknown" | "low" | "critical", string>;
};

const capacityPanelText: Record<Locale, GenerationCapacityPanelText> = {
  ru: {
    title: "Capacity и fal.ai",
    description: "Очередь PetMagic, доступные provider slots и состояние единственного worker.",
    unavailable: "Состояние генерационной очереди временно недоступно.",
    retry: "Повторить",
    refreshProvider: "Обновить баланс",
    refreshingProvider: "Обновляем…",
    editPolicy: "Настроить",
    admissionOn: "Приём включён",
    admissionOff: "Приём остановлен",
    effectiveCapacity: "Рабочих slots",
    providerLimit: "Лимит fal.ai",
    balance: "Баланс fal.ai",
    balanceUnknown: "Нет данных",
    inFlight: "В работе",
    queued: "В очереди",
    imageQueue: "Image",
    videoQueue: "Video",
    oldestQueued: "Самая старая",
    noQueue: "Очередь пуста",
    capacityUsage: "Использование capacity",
    nativeSlots: "Своих slots",
    borrowedSlots: "Заимствовано",
    reservedSlots: "Свободно reserved",
    imageInFlight: "Image в работе",
    videoInFlight: "Video в работе",
    preprocessingInFlight: "Preprocessing в работе",
    submissionUnknown: "Нужна сверка provider submit",
    worker: "Worker и lanes",
    workerInstances: "Инстансы",
    workerHeartbeat: "Heartbeat",
    workerProgress: "Последний прогресс",
    workerRevision: "Применённая revision",
    schedulerMode: "Режим scheduler",
    schedulerV2On: "Scheduler V2",
    schedulerV2Off: "Compatibility loop",
    lanes: "Параллельность lanes",
    dispatch: "Dispatch",
    reconciliation: "Reconciliation",
    mediaImport: "Media import",
    maintenance: "Maintenance",
    profile: "Эффективный профиль",
    imageReserved: "Image reserved",
    imageProtected: "Image protected",
    imageMax: "Image max",
    videoReserved: "Video guaranteed",
    videoMax: "Video max",
    videoBorrow: "Video borrow",
    videoPreprocessing: "Video preprocessing",
    stages: "Очередь по стадиям",
    noStages: "Активных стадий нет.",
    alerts: "Активные предупреждения",
    checkedAt: "Проверено",
    confirmedAt: "Лимит подтверждён",
    policyRevision: "Policy revision",
    editTitle: "Настройка generation capacity",
    editDescription:
      "Лимит fal.ai вводится по данным Dashboard. Баланс не используется для автоматического вычисления concurrency.",
    confirmedLimitLabel: "Подтверждённый fal.ai concurrency limit",
    confirmFalLimitLabel:
      "Я сверил concurrency limit в fal.ai Dashboard и подтверждаю его актуальность",
    confirmFalLimitRequired:
      "Новый concurrency limit нельзя применить без явного подтверждения сверки с fal.ai Dashboard.",
    reserveLabel: "Резерв вне PetMagic",
    ceilingLabel: "Жёсткий максимум PetMagic",
    admissionLabel: "Принимать новые генерации",
    reasonLabel: "Причина изменения",
    reasonPlaceholder: "Что проверено и почему меняется capacity",
    reasonRequired: "Укажите причину изменения длиной не менее 3 символов.",
    invalidPolicy: "Лимиты должны быть целыми числами; reserve должен быть меньше fal.ai limit.",
    previewTitle: "Предпросмотр Balanced profile",
    previewDescription: "Активные задания не отменяются при уменьшении capacity.",
    riskyTitle: "Изменение затрагивает admission или доступную capacity",
    riskyDescription: "Перед применением проверьте fal.ai, очередь и активные генерации.",
    riskyAcknowledge: "Я проверил fal.ai, очередь и активные генерации и подтверждаю это изменение",
    cancel: "Отмена",
    save: "Сохранить policy",
    saving: "Сохраняем…",
    saved: "Generation capacity обновлена.",
    saveError: "Не удалось обновить generation capacity.",
    staleConflict:
      "Policy уже изменена другим администратором. Загружена новая revision; ваши значения и причина сохранены — проверьте их снова.",
    staleConflictRefreshFailed:
      "Policy конфликтует с сервером, но новую revision получить не удалось. Черновик сохранён; повторите обновление и не отправляйте его вслепую.",
    refreshConflict: "Загрузить новую revision",
    refreshingConflict: "Обновляем revision…",
    snapshotRefreshFailedTitle: "Не удалось обновить состояние generation capacity",
    snapshotRefreshFailedDescription:
      "Показан последний успешный снимок. Повторите загрузку перед изменением policy.",
    snapshotTooOldTitle: "Снимок generation capacity устарел",
    snapshotTooOldDescription:
      "Изменение policy заблокировано до успешного обновления состояния очереди и worker.",
    refreshError: "Не удалось обновить состояние fal.ai.",
    refreshed: "Состояние fal.ai обновлено.",
    refreshCoalesced: "Обновление уже выполнялось; показан самый свежий доступный снимок fal.ai.",
    refreshFailed: "fal.ai не подтвердил обновление; показан последний безопасный снимок.",
    notificationSource: "Generation capacity",
    balanceStateLabels: {
      fresh: "Актуально",
      stale: "Устарело",
      unknown: "Нет данных",
      low: "Низкий баланс",
      critical: "Критический баланс",
    },
  },
  en: {
    title: "Capacity and fal.ai",
    description: "PetMagic queue, available provider slots, and the single worker state.",
    unavailable: "Generation capacity is temporarily unavailable.",
    retry: "Retry",
    refreshProvider: "Refresh balance",
    refreshingProvider: "Refreshing…",
    editPolicy: "Configure",
    admissionOn: "Admission enabled",
    admissionOff: "Admission paused",
    effectiveCapacity: "Usable slots",
    providerLimit: "fal.ai limit",
    balance: "fal.ai balance",
    balanceUnknown: "No data",
    inFlight: "In flight",
    queued: "Queued",
    imageQueue: "Image",
    videoQueue: "Video",
    oldestQueued: "Oldest",
    noQueue: "Queue is empty",
    capacityUsage: "Capacity usage",
    nativeSlots: "Native slots",
    borrowedSlots: "Borrowed",
    reservedSlots: "Reserved available",
    imageInFlight: "Image in flight",
    videoInFlight: "Video in flight",
    preprocessingInFlight: "Preprocessing in flight",
    submissionUnknown: "Provider submits to reconcile",
    worker: "Worker and lanes",
    workerInstances: "Instances",
    workerHeartbeat: "Heartbeat",
    workerProgress: "Last progress",
    workerRevision: "Applied revision",
    schedulerMode: "Scheduler mode",
    schedulerV2On: "Scheduler V2",
    schedulerV2Off: "Compatibility loop",
    lanes: "Lane concurrency",
    dispatch: "Dispatch",
    reconciliation: "Reconciliation",
    mediaImport: "Media import",
    maintenance: "Maintenance",
    profile: "Effective profile",
    imageReserved: "Image reserved",
    imageProtected: "Image protected",
    imageMax: "Image max",
    videoReserved: "Video guaranteed",
    videoMax: "Video max",
    videoBorrow: "Video borrow",
    videoPreprocessing: "Video preprocessing",
    stages: "Queue by stage",
    noStages: "No active stages.",
    alerts: "Active alerts",
    checkedAt: "Checked",
    confirmedAt: "Limit confirmed",
    policyRevision: "Policy revision",
    editTitle: "Configure generation capacity",
    editDescription:
      "Enter the fal.ai limit shown in its Dashboard. The credit balance does not determine concurrency automatically.",
    confirmedLimitLabel: "Confirmed fal.ai concurrency limit",
    confirmFalLimitLabel:
      "I checked the concurrency limit in the fal.ai Dashboard and confirm it is current",
    confirmFalLimitRequired:
      "A new concurrency limit cannot be applied without explicitly confirming the fal.ai Dashboard value.",
    reserveLabel: "Capacity reserved outside PetMagic",
    ceilingLabel: "PetMagic hard ceiling",
    admissionLabel: "Accept new generations",
    reasonLabel: "Change reason",
    reasonPlaceholder: "What was verified and why capacity is changing",
    reasonRequired: "Provide a change reason of at least 3 characters.",
    invalidPolicy: "Limits must be whole numbers and reserve must be lower than the fal.ai limit.",
    previewTitle: "Balanced profile preview",
    previewDescription: "Lowering capacity never cancels active jobs.",
    riskyTitle: "This change affects admission or available capacity",
    riskyDescription: "Review fal.ai, the queue, and active generations before applying it.",
    riskyAcknowledge:
      "I reviewed fal.ai, the queue, and active generations and confirm this change",
    cancel: "Cancel",
    save: "Save policy",
    saving: "Saving…",
    saved: "Generation capacity was updated.",
    saveError: "Failed to update generation capacity.",
    staleConflict:
      "Another administrator changed this policy. The latest revision was loaded; your values and reason were preserved for review.",
    staleConflictRefreshFailed:
      "The policy conflicts with the server, but a newer revision could not be loaded. Your draft is preserved; refresh it before retrying.",
    refreshConflict: "Load latest revision",
    refreshingConflict: "Loading revision…",
    snapshotRefreshFailedTitle: "Generation capacity refresh failed",
    snapshotRefreshFailedDescription:
      "The last successful snapshot is shown. Refresh it before changing the policy.",
    snapshotTooOldTitle: "Generation capacity snapshot is stale",
    snapshotTooOldDescription:
      "Policy changes are blocked until the queue and worker state refresh successfully.",
    refreshError: "Failed to refresh the fal.ai state.",
    refreshed: "fal.ai state was refreshed.",
    refreshCoalesced:
      "A refresh was already running; the freshest available fal.ai snapshot is shown.",
    refreshFailed: "fal.ai did not confirm the refresh; the last safe snapshot is still shown.",
    notificationSource: "Generation capacity",
    balanceStateLabels: {
      fresh: "Fresh",
      stale: "Stale",
      unknown: "Unknown",
      low: "Low balance",
      critical: "Critical balance",
    },
  },
};

const capacityAlertText: Record<Locale, Record<string, GenerationCapacityAlertText>> = {
  ru: {
    "generation-scheduler-v2-disabled": {
      title: "Scheduler V2 отключён",
      message:
        "Worker продолжает работать в compatibility loop, пока rollout-флаг не будет включён.",
    },
    "generation-admission-paused": {
      title: "Приём генераций остановлен",
      message: "Новые запросы на генерацию сейчас не принимаются.",
    },
    "fal-concurrency-confirmation-stale": {
      title: "Лимит concurrency fal.ai давно не подтверждался",
      message: "Подтвердите актуальный concurrency limit в fal.ai Dashboard.",
    },
    "generation-effective-capacity-zero": {
      title: "Рабочая capacity генераций равна нулю",
      message: "Зарезервированный headroom не оставляет fal.ai capacity для PetMagic.",
    },
    "fal-balance-critical": {
      title: "Критический баланс fal.ai",
      message: "Новые отправки в provider должны оставаться остановленными до пополнения баланса.",
    },
    "fal-balance-low": {
      title: "Низкий баланс fal.ai",
      message: "Пополните баланс provider до достижения критического порога.",
    },
    "fal-balance-stale": {
      title: "Данные о балансе fal.ai устарели",
      message: "Последний известный баланс пока находится в пределах пятиминутного safety window.",
    },
    "fal-balance-unknown": {
      title: "Баланс fal.ai неизвестен",
      message: "Нет актуального снимка баланса provider, пригодного для безопасной работы.",
    },
    "generation-worker-fingerprint-mismatch": {
      title: "Конфигурация generation worker не совпадает",
      message: "Generation worker запущен не с ожидаемой конфигурацией scheduler.",
    },
    "generation-worker-instance-count-unexpected": {
      title: "Запущено больше одного generation worker",
      message:
        "Архитектура рассчитана на один Render worker. Проверьте Blueprint, Dashboard scaling и активные инстансы.",
    },
    "generation-worker-runtime-config-unknown": {
      title: "Runtime-конфигурация generation worker неизвестна",
      message: "Активные worker не сообщили единую конфигурацию Scheduler V2 и bounded lanes.",
    },
    "generation-worker-policy-revision-stale": {
      title: "Generation worker применил устаревшую policy",
      message:
        "Дождитесь heartbeat с текущей revision или остановите rollout и проверьте worker logs.",
    },
    "generation-worker-heartbeat-missing": {
      title: "Нет heartbeat generation worker",
      message: "За последние две минуты ни один исправный generation worker не вышел на связь.",
    },
    "generation-provider-submission-unknown": {
      title: "Нужна сверка отправок в fal.ai",
      message:
        "Неоднозначные provider submits занимают capacity. Разрешите их только по подтверждённым данным fal.ai.",
    },
    "generation-provider-webhook-dead-letter": {
      title: "Webhook провайдера требует вмешательства",
      message:
        "Событие исчерпало автоматические попытки reconciliation и перемещено в dead-letter. Проверьте worker logs и состояние provider attempt.",
    },
  },
  en: {
    "generation-scheduler-v2-disabled": {
      title: "Scheduler V2 is disabled",
      message: "The worker is using the compatibility loop until the rollout flag is enabled.",
    },
    "generation-admission-paused": {
      title: "Generation admission is paused",
      message: "New generation requests are not being admitted.",
    },
    "fal-concurrency-confirmation-stale": {
      title: "fal.ai concurrency confirmation is stale",
      message: "Confirm the current fal.ai concurrency limit in the provider dashboard.",
    },
    "generation-effective-capacity-zero": {
      title: "Effective generation capacity is zero",
      message: "Reserved headroom leaves no provider capacity for PetMagic.",
    },
    "fal-balance-critical": {
      title: "fal.ai balance is critical",
      message: "New provider submissions must remain paused until the balance is replenished.",
    },
    "fal-balance-low": {
      title: "fal.ai balance is low",
      message: "Replenish the provider balance before it reaches the critical threshold.",
    },
    "fal-balance-stale": {
      title: "fal.ai balance is stale",
      message: "The last known balance is still within the five-minute safety window.",
    },
    "fal-balance-unknown": {
      title: "fal.ai balance is unknown",
      message: "Provider balance has no usable recent snapshot.",
    },
    "generation-worker-fingerprint-mismatch": {
      title: "Generation worker configuration mismatch",
      message: "The generation worker is not running with the expected scheduler configuration.",
    },
    "generation-worker-instance-count-unexpected": {
      title: "More than one generation worker is active",
      message:
        "This architecture expects one Render worker. Review the Blueprint, Dashboard scaling, and active instances.",
    },
    "generation-worker-runtime-config-unknown": {
      title: "Generation worker runtime configuration is unknown",
      message:
        "Active workers have not reported one consistent Scheduler V2 and bounded-lane configuration.",
    },
    "generation-worker-policy-revision-stale": {
      title: "Generation worker policy revision is stale",
      message:
        "Wait for a heartbeat with the current revision or stop rollout and inspect worker logs.",
    },
    "generation-worker-heartbeat-missing": {
      title: "Generation worker heartbeat is missing",
      message: "No healthy generation worker reported during the last two minutes.",
    },
    "generation-provider-submission-unknown": {
      title: "fal.ai submissions require reconciliation",
      message:
        "Ambiguous provider submits occupy capacity. Resolve them only with confirmed fal.ai evidence.",
    },
    "generation-provider-webhook-dead-letter": {
      title: "Provider webhook requires intervention",
      message:
        "An event exhausted automatic reconciliation retries and was dead-lettered. Review worker logs and the provider attempt state.",
    },
  },
};

export function getGenerationCapacityPanelText(locale: Locale): GenerationCapacityPanelText {
  return capacityPanelText[locale];
}

export function getGenerationCapacityAlertText(
  locale: Locale,
  alert: GenerationCapacityAlertLike
): GenerationCapacityAlertText {
  return (
    capacityAlertText[locale][alert.alertId] ?? {
      title: alert.title,
      message: alert.message,
    }
  );
}
