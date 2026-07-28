import type { GenerationCapacityMutableSettings } from "@/lib/generation-capacity-settings-draft";
import type { Locale } from "@/lib/i18n";

type OperationalState = "provider_blocked" | "draining" | "degraded" | "ready";

type AlertPresentation = {
  title: string;
  message: string;
  action: string;
  target: "fal" | "limits" | "workers";
};

export type GenerationCapacityCopy = {
  title: string;
  description: string;
  refresh: string;
  refreshing: string;
  retry: string;
  loadingTitle: string;
  errorTitle: string;
  noData: string;
  updated: string;
  autoRefresh: string;
  revision: string;
  health: Record<string, string>;
  nav: {
    label: string;
    overview: string;
    limits: string;
    fal: string;
    workers: string;
    alerts: string;
  };
  readiness: {
    title: string;
    states: Record<OperationalState, { title: string; description: string }>;
    providerReasons: Record<string, string>;
    limitingLayer: string;
    effectiveCapacity: string;
    configureSafeStart: string;
    presetApplied: string;
    checkBalance: string;
    queueContinues: string;
  };
  capacity: {
    petmagic: string;
    workers: string;
    fal: string;
    effective: string;
    bottleneck: string;
    active: string;
    image: string;
    video: string;
    queued: string;
    borrowed: string;
    noLimit: string;
    usage: (active: number, limit: number) => string;
    workerTopology: (instances: number, loops: number) => string;
    falFormula: (configured: number, reserved: number) => string;
  };
  checklist: {
    title: string;
    description: string;
    ready: string;
    primaryShown: string;
    attention: string;
    falLimit: string;
    falLimitReady: string;
    falLimitMissing: string;
    falLimitConsequence: string;
    balance: string;
    balanceReady: string;
    balanceUnknown: string;
    balanceLow: string;
    balanceCritical: string;
    balanceConsequence: string;
    workers: string;
    workersConsequence: string;
    render: string;
    renderReady: string;
    renderMissing: string;
    renderConsequence: string;
    configure: string;
    openScaling: string;
    showInstructions: string;
  };
  queue: {
    title: string;
    draining: string;
  };
  fal: {
    title: string;
    description: string;
    balance: string;
    lastConfirmedBalance: string;
    usable: string;
    configured: string;
    inflight: string;
    reserve: string;
    checked: string;
    lastSuccess: string;
    stale: string;
    manualLimit: string;
    refresh: string;
    refreshing: string;
    keyNotice: string;
    openDashboard: string;
    topUpBalance: string;
    verificationTitle: string;
    verificationDescription: string;
    verificationChecks: readonly string[];
    verificationDoesNotCheck: string;
    lastAttemptSuccess: string;
    lastAttemptFailed: string;
    lastAttemptWaiting: string;
    lastAttemptStale: string;
    billingKeyReady: string;
    billingKeyMissing: string;
    providerNotUsed: string;
    diagnosticReason: string;
    diagnostics: Record<string, { title: string; description: string }>;
  };
  workers: {
    title: string;
    description: string;
    instance: string;
    loops: string;
    revision: string;
    heartbeat: string;
    status: string;
    current: string;
    stale: string;
    draining: string;
    empty: string;
    currentWorkers: string;
    observedCapacity: string;
    requiredCapacity: string;
    requiredInstances: string;
    paidUnusedCapacity: string;
    staleHistory: (count: number) => string;
    staleHistoryHint: string;
  };
  settings: {
    title: string;
    description: string;
    groups: {
      total: { title: string; description: string };
      image: { title: string; description: string };
      video: { title: string; description: string };
      fal: { title: string; description: string };
      balance: { title: string; description: string };
    };
    presetTitle: string;
    presetDescription: string;
    presetValues: string;
    applyPreset: string;
    presetDoesNotSave: string;
    summaryTitle: string;
    summaryDescription: string;
    edit: string;
    discardDraft: string;
    saveReview: string;
    saving: string;
    noChanges: string;
    changes: (count: number) => string;
    whyDisabled: string;
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
    validation: {
      invalidInteger: (label: string) => string;
      workerLoops: string;
      falLimitMissing: string;
      globalExceedsFal: string;
      imageMax: string;
      imageProtected: string;
      videoMax: string;
      videoGuaranteed: string;
      videoBorrow: string;
      balanceThresholds: string;
    };
  };
  fields: Record<keyof GenerationCapacityMutableSettings, { label: string; hint: string }>;
  alerts: {
    title: string;
    description: string;
    acknowledge: string;
    acknowledging: string;
    acknowledged: string;
    acknowledgementHint: string;
    empty: string;
    technicalCode: string;
    catalog: Record<string, AlertPresentation>;
  };
  render: {
    title: string;
    description: string;
    unavailable: string;
    setupTitle: string;
    setupDescription: string;
    setupSteps: readonly string[];
    setupVariables: readonly string[];
    setupSecretNotice: string;
    service: string;
    plan: string;
    region: string;
    instances: string;
    topology: string;
    autoscaling: string;
    managed: string;
    review: string;
    reviewTitle: string;
    reviewDescription: string;
    target: string;
    reason: string;
    reasonPlaceholder: string;
    costNotice: string;
    billingNotice: string;
    conflictTitle: string;
    conflictMessage: string;
    reload: string;
    confirmUnderstanding: string;
    submit: string;
    operation: string;
    cancelOperation: string;
    openDashboard: string;
    operationStatuses: Record<string, string>;
  };
};

