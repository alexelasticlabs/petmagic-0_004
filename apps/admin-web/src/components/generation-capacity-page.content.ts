import type { Locale } from "@/lib/i18n";

export type GenerationCapacityCopy = {
  eyebrow: string;
  title: string;
  description: string;
  adminOnly: string;
  live: string;
  refresh: string;
  retry: string;
  loadingTitle: string;
  errorTitle: string;
  noData: string;
  health: Record<string, string>;
  queue: {
    title: string;
    description: string;
    activeGlobal: string;
    activeImage: string;
    activeVideo: string;
    queuedImage: string;
    queuedVideo: string;
    effectiveImage: string;
    borrowedVideo: string;
    draining: string;
  };
  fal: {
    title: string;
    description: string;
    balance: string;
    usable: string;
    inflight: string;
    reserve: string;
    checked: string;
    stale: string;
    manualLimit: string;
    refresh: string;
    refreshing: string;
  };
  workers: {
    title: string;
    description: string;
    instance: string;
    loops: string;
    revision: string;
    heartbeat: string;
    current: string;
    stale: string;
    draining: string;
    empty: string;
    totalCapacity: string;
    paidUnusedCapacity: string;
    expectedTopology: string;
    observedTopology: string;
  };
  settings: {
    title: string;
    description: string;
    saveReview: string;
    saving: string;
    noChanges: string;
    conflictTitle: string;
    conflictMessage: string;
    reload: string;
    reviewTitle: string;
    reviewDescription: string;
    current: string;
    proposed: string;
    reason: string;
    reasonPlaceholder: string;
    reasonHint: string;
    cancel: string;
    confirm: string;
    validationTitle: string;
  };
  fields: Record<string, { label: string; hint: string }>;
  alerts: {
    title: string;
    description: string;
    acknowledge: string;
    acknowledging: string;
    acknowledged: string;
    resolved: string;
    empty: string;
  };
  render: {
    title: string;
    description: string;
    unavailable: string;
    service: string;
    plan: string;
    region: string;
    instances: string;
    autoscaling: string;
    managed: string;
    review: string;
    reviewTitle: string;
    reviewDescription: string;
    target: string;
    reason: string;
    reasonPlaceholder: string;
    costNotice: string;
    conflictTitle: string;
    conflictMessage: string;
    reload: string;
    confirmUnderstanding: string;
    submit: string;
    operation: string;
    cancelOperation: string;
    operationStatuses: Record<string, string>;
  };
};

const fieldsRu: GenerationCapacityCopy["fields"] = {
  globalMaxConcurrent: {
    label: "Global max",
    hint: "Общий максимум одновременно активных задач PetMagic.",
  },
  imageMaxConcurrent: { label: "Image max", hint: "Максимум одновременно активных image-задач." },
  imageProtectedConcurrent: {
    label: "Image protected",
    hint: "Минимальная ёмкость, которую video borrowing не занимает.",
  },
  videoGuaranteedConcurrent: {
    label: "Video guaranteed",
    hint: "Слоты, освобождаемые для video при наличии спроса.",
  },
  videoMaxConcurrent: { label: "Video max", hint: "Максимум одновременно активных video-задач." },
  videoBorrowMaxConcurrent: {
    label: "Video borrow",
    hint: "Дополнительные video-слоты без задержки image.",
  },
  workerLoopsPerInstance: {
    label: "Loops per worker",
    hint: "Рабочие петли каждого Render worker instance (1–2).",
  },
  falConfiguredConcurrency: {
    label: "fal.ai configured limit",
    hint: "Лимит вручную подтверждается в fal.ai Dashboard.",
  },
  falReservedConcurrency: {
    label: "fal.ai reserve",
    hint: "Запас, который PetMagic намеренно не использует.",
  },
  falBalanceLowThresholdUsd: {
    label: "Balance Low, USD",
    hint: "Порог предупреждения о низком балансе.",
  },
  falBalanceCriticalThresholdUsd: {
    label: "Balance Critical, USD",
    hint: "Порог критического баланса и блокировки submissions.",
  },
};