const fieldsRu: GenerationCapacityCopy["fields"] = {
  globalMaxConcurrent: {
    label: "Общий лимит",
    hint: "Максимум одновременно активных задач PetMagic.",
  },
  imageMaxConcurrent: {
    label: "Image: максимум",
    hint: "Сколько image-задач может выполняться одновременно.",
  },
  imageProtectedConcurrent: {
    label: "Image: защищённые слоты",
    hint: "Эту ёмкость video borrowing занимать не может.",
  },
  videoGuaranteedConcurrent: {
    label: "Video: гарантированные слоты",
    hint: "Столько слотов освобождается для video при наличии спроса.",
  },
  videoMaxConcurrent: {
    label: "Video: максимум",
    hint: "Верхняя граница одновременно активных video-задач.",
  },
  videoBorrowMaxConcurrent: {
    label: "Video: borrowing",
    hint: "Дополнительные video-слоты, если они не задерживают image.",
  },
  workerLoopsPerInstance: {
    label: "Loops на worker",
    hint: "Рабочие петли одного Render worker instance: 1 или 2.",
  },
  falConfiguredConcurrency: {
    label: "Подтверждённый лимит fal.ai",
    hint: "Значение вручную сверяется с fal.ai Dashboard; оно не меняет лимит аккаунта.",
  },
  falReservedConcurrency: {
    label: "Резерв fal.ai",
    hint: "Запас PetMagic, который намеренно не используется.",
  },
  falBalanceLowThresholdUsd: {
    label: "Предупреждение, USD",
    hint: "При этом балансе появляется предупреждение.",
  },
  falBalanceCriticalThresholdUsd: {
    label: "Критический порог, USD",
    hint: "При этом балансе новые отправки в provider блокируются.",
  },
};

const fieldsEn: GenerationCapacityCopy["fields"] = {
  globalMaxConcurrent: {
    label: "Global limit",
    hint: "Maximum concurrently active PetMagic jobs.",
  },
  imageMaxConcurrent: { label: "Image maximum", hint: "Maximum concurrently active image jobs." },
  imageProtectedConcurrent: {
    label: "Image protected slots",
    hint: "Capacity that video borrowing cannot consume.",
  },
  videoGuaranteedConcurrent: {
    label: "Video guaranteed slots",
    hint: "Slots recovered for video while demand exists.",
  },
  videoMaxConcurrent: { label: "Video maximum", hint: "Maximum concurrently active video jobs." },
  videoBorrowMaxConcurrent: {
    label: "Video borrowing",
    hint: "Additional video slots allowed without delaying image jobs.",
  },
  workerLoopsPerInstance: {
    label: "Loops per worker",
    hint: "Execution loops on every Render worker instance: 1 or 2.",
  },
  falConfiguredConcurrency: {
    label: "Confirmed fal.ai limit",
    hint: "Manually verified in fal.ai Dashboard; this does not change the account limit.",
  },
  falReservedConcurrency: {
    label: "fal.ai reserve",
    hint: "Capacity PetMagic intentionally leaves unused.",
  },
  falBalanceLowThresholdUsd: {
    label: "Warning threshold, USD",
    hint: "A low-balance warning appears at this value.",
  },
  falBalanceCriticalThresholdUsd: {
    label: "Critical threshold, USD",
    hint: "New provider submissions are blocked at this value.",
  },
};

const alertCatalogRu: Record<string, AlertPresentation> = {
  fal_balance_low: {
    title: "Баланс fal.ai заканчивается",
    message: "Генерации пока доступны, но баланс нужно пополнить до роста нагрузки.",
    action: "Проверить баланс",
    target: "fal",
  },
  fal_balance_critical: {
    title: "Баланс fal.ai достиг критического порога",
    message: "Новые отправки в fal.ai заблокированы до пополнения баланса.",
    action: "Открыть fal.ai",
    target: "fal",
  },
  fal_balance_unknown: {
    title: "Баланс fal.ai не подтверждён",
    message: "Backend не получил свежий balance snapshot; новые provider submissions отложены.",
    action: "Проверить баланс",
    target: "fal",
  },
  fal_capacity_near_usable_limit: {
    title: "fal.ai близок к доступному лимиту",
    message: "Количество inflight-запросов почти исчерпало доступную concurrency.",
    action: "Проверить лимиты",
    target: "limits",
  },
  worker_capacity_insufficient: {
    title: "Недостаточно worker capacity",
    message: "Текущих worker loops меньше выбранного общего лимита PetMagic.",
    action: "Проверить workers",
    target: "workers",
  },
  runtime_config_not_applied: {
    title: "Workers ещё не применили новые настройки",
    message: "После сохранения дождитесь refresh и следующего heartbeat worker.",
    action: "Проверить workers",
    target: "workers",
  },
  render_instance_drift: {
    title: "Render topology отличается от ожидаемой",
    message: "Фактическое и целевое количество Render instances не совпадает.",
    action: "Открыть Render",
    target: "workers",
  },
  render_scale_failed: {
    title: "Render scaling завершился ошибкой",
    message: "Drain снят; проверьте operation и Render configuration перед повтором.",
    action: "Открыть Render",
    target: "workers",
  },
};

const alertCatalogEn: Record<string, AlertPresentation> = {
  fal_balance_low: {
    title: "fal.ai balance is running low",
    message: "Generations remain available, but credits should be topped up before traffic grows.",
    action: "Check balance",
    target: "fal",
  },
  fal_balance_critical: {
    title: "fal.ai balance reached the critical threshold",
    message: "New fal.ai submissions are blocked until the balance is restored.",
    action: "Open fal.ai",
    target: "fal",
  },
  fal_balance_unknown: {
    title: "fal.ai balance is not confirmed",
    message: "The backend has no fresh balance snapshot; new provider submissions are deferred.",
    action: "Check balance",
    target: "fal",
  },
  fal_capacity_near_usable_limit: {
    title: "fal.ai is near the usable limit",
    message: "Inflight requests have nearly exhausted usable concurrency.",
    action: "Review limits",
    target: "limits",
  },
  worker_capacity_insufficient: {
    title: "Worker capacity is insufficient",
    message: "Current worker loops are below the selected PetMagic global limit.",
    action: "Review workers",
    target: "workers",
  },
  runtime_config_not_applied: {
    title: "Workers have not applied the latest settings",
    message: "After saving, wait for settings refresh and the next worker heartbeat.",
    action: "Review workers",
    target: "workers",
  },
  render_instance_drift: {
    title: "Render topology differs from the target",
    message: "Actual and desired Render instance counts do not match.",
    action: "Open Render",
    target: "workers",
  },
  render_scale_failed: {
    title: "Render scaling failed",
    message:
      "Drain has been released; review the operation and Render configuration before retrying.",
    action: "Open Render",
    target: "workers",
  },
};