const fieldsEn: GenerationCapacityCopy["fields"] = {
  globalMaxConcurrent: { label: "Global max", hint: "Maximum concurrently active PetMagic jobs." },
  imageMaxConcurrent: { label: "Image max", hint: "Maximum concurrently active image jobs." },
  imageProtectedConcurrent: {
    label: "Image protected",
    hint: "Capacity that video borrowing cannot consume.",
  },
  videoGuaranteedConcurrent: {
    label: "Video guaranteed",
    hint: "Slots recovered for video while video demand exists.",
  },
  videoMaxConcurrent: { label: "Video max", hint: "Maximum concurrently active video jobs." },
  videoBorrowMaxConcurrent: {
    label: "Video borrow",
    hint: "Additional video slots allowed without delaying image jobs.",
  },
  workerLoopsPerInstance: {
    label: "Loops per worker",
    hint: "Execution loops on every Render worker instance (1–2).",
  },
  falConfiguredConcurrency: {
    label: "fal.ai configured limit",
    hint: "Manually confirmed in the fal.ai Dashboard.",
  },
  falReservedConcurrency: {
    label: "fal.ai reserve",
    hint: "Capacity PetMagic intentionally leaves unused.",
  },
  falBalanceLowThresholdUsd: { label: "Balance Low, USD", hint: "Low-balance warning threshold." },
  falBalanceCriticalThresholdUsd: {
    label: "Balance Critical, USD",
    hint: "Critical balance and submission-block threshold.",
  },
};

const sharedStatusRu = {
  healthy: "Норма",
  degraded: "Ограничено",
  critical: "Критично",
  unknown: "Неизвестно",
  low: "Низкий",
};

const sharedStatusEn = {
  healthy: "Healthy",
  degraded: "Degraded",
  critical: "Critical",
  unknown: "Unknown",
  low: "Low",
};

const copy: Record<Locale, GenerationCapacityCopy> = {
  ru: {
    eyebrow: "Generation control",
    title: "Мощность генераций",
    description:
      "Единая точка контроля очереди, лимитов fal.ai, worker topology и ручного Render scaling.",
    adminOnly: "Только Admin",
    live: "Live status",
    refresh: "Обновить",
    retry: "Повторить",
    loadingTitle: "Загружаем состояние генераций",
    errorTitle: "Не удалось получить generation control",
    noData: "Backend не вернул данные.",
    health: sharedStatusRu,
    queue: {
      title: "Очередь и активные задачи",
      description: "Effective limits учитывают video demand; уже активные задачи не прерываются.",
      activeGlobal: "Активно всего",
      activeImage: "Image активно",
      activeVideo: "Video активно",
      queuedImage: "Image в очереди",
      queuedVideo: "Video в очереди",
      effectiveImage: "Effective image max",
      borrowedVideo: "Borrowed video",
      draining: "Draining: новые claims ограничены до безопасной ёмкости.",
    },
    fal: {
      title: "fal.ai",
      description: "Баланс считывается сервером; API key не передаётся в браузер.",
      balance: "Баланс",
      usable: "Доступная concurrency",
      inflight: "Inflight",
      reserve: "Резерв",
      checked: "Проверено",
      stale: "Данные устарели — новые submissions должны быть заблокированы.",
      manualLimit: "Account concurrency задаётся вручную по fal.ai Dashboard.",
      refresh: "Проверить баланс",
      refreshing: "Проверяем…",
    },
    workers: {
      title: "Worker topology",
      description: "Heartbeat каждого instance и применённая revision runtime-настроек.",
      instance: "Instance",
      loops: "Loops",
      revision: "Revision",
      heartbeat: "Heartbeat",
      current: "Актуален",
      stale: "Устарел",
      draining: "Draining",
      empty: "Активные worker heartbeats не найдены.",
      totalCapacity: "Наблюдаемая ёмкость",
      paidUnusedCapacity: "Оплачиваемая неиспользуемая ёмкость",
      expectedTopology: "Ожидаемая topology",
      observedTopology: "Наблюдаемая topology",
    },
    settings: {
      title: "Runtime-настройки",
      description: "Сохраняются с optimistic concurrency и применяются workers без redeploy.",
      saveReview: "Проверить изменения",
      saving: "Сохраняем…",
      noChanges: "Изменений нет.",
      conflictTitle: "Настройки уже изменены",
      conflictMessage:
        "Серверная revision стала новее. Перезагрузите значения и повторите проверку.",
      reload: "Загрузить актуальные",
      reviewTitle: "Подтвердить runtime-настройки",
      reviewDescription: "Проверьте только изменённые значения. Активные задачи не будут отменены.",
      current: "Было",
      proposed: "Станет",
      reason: "Причина изменения",
      reasonPlaceholder: "Например: подготовка production capacity перед запуском",
      reasonHint: "Обязательно, от 3 до 500 символов. Причина попадёт в audit trail.",
      cancel: "Отмена",
      confirm: "Применить настройки",
      validationTitle: "Исправьте значения",
    },
    fields: fieldsRu,
    alerts: {
      title: "Операционные уведомления",
      description:
        "Persistent alerts видны всем администраторам и закрываются автоматически после восстановления.",
      acknowledge: "Ознакомлен",
      acknowledging: "Сохраняем…",
      acknowledged: "Ознакомлен",
      resolved: "Восстановлено",
      empty: "Активных generation alerts нет.",
    },
    render: {
      title: "Render workers",
      description:
        "Масштабирование запускается только после явного подтверждения и никогда не происходит автоматически.",
      unavailable:
        "Render API не настроен. Добавьте secrets в API service; в браузер они не попадут.",
      service: "Service",
      plan: "Plan",
      region: "Region",
      instances: "Instances",
      autoscaling: "Render autoscaling включён — ручной scale заблокирован.",
      managed: "API-managed",
      review: "Изменить instances",
      reviewTitle: "Подтвердить Render scaling",
      reviewDescription:
        "Render тарифицирует каждый instance отдельно и пропорционально времени работы.",
      target: "Целевое количество instances",
      reason: "Причина масштабирования",
      reasonPlaceholder: "Например: controlled scale-up перед рекламной кампанией",
      costNotice:
        "Это действие может немедленно изменить оплачиваемую мощность. Точная сумма отображается в Render Billing.",
      conflictTitle: "Render topology уже изменилась",
      conflictMessage:
        "Подтверждённый baseline больше не актуален. Закройте review, загрузите текущее состояние и проверьте стоимость ещё раз.",
      reload: "Закрыть и обновить",
      confirmUnderstanding: "Я понимаю, что стоимость может измениться после подтверждения.",
      submit: "Запустить scaling",
      operation: "Текущая операция",
      cancelOperation: "Отменить операцию",
      operationStatuses: {
        requested: "Ожидает",
        draining: "Draining",
        scaling: "Scaling",
        verifying: "Проверка",
        completed: "Готово",
        failed: "Ошибка",
        cancelled: "Отменено",
      },
    },
  },
  en: {
    eyebrow: "Generation control",
    title: "Generation capacity",
    description:
      "One control plane for queue limits, fal.ai capacity, worker topology, and guarded Render scaling.",
    adminOnly: "Admin only",
    live: "Live status",
    refresh: "Refresh",
    retry: "Retry",
    loadingTitle: "Loading generation capacity",
    errorTitle: "Generation control is unavailable",
    noData: "The backend returned no data.",
    health: sharedStatusEn,
    queue: {
      title: "Queue and active jobs",
      description: "Effective limits respond to video demand; active jobs are never preempted.",
      activeGlobal: "Active total",
      activeImage: "Active image",
      activeVideo: "Active video",
      queuedImage: "Queued image",
      queuedVideo: "Queued video",
      effectiveImage: "Effective image max",
      borrowedVideo: "Borrowed video",
      draining: "Draining: new claims are restricted to the safe capacity.",
    },
    fal: {
      title: "fal.ai",
      description: "The backend reads account balance; the API key never reaches the browser.",
      balance: "Balance",
      usable: "Usable concurrency",
      inflight: "Inflight",
      reserve: "Reserve",
      checked: "Checked",
      stale: "Balance data is stale; new submissions must remain blocked.",
      manualLimit: "Account concurrency is manually confirmed from the fal.ai Dashboard.",
      refresh: "Refresh balance",
      refreshing: "Refreshing…",
    },
    workers: {
      title: "Worker topology",
      description: "Heartbeat and applied runtime settings revision for every instance.",
      instance: "Instance",
      loops: "Loops",
      revision: "Revision",
      heartbeat: "Heartbeat",
      current: "Current",
      stale: "Stale",
      draining: "Draining",
      empty: "No active worker heartbeats were found.",
      totalCapacity: "Observed capacity",
      paidUnusedCapacity: "Paid unused capacity",
      expectedTopology: "Expected topology",
      observedTopology: "Observed topology",
    },
    settings: {
      title: "Runtime settings",
      description: "Saved with optimistic concurrency and applied by workers without a redeploy.",
      saveReview: "Review changes",
      saving: "Saving…",
      noChanges: "There are no changes.",
      conflictTitle: "Settings changed on the server",
      conflictMessage: "A newer revision exists. Reload current values before reviewing again.",
      reload: "Load current values",
      reviewTitle: "Confirm runtime settings",
      reviewDescription: "Review changed fields only. Active jobs will not be cancelled.",
      current: "Current",
      proposed: "Proposed",
      reason: "Change reason",
      reasonPlaceholder: "For example: prepare production capacity before launch",
      reasonHint: "Required, 3–500 characters. The reason is recorded in the audit trail.",
      cancel: "Cancel",
      confirm: "Apply settings",
      validationTitle: "Correct the values",
    },
    fields: fieldsEn,
    alerts: {
      title: "Operational alerts",
      description:
        "Persistent alerts are shared across admins and resolve automatically after recovery.",
      acknowledge: "Acknowledge",
      acknowledging: "Saving…",
      acknowledged: "Acknowledged",
      resolved: "Resolved",
      empty: "There are no active generation alerts.",
    },
    render: {
      title: "Render workers",
      description:
        "Scaling starts only after explicit confirmation and never happens automatically.",
      unavailable:
        "Render API is not configured. Add secrets to the API service; they never reach the browser.",
      service: "Service",
      plan: "Plan",
      region: "Region",
      instances: "Instances",
      autoscaling: "Render autoscaling is enabled; manual scaling is blocked.",
      managed: "API-managed",
      review: "Change instances",
      reviewTitle: "Confirm Render scaling",
      reviewDescription: "Render bills every instance separately and prorates usage time.",
      target: "Target instances",
      reason: "Scaling reason",
      reasonPlaceholder: "For example: controlled scale-up before an ad campaign",
      costNotice:
        "This can immediately change paid capacity. Render Billing is the source of the final amount.",
      conflictTitle: "Render topology changed",
      conflictMessage:
        "The reviewed baseline is no longer current. Close the review, reload live state, and verify the cost again.",
      reload: "Close and reload",
      confirmUnderstanding: "I understand that the cost can change after confirmation.",
      submit: "Start scaling",
      operation: "Current operation",
      cancelOperation: "Cancel operation",
      operationStatuses: {
        requested: "Requested",
        draining: "Draining",
        scaling: "Scaling",
        verifying: "Verifying",
        completed: "Completed",
        failed: "Failed",
        cancelled: "Cancelled",
      },
    },
  },
};

export function getGenerationCapacityCopy(locale: Locale): GenerationCapacityCopy {
  return copy[locale];
}