const copy: Record<Locale, GenerationCapacityCopy> = {
  ru: {
    title: "Мощность генераций",
    description: "Очередь, fal.ai и Render workers — в одном операторском экране.",
    refresh: "Обновить диагностику",
    refreshing: "Обновляем…",
    retry: "Повторить",
    loadingTitle: "Загружаем состояние генераций",
    errorTitle: "Не удалось получить управление генерациями",
    noData: "Backend не вернул данные.",
    updated: "Обновлено",
    autoRefresh: "автообновление каждые 15 сек",
    revision: "Ревизия",
    health: {
      healthy: "Работает",
      degraded: "Ограничено",
      critical: "Заблокировано",
      unknown: "Неизвестно",
      low: "Низкий баланс",
    },
    nav: {
      label: "Разделы управления мощностью",
      overview: "Обзор",
      limits: "Лимиты",
      fal: "fal.ai",
      workers: "Workers и Render",
      alerts: "Уведомления",
    },
    readiness: {
      title: "Генерации сейчас",
      states: {
        provider_blocked: {
          title: "Отправка в fal.ai приостановлена",
          description:
            "Новые задания остаются в очереди, пока provider gate закрыт. Уже запущенные задачи продолжают проверяться.",
        },
        draining: {
          title: "Система завершает активные задачи",
          description: "Новые claims ограничены; активные генерации завершаются естественно.",
        },
        degraded: {
          title: "Генерации работают с ограниченной мощностью",
          description:
            "Задания выполняются, но фактическая worker capacity ниже выбранного лимита.",
        },
        ready: {
          title: "Генерации работают штатно",
          description:
            "Provider gate открыт, workers применили настройки, доступная ёмкость известна.",
        },
      },
      providerReasons: {
        concurrency_unknown: "Лимит concurrency fal.ai не указан",
        concurrency_exhausted: "Доступная concurrency fal.ai исчерпана",
        balance_unknown: "Свежий баланс fal.ai не получен",
        balance_critical: "Баланс fal.ai достиг критического порога",
      },
      limitingLayer: "Ограничивающий слой",
      effectiveCapacity: "Доступно одновременно",
      configureSafeStart: "Настроить безопасный старт",
      presetApplied: "Рекомендуемые значения подставлены в черновик. Проверьте их ниже.",
      checkBalance: "Открыть диагностику fal.ai",
      queueContinues: "Очередь продолжает принимать задания; provider submission будет повторён.",
    },
    capacity: {
      petmagic: "PetMagic",
      workers: "Workers",
      fal: "fal.ai",
      effective: "Фактически доступно",
      bottleneck: "Ограничивает",
      active: "В работе",
      image: "Image",
      video: "Video",
      queued: "В очереди",
      borrowed: "Video borrowing",
      noLimit: "не задан",
      usage: (active, limit) => `${active} активно из ${limit}`,
      workerTopology: (instances, loops) => `${instances} instance · ${loops} рабочих петель`,
      falFormula: (configured, reserved) => `Лимит ${configured} − резерв ${reserved}`,
    },
    checklist: {
      title: "Что нужно сделать",
      description: "Шаги расположены по влиянию на новые генерации.",
      ready: "Готово",
      primaryShown:
        "Главный следующий шаг показан слева. После него диагностика обновится автоматически.",
      attention: "Требует внимания",
      falLimit: "Лимит fal.ai",
      falLimitReady: "Подтверждён вручную",
      falLimitMissing: "Не задан",
      falLimitConsequence: "Без лимита PetMagic не отправляет новые запросы provider.",
      balance: "Баланс fal.ai",
      balanceReady: "Подтверждён",
      balanceUnknown: "Неизвестен",
      balanceLow: "Низкий",
      balanceCritical: "Критический",
      balanceConsequence: "Unknown или Critical закрывает provider gate.",
      workers: "Worker capacity",
      workersConsequence:
        "Недостаток loops снижает реальную параллельность, но не увеличивает оплату.",
      render: "Render API",
      renderReady: "Настроен",
      renderMissing: "Не настроен",
      renderConsequence: "Без API нельзя безопасно менять instances из админки.",
      configure: "Настроить",
      openScaling: "Открыть масштабирование",
      showInstructions: "Показать инструкцию",
    },
    queue: {
      title: "Очередь",
      draining: "Новые claims ограничены до безопасной ёмкости.",
    },
    fal: {
      title: "fal.ai: аккаунт и provider gate",
      description: "Баланс читает backend; API key и secrets никогда не передаются в браузер.",
      balance: "Баланс",
      lastConfirmedBalance: "Последний подтверждённый баланс",
      usable: "Доступная concurrency",
      configured: "Подтверждённый лимит",
      inflight: "Сейчас в fal.ai",
      reserve: "Резерв PetMagic",
      checked: "Последняя попытка",
      lastSuccess: "Последний успешный ответ",
      stale: "Данные устарели: новые отправки provider должны оставаться отложенными.",
      manualLimit:
        "Лимит аккаунта сверяется вручную в fal.ai Dashboard и вводится в разделе «Лимиты».",
      refresh: "Проверить подключение и баланс",
      refreshing: "Проверяем…",
      keyNotice:
        "Ключ генераций остаётся у worker, а отдельный Admin billing credential хранится только в API service.",
      openDashboard: "Открыть fal.ai Dashboard",
      topUpBalance: "Пополнить баланс",
      verificationTitle: "Что именно проверит backend",
      verificationDescription:
        "API service запрашивает fal.ai Account Billing server-to-server. Повторный клик в течение 5 секунд безопасно использует только что сохранённый snapshot; браузер не получает ни один ключ.",
      verificationChecks: [
        "Настроен ли отдельный Admin API key для billing.",
        "Есть ли у ключа ADMIN scope и относится ли ответ к ожидаемому аккаунту.",
        "Вернул ли fal.ai актуальный USD balance, который можно сохранить как свежий snapshot.",
      ],
      verificationDoesNotCheck:
        "Кнопка не запускает генерацию, не пополняет баланс и не читает concurrency limit — лимит 10 подтверждается вручную в fal.ai Dashboard.",
      lastAttemptSuccess: "Последняя проверка успешна",
      lastAttemptFailed: "Последняя проверка не прошла",
      lastAttemptWaiting: "Проверка ещё не выполнялась",
      lastAttemptStale: "Последний успешный ответ устарел",
      billingKeyReady: "Admin billing key настроен",
      billingKeyMissing: "Admin billing key не настроен",
      providerNotUsed: "Локально выбран Fake provider — fal.ai в этом окружении не используется.",
      diagnosticReason: "Причина",
      diagnostics: {
        admin_api_key_missing: {
          title: "Не задан Admin API key для billing",
          description:
            "Создайте в fal.ai отдельный ключ с ADMIN scope и добавьте его как server-side billing credential только в Render API service.",
        },
        authentication_failed: {
          title: "fal.ai отклонил ключ",
          description: "Проверьте, что Admin API key актуален и скопирован полностью.",
        },
        admin_scope_required: {
          title: "Ключ не имеет ADMIN scope",
          description:
            "Обычный API key подходит для генераций, но Account Billing возвращает 403. Создайте отдельный ADMIN key; не заменяйте им ключ worker.",
        },
        rate_limited: {
          title: "fal.ai временно ограничил запросы",
          description:
            "Подождите и повторите проверку. Фоновая проверка выполняется не чаще раза в минуту.",
        },
        provider_unavailable: {
          title: "Billing API fal.ai временно недоступен",
          description:
            "Свежий баланс не подтверждён. Повторите проверку после восстановления fal.ai.",
        },
        account_mismatch: {
          title: "Ответ получен не от ожидаемого fal.ai аккаунта",
          description:
            "Проверьте server-side account pin и аккаунт, в котором создан Admin API key.",
        },
        unsupported_currency: {
          title: "fal.ai вернул неподдерживаемую валюту",
          description:
            "PetMagic ожидает balance в USD и не будет интерпретировать другую валюту как доллары.",
        },
        invalid_response: {
          title: "Ответ fal.ai имеет неожиданный формат",
          description: "Баланс не обновлён, чтобы не принять неверное значение.",
        },
        request_timeout: {
          title: "fal.ai не ответил вовремя",
          description: "Проверьте соединение позже; предыдущий баланс не считается свежим.",
        },
        request_failed: {
          title: "Не удалось связаться с fal.ai",
          description: "Проверьте сетевое соединение API service и повторите запрос.",
        },
      },
    },
    workers: {
      title: "Workers и Render",
      description: "Фактические heartbeats, применённая ревизия и ручное масштабирование.",
      instance: "Worker",
      loops: "Loops",
      revision: "Ревизия",
      heartbeat: "Последний heartbeat",
      status: "Состояние",
      current: "Актуален",
      stale: "Устарел",
      draining: "Завершает задачи",
      empty: "Свежие worker heartbeats не найдены.",
      currentWorkers: "Активные workers",
      observedCapacity: "Наблюдаемая ёмкость",
      requiredCapacity: "Нужно для общего лимита",
      requiredInstances: "Нужно instances",
      paidUnusedCapacity: "Оплачиваемая неиспользуемая ёмкость",
      staleHistory: (count) => `Устаревшие heartbeats: ${count}`,
      staleHistoryHint: "История не участвует в расчёте мощности и скрыта по умолчанию.",
    },
    settings: {
      title: "Лимиты и политика очереди",
      description:
        "Изменения применяются без redeploy, но только после review и обязательной причины.",
      groups: {
        total: { title: "Общая ёмкость", description: "Лимит PetMagic и нагрузка одного worker." },
        image: { title: "Image", description: "Максимум и защищённая ёмкость image-задач." },
        video: { title: "Video", description: "Гарантия, максимум и безопасный borrowing." },
        fal: { title: "fal.ai", description: "Подтверждённый account limit и внутренний резерв." },
        balance: {
          title: "Баланс",
          description: "Пороги предупреждения и блокировки provider submissions.",
        },
      },
      presetTitle: "Безопасный production старт",
      presetDescription: "Профиль из render.production.yaml для account concurrency 10.",
      presetValues:
        "Global 8 · Image 7/3 · Video 2/4 + borrow 2 · 2 loops на instance · fal.ai 10−2 · $10/$5",
      applyPreset: "Подставить значения",
      presetDoesNotSave:
        "Кнопка меняет только черновик. Сохранение и Render scaling подтверждаются отдельно.",
      summaryTitle: "Текущий профиль",
      summaryDescription:
        "Сначала проверьте итоговую ёмкость. Поля появятся только после явного перехода в редактирование.",
      edit: "Изменить лимиты",
      discardDraft: "Отменить черновик",
      saveReview: "Проверить изменения",
      saving: "Сохраняем…",
      noChanges: "Изменений нет.",
      changes: (count) => `Изменено полей: ${count}`,
      whyDisabled: "Измените значения и исправьте ошибки, чтобы перейти к review.",
      conflictTitle: "Настройки уже изменены",
      conflictMessage:
        "Серверная ревизия стала новее. Загрузите актуальные значения и повторите review.",
      reload: "Загрузить актуальные",
      reviewTitle: "Подтвердить runtime-настройки",
      reviewDescription: "Проверьте изменённые значения. Активные задачи не будут отменены.",
      current: "Было",
      proposed: "Станет",
      reason: "Причина изменения",
      reasonPlaceholder: "Например: подготовка production capacity перед запуском",
      reasonHint: "Обязательно, от 3 до 500 символов. Причина попадёт в audit trail.",
      cancel: "Отмена",
      confirm: "Применить настройки",
      validationTitle: "Исправьте настройки",
      validation: {
        invalidInteger: (label) => `${label}: введите допустимое целое число.`,
        workerLoops: "Loops на worker должны быть от 1 до 2.",
        falLimitMissing: "Укажите подтверждённый лимит fal.ai больше нуля.",
        globalExceedsFal: "Общий лимит не может превышать лимит fal.ai за вычетом резерва.",
        imageMax: "Image максимум не может превышать общий лимит.",
        imageProtected: "Защищённые image-слоты должны быть от 1 до Image максимума.",
        videoMax: "Video максимум не может превышать общий лимит.",
        videoGuaranteed: "Гарантированные video-слоты не могут превышать Video максимум.",
        videoBorrow: "Video guarantee + borrowing должны покрывать Video максимум.",
        balanceThresholds:
          "Критический порог должен быть неотрицательным и не выше предупреждения.",
      },
    },
    fields: fieldsRu,
    alerts: {
      title: "Операционные уведомления",
      description:
        "Сначала показано действие, затем технический код. Ознакомление не устраняет причину.",
      acknowledge: "Пометить прочитанным",
      acknowledging: "Сохраняем…",
      acknowledged: "Прочитано",
      acknowledgementHint: "Уведомление останется активным до автоматического восстановления.",
      empty: "Активных уведомлений о генерациях нет.",
      technicalCode: "Код",
      catalog: alertCatalogRu,
    },
    render: {
      title: "Render scaling",
      description:
        "Instances меняются только вручную; runtime limits сами не влияют на оплату Render.",
      unavailable: "Управление Render из админки пока не настроено.",
      setupTitle: "Как включить ручное масштабирование",
      setupDescription:
        "Настройка выполняется в Render, а не на этой странице. Она не меняет количество instances сама по себе.",
      setupSteps: [
        "Откройте Render Dashboard → petmagic-production-api → Environment.",
        "Добавьте перечисленные variables и сохраните изменения API service.",
        "Дождитесь redeploy API, затем вернитесь сюда и обновите диагностику.",
      ],
      setupVariables: [
        "RENDER_API_KEY",
        "RENDER_GENERATION_WORKER_SERVICE_ID",
        "RENDER_GENERATION_WORKER_EXPECTED_OWNER_ID",
        "RENDER_GENERATION_WORKER_EXPECTED_NAME",
        "RENDER_GENERATION_WORKER_EXPECTED_TYPE",
        "RENDER_GENERATION_WORKER_EXPECTED_REPOSITORY",
      ],
      setupSecretNotice:
        "Значения вводятся только в Render Environment. Админка не читает и не показывает секреты.",
      service: "Service",
      plan: "Plan",
      region: "Регион",
      instances: "Instances",
      topology: "Фактически / целевое",
      autoscaling: "Render autoscaling включён — ручное масштабирование заблокировано.",
      managed: "Ручное управление через API",
      review: "Изменить instances",
      reviewTitle: "Подтвердить Render scaling",
      reviewDescription:
        "Render тарифицирует каждый instance отдельно и пропорционально времени работы.",
      target: "Целевое количество instances",
      reason: "Причина масштабирования",
      reasonPlaceholder: "Например: controlled scale-up перед рекламной кампанией",
      costNotice:
        "Это действие может сразу изменить оплачиваемую мощность. Точная сумма отображается в Render Billing.",
      billingNotice: "До отдельного подтверждения стоимость и количество instances не изменятся.",
      conflictTitle: "Render topology уже изменилась",
      conflictMessage:
        "Подтверждённый baseline устарел. Закройте review, обновите состояние и проверьте стоимость ещё раз.",
      reload: "Закрыть и обновить",
      confirmUnderstanding: "Я понимаю, что стоимость может измениться после подтверждения.",
      submit: "Запустить scaling",
      operation: "Текущая операция",
      cancelOperation: "Отменить операцию",
      openDashboard: "Открыть Render Dashboard",
      operationStatuses: {
        requested: "Ожидает",
        draining: "Завершает активные задачи",
        scaling: "Меняет instances",
        verifying: "Проверяет topology",
        completed: "Готово",
        failed: "Ошибка",
        cancelled: "Отменено",
      },
    },
  },
  en: {
    title: "Generation capacity",
    description: "Queue, fal.ai, and Render workers in one operational workspace.",
    refresh: "Refresh diagnostics",
    refreshing: "Refreshing…",
    retry: "Retry",
    loadingTitle: "Loading generation capacity",
    errorTitle: "Generation control is unavailable",
    noData: "The backend returned no data.",
    updated: "Updated",
    autoRefresh: "auto-refresh every 15 sec",
    revision: "Revision",
    health: {
      healthy: "Operational",
      degraded: "Limited",
      critical: "Blocked",
      unknown: "Unknown",
      low: "Low balance",
    },
    nav: {
      label: "Generation capacity sections",
      overview: "Overview",
      limits: "Limits",
      fal: "fal.ai",
      workers: "Workers & Render",
      alerts: "Alerts",
    },
    readiness: {
      title: "Generations now",
      states: {
        provider_blocked: {
          title: "fal.ai submissions are paused",
          description:
            "New jobs remain queued while the provider gate is closed. Running jobs keep reconciling.",
        },
        draining: {
          title: "The system is finishing active jobs",
          description: "New claims are restricted while active generations complete naturally.",
        },
        degraded: {
          title: "Generations are running with limited capacity",
          description: "Jobs can run, but actual worker capacity is below the selected limit.",
        },
        ready: {
          title: "Generations are operational",
          description:
            "The provider gate is open, workers are current, and effective capacity is known.",
        },
      },
      providerReasons: {
        concurrency_unknown: "fal.ai concurrency limit is not configured",
        concurrency_exhausted: "Usable fal.ai concurrency is exhausted",
        balance_unknown: "No fresh fal.ai balance is available",
        balance_critical: "fal.ai balance reached the critical threshold",
      },
      limitingLayer: "Limiting layer",
      effectiveCapacity: "Effective concurrency",
      configureSafeStart: "Configure safe start",
      presetApplied: "Recommended values were placed in the draft. Review them below.",
      checkBalance: "Open fal.ai diagnostics",
      queueContinues: "The queue keeps accepting jobs; provider submission will be retried.",
    },
    capacity: {
      petmagic: "PetMagic",
      workers: "Workers",
      fal: "fal.ai",
      effective: "Effective capacity",
      bottleneck: "Bottleneck",
      active: "Active",
      image: "Image",
      video: "Video",
      queued: "Queued",
      borrowed: "Video borrowing",
      noLimit: "not configured",
      usage: (active, limit) => `${active} active of ${limit}`,
      workerTopology: (instances, loops) => `${instances} instance · ${loops} worker loops`,
      falFormula: (configured, reserved) => `Limit ${configured} − reserve ${reserved}`,
    },
    checklist: {
      title: "What needs attention",
      description: "Steps are ordered by impact on new generations.",
      ready: "Ready",
      primaryShown:
        "The primary next step is shown on the left. Diagnostics refresh automatically afterward.",
      attention: "Needs attention",
      falLimit: "fal.ai limit",
      falLimitReady: "Manually confirmed",
      falLimitMissing: "Not configured",
      falLimitConsequence: "Without a limit, PetMagic does not submit new provider requests.",
      balance: "fal.ai balance",
      balanceReady: "Confirmed",
      balanceUnknown: "Unknown",
      balanceLow: "Low",
      balanceCritical: "Critical",
      balanceConsequence: "Unknown or Critical closes the provider gate.",
      workers: "Worker capacity",
      workersConsequence: "Missing loops reduce actual concurrency without increasing billing.",
      render: "Render API",
      renderReady: "Configured",
      renderMissing: "Not configured",
      renderConsequence: "Without the API, instances cannot be changed safely from Admin.",
      configure: "Configure",
      openScaling: "Open scaling",
      showInstructions: "Show instructions",
    },
    queue: { title: "Queue", draining: "New claims are restricted to safe capacity." },
    fal: {
      title: "fal.ai account and provider gate",
      description: "The backend reads balance; API keys and secrets never reach the browser.",
      balance: "Balance",
      lastConfirmedBalance: "Last confirmed balance",
      usable: "Usable concurrency",
      configured: "Confirmed limit",
      inflight: "Currently in fal.ai",
      reserve: "PetMagic reserve",
      checked: "Last attempt",
      lastSuccess: "Last successful response",
      stale: "Data is stale: new provider submissions must remain deferred.",
      manualLimit: "Verify the account limit in fal.ai Dashboard and enter it under Limits.",
      refresh: "Check connection and balance",
      refreshing: "Checking…",
      keyNotice:
        "The generation key stays on the worker. A separate Admin billing credential is stored only on the API service.",
      openDashboard: "Open fal.ai Dashboard",
      topUpBalance: "Add credits",
      verificationTitle: "What the backend will verify",
      verificationDescription:
        "The API service calls fal.ai Account Billing server-to-server. A repeated click within 5 seconds safely reuses the just-saved snapshot; no key reaches the browser.",
      verificationChecks: [
        "A dedicated Admin API key is configured for billing.",
        "The key has ADMIN scope and the response belongs to the expected account.",
        "fal.ai returned a current USD balance that can be stored as a fresh snapshot.",
      ],
      verificationDoesNotCheck:
        "This does not start a generation, add credits, or read the concurrency limit. Confirm limit 10 manually in fal.ai Dashboard.",
      lastAttemptSuccess: "Last check succeeded",
      lastAttemptFailed: "Last check failed",
      lastAttemptWaiting: "No check has run yet",
      lastAttemptStale: "The last successful response is stale",
      billingKeyReady: "Admin billing key is configured",
      billingKeyMissing: "Admin billing key is not configured",
      providerNotUsed:
        "The Fake provider is selected locally, so this environment does not use fal.ai.",
      diagnosticReason: "Reason",
      diagnostics: {
        admin_api_key_missing: {
          title: "Billing Admin API key is missing",
          description:
            "Create a separate fal.ai key with ADMIN scope and add it as a server-side billing credential only to the Render API service.",
        },
        authentication_failed: {
          title: "fal.ai rejected the key",
          description: "Verify that the Admin API key is active and was copied completely.",
        },
        admin_scope_required: {
          title: "The key does not have ADMIN scope",
          description:
            "A regular API key can generate, but Account Billing returns 403. Create a separate ADMIN key; do not replace the worker key.",
        },
        rate_limited: {
          title: "fal.ai temporarily rate-limited the check",
          description: "Wait and retry. Background billing checks run at most once per minute.",
        },
        provider_unavailable: {
          title: "fal.ai Billing API is temporarily unavailable",
          description: "No fresh balance was confirmed. Retry after fal.ai recovers.",
        },
        account_mismatch: {
          title: "The response belongs to a different fal.ai account",
          description:
            "Check the server-side account pin and the account that owns the Admin API key.",
        },
        unsupported_currency: {
          title: "fal.ai returned an unsupported currency",
          description: "PetMagic expects USD and will not interpret another currency as dollars.",
        },
        invalid_response: {
          title: "fal.ai returned an unexpected response",
          description:
            "The balance was not updated, preventing an invalid value from being accepted.",
        },
        request_timeout: {
          title: "fal.ai did not respond in time",
          description: "Retry later; the previous balance is not considered fresh.",
        },
        request_failed: {
          title: "Could not connect to fal.ai",
          description: "Check the API service network connection and retry.",
        },
      },
    },
    workers: {
      title: "Workers & Render",
      description: "Live heartbeats, applied revision, and guarded manual scaling.",
      instance: "Worker",
      loops: "Loops",
      revision: "Revision",
      heartbeat: "Last heartbeat",
      status: "Status",
      current: "Current",
      stale: "Stale",
      draining: "Draining",
      empty: "No fresh worker heartbeats were found.",
      currentWorkers: "Active workers",
      observedCapacity: "Observed capacity",
      requiredCapacity: "Required for global limit",
      requiredInstances: "Required instances",
      paidUnusedCapacity: "Paid unused capacity",
      staleHistory: (count) => `Stale heartbeats: ${count}`,
      staleHistoryHint:
        "History does not affect capacity calculations and is collapsed by default.",
    },
    settings: {
      title: "Limits and queue policy",
      description: "Changes apply without redeploy, but only after review and a required reason.",
      groups: {
        total: { title: "Total capacity", description: "PetMagic limit and load per worker." },
        image: { title: "Image", description: "Maximum and protected image capacity." },
        video: { title: "Video", description: "Guarantee, maximum, and safe borrowing." },
        fal: { title: "fal.ai", description: "Confirmed account limit and internal reserve." },
        balance: { title: "Balance", description: "Warning and provider-block thresholds." },
      },
      presetTitle: "Safe production start",
      presetDescription: "Profile from render.production.yaml for account concurrency 10.",
      presetValues:
        "Global 8 · Image 7/3 · Video 2/4 + borrow 2 · 2 loops per instance · fal.ai 10−2 · $10/$5",
      applyPreset: "Use these values",
      presetDoesNotSave:
        "This only changes the draft. Settings and Render scaling are confirmed separately.",
      summaryTitle: "Current profile",
      summaryDescription:
        "Review effective capacity first. The editable fields appear only after you explicitly enter edit mode.",
      edit: "Edit limits",
      discardDraft: "Discard draft",
      saveReview: "Review changes",
      saving: "Saving…",
      noChanges: "There are no changes.",
      changes: (count) => `${count} field${count === 1 ? "" : "s"} changed`,
      whyDisabled: "Change values and resolve validation errors to continue to review.",
      conflictTitle: "Settings changed on the server",
      conflictMessage: "A newer revision exists. Load current values and review again.",
      reload: "Load current values",
      reviewTitle: "Confirm runtime settings",
      reviewDescription: "Review changed values. Active jobs will not be cancelled.",
      current: "Current",
      proposed: "Proposed",
      reason: "Change reason",
      reasonPlaceholder: "For example: prepare production capacity before launch",
      reasonHint: "Required, 3–500 characters. The reason is stored in the audit trail.",
      cancel: "Cancel",
      confirm: "Apply settings",
      validationTitle: "Correct the settings",
      validation: {
        invalidInteger: (label) => `${label}: enter a valid integer.`,
        workerLoops: "Loops per worker must be between 1 and 2.",
        falLimitMissing: "Enter a confirmed fal.ai limit greater than zero.",
        globalExceedsFal: "The global limit cannot exceed the fal.ai limit minus reserve.",
        imageMax: "Image maximum cannot exceed the global limit.",
        imageProtected: "Protected image slots must be between 1 and the image maximum.",
        videoMax: "Video maximum cannot exceed the global limit.",
        videoGuaranteed: "Guaranteed video slots cannot exceed the video maximum.",
        videoBorrow: "Video guarantee plus borrowing must cover the video maximum.",
        balanceThresholds: "Critical threshold must be non-negative and no greater than Warning.",
      },
    },
    fields: fieldsEn,
    alerts: {
      title: "Operational alerts",
      description:
        "The repair action comes first; the technical code is secondary. Acknowledging does not resolve the issue.",
      acknowledge: "Mark as read",
      acknowledging: "Saving…",
      acknowledged: "Read",
      acknowledgementHint: "The alert remains active until the system recovers automatically.",
      empty: "There are no active generation alerts.",
      technicalCode: "Code",
      catalog: alertCatalogEn,
    },
    render: {
      title: "Render scaling",
      description: "Instances change only manually; runtime limits do not change Render billing.",
      unavailable: "Render control is not configured in Admin yet.",
      setupTitle: "How to enable manual scaling",
      setupDescription:
        "Configure this in Render, not on this page. Setup alone does not change instance count.",
      setupSteps: [
        "Open Render Dashboard → petmagic-production-api → Environment.",
        "Add the variables listed below and save the API service changes.",
        "Wait for the API redeploy, then return here and refresh diagnostics.",
      ],
      setupVariables: [
        "RENDER_API_KEY",
        "RENDER_GENERATION_WORKER_SERVICE_ID",
        "RENDER_GENERATION_WORKER_EXPECTED_OWNER_ID",
        "RENDER_GENERATION_WORKER_EXPECTED_NAME",
        "RENDER_GENERATION_WORKER_EXPECTED_TYPE",
        "RENDER_GENERATION_WORKER_EXPECTED_REPOSITORY",
      ],
      setupSecretNotice:
        "Values belong only in Render Environment. Admin never reads or displays secrets.",
      service: "Service",
      plan: "Plan",
      region: "Region",
      instances: "Instances",
      topology: "Actual / desired",
      autoscaling: "Render autoscaling is enabled, so manual scaling is blocked.",
      managed: "Manual API control",
      review: "Change instances",
      reviewTitle: "Confirm Render scaling",
      reviewDescription: "Render bills each instance separately and prorates usage time.",
      target: "Target instances",
      reason: "Scaling reason",
      reasonPlaceholder: "For example: controlled scale-up before an ad campaign",
      costNotice:
        "This can immediately change paid capacity. Render Billing is the final source of truth.",
      billingNotice: "Cost and instance count do not change until a separate confirmation.",
      conflictTitle: "Render topology changed",
      conflictMessage:
        "The reviewed baseline is stale. Close review, refresh live state, and verify cost again.",
      reload: "Close and reload",
      confirmUnderstanding: "I understand that cost can change after confirmation.",
      submit: "Start scaling",
      operation: "Current operation",
      cancelOperation: "Cancel operation",
      openDashboard: "Open Render Dashboard",
      operationStatuses: {
        requested: "Requested",
        draining: "Finishing active jobs",
        scaling: "Changing instances",
        verifying: "Verifying topology",
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
