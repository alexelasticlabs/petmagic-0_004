import type {
  AdminTemplateStatistics,
  AdminTemplateTrendPoint,
  TemplateGenerationJobStatus,
  TemplateStatus,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type PeriodKey = "7d" | "30d" | "90d" | "all";
export type TrendMetricKey =
  | "totalRuns"
  | "completedRuns"
  | "failedRuns"
  | "totalTokenCost"
  | "averageGenerationSeconds";

export type TrendTotals = {
  totalRuns: number;
  queuedRuns: number;
  processingRuns: number;
  completedRuns: number;
  failedRuns: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  averageGenerationSeconds: number | null;
  successRatePercent: number;
};

export type PeriodAnalytics = {
  currentPoints: AdminTemplateTrendPoint[];
  previousPoints: AdminTemplateTrendPoint[];
  current: TrendTotals;
  previous: TrendTotals | null;
};

const PERIOD_DAY_COUNTS: Record<Exclude<PeriodKey, "all">, number> = {
  "7d": 7,
  "30d": 30,
  "90d": 90,
};

export function buildPeriodAnalytics(
  points: readonly AdminTemplateTrendPoint[],
  period: PeriodKey
): PeriodAnalytics {
  const sortedPoints = [...points].sort(
    (left, right) => getUtcDay(left.dateUtc) - getUtcDay(right.dateUtc)
  );

  if (!sortedPoints.length) {
    return {
      currentPoints: [],
      previousPoints: [],
      current: summarizeTrendPoints([]),
      previous: null,
    };
  }

  if (period === "all") {
    return {
      currentPoints: sortedPoints,
      previousPoints: [],
      current: summarizeTrendPoints(sortedPoints),
      previous: null,
    };
  }

  const dayMs = 24 * 60 * 60 * 1000;
  const days = PERIOD_DAY_COUNTS[period];
  const latestDay = Math.max(...sortedPoints.map((point) => getUtcDay(point.dateUtc)));
  const currentStart = latestDay - (days - 1) * dayMs;
  const previousStart = currentStart - days * dayMs;
  const previousEnd = currentStart - dayMs;
  const currentPoints = sortedPoints.filter((point) => {
    const day = getUtcDay(point.dateUtc);
    return day >= currentStart && day <= latestDay;
  });
  const previousPoints = sortedPoints.filter((point) => {
    const day = getUtcDay(point.dateUtc);
    return day >= previousStart && day <= previousEnd;
  });

  return {
    currentPoints,
    previousPoints,
    current: summarizeTrendPoints(currentPoints),
    previous: previousPoints.length ? summarizeTrendPoints(previousPoints) : null,
  };
}

export function summarizeTrendPoints(points: readonly AdminTemplateTrendPoint[]): TrendTotals {
  const totals = points.reduce(
    (accumulator, point) => {
      accumulator.totalRuns += point.totalRuns;
      accumulator.queuedRuns += point.queuedRuns;
      accumulator.processingRuns += point.processingRuns;
      accumulator.completedRuns += point.completedRuns;
      accumulator.failedRuns += point.failedRuns;
      accumulator.totalTokenCost += point.totalTokenCost;
      accumulator.totalProviderCostUsd += point.totalProviderCostUsd;

      if (typeof point.averageGenerationSeconds === "number" && point.completedRuns > 0) {
        accumulator.durationSeconds += point.averageGenerationSeconds * point.completedRuns;
        accumulator.durationSamples += point.completedRuns;
      }

      return accumulator;
    },
    {
      totalRuns: 0,
      queuedRuns: 0,
      processingRuns: 0,
      completedRuns: 0,
      failedRuns: 0,
      totalTokenCost: 0,
      totalProviderCostUsd: 0,
      durationSeconds: 0,
      durationSamples: 0,
    }
  );

  return {
    totalRuns: totals.totalRuns,
    queuedRuns: totals.queuedRuns,
    processingRuns: totals.processingRuns,
    completedRuns: totals.completedRuns,
    failedRuns: totals.failedRuns,
    totalTokenCost: totals.totalTokenCost,
    totalProviderCostUsd: totals.totalProviderCostUsd,
    averageGenerationSeconds:
      totals.durationSamples > 0 ? totals.durationSeconds / totals.durationSamples : null,
    successRatePercent: totals.totalRuns > 0 ? (totals.completedRuns / totals.totalRuns) * 100 : 0,
  };
}

export function totalsFromStatistics(statistics: AdminTemplateStatistics): TrendTotals {
  return {
    totalRuns: statistics.totalRuns,
    queuedRuns: statistics.queuedRuns,
    processingRuns: statistics.processingRuns,
    completedRuns: statistics.completedRuns,
    failedRuns: statistics.failedRuns,
    totalTokenCost: statistics.totalTokenCost,
    totalProviderCostUsd: statistics.totalProviderCostUsd,
    averageGenerationSeconds: statistics.averageGenerationSeconds ?? null,
    successRatePercent: statistics.successRatePercent,
  };
}

export function calculateChange(current: number, previous: number | null | undefined) {
  if (typeof previous !== "number" || Number.isNaN(previous) || previous === 0) {
    return null;
  }

  return ((current - previous) / Math.abs(previous)) * 100;
}

export function getTrendMetricValue(point: AdminTemplateTrendPoint, metric: TrendMetricKey) {
  if (metric === "averageGenerationSeconds") {
    return point.averageGenerationSeconds ?? 0;
  }

  return point[metric];
}

export function buildChartTicks(maxValue: number) {
  const ceiling = Math.max(1, Math.ceil(maxValue));

  if (ceiling <= 4) {
    return Array.from({ length: ceiling + 1 }, (_, index) => ceiling - index);
  }

  const step = Math.ceil(ceiling / 4);
  const top = step * 4;
  return [top, top - step, top - step * 2, step, 0];
}

export function formatTrendValue(
  value: number,
  metric: TrendMetricKey,
  locale: Locale,
  failedRunsLabel: string
) {
  if (metric === "totalTokenCost") {
    return formatTokens(value, locale === "ru");
  }

  if (metric === "averageGenerationSeconds") {
    return formatDuration(value, locale === "ru");
  }

  return `${formatNumber(value, locale)} ${metric === "failedRuns" ? failedRunsLabel.toLowerCase() : ""}`.trim();
}

export function getStatusBadgeClassName(status: TemplateStatus) {
  if (status === "Active") {
    return "statusBadge_active";
  }

  if (status === "Archived") {
    return "statusBadge_archived";
  }

  return "statusBadge_draft";
}

export function getJobStatusClassName(status: TemplateGenerationJobStatus) {
  if (status === "Completed") {
    return "statusChip_success";
  }

  if (status === "Failed") {
    return "statusChip_danger";
  }

  if (status === "Processing") {
    return "statusChip_warning";
  }

  return "statusChip_info";
}

export function formatJobStatus(status: TemplateGenerationJobStatus, isRu: boolean) {
  if (!isRu) {
    return status;
  }

  if (status === "Completed") {
    return "Успешно";
  }

  if (status === "Failed") {
    return "Ошибка";
  }

  if (status === "Processing") {
    return "В работе";
  }

  return "В очереди";
}

export function formatFailureCode(value: string, unknownFailureLabel: string) {
  if (!value || value === "templates.unknown_failure") {
    return unknownFailureLabel;
  }

  return sanitizeSensitiveText(value, 120);
}

export function formatAnalyticsValue(value: string | null | undefined) {
  if (!value) {
    return "-";
  }

  const safeValue = sanitizeSensitiveText(value, 120);
  return safeValue.toUpperCase() === safeValue && safeValue.length <= 3
    ? safeValue
    : safeValue.replace(/[_-]+/g, " ");
}

export function formatPercent(value: number, isRu: boolean) {
  const formatter = new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", {
    minimumFractionDigits: value % 1 === 0 ? 0 : 1,
    maximumFractionDigits: 1,
  });

  return `${formatter.format(value)}%`;
}

export function formatDelta(value: number, isRu: boolean) {
  const sign = value > 0 ? "+" : "";
  return `${sign}${formatPercent(value, isRu)}`;
}

export function formatNumber(value: number, locale: Locale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  }).format(value);
}

export function formatTokens(value: number, isRu: boolean) {
  const formatter = new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  });

  return `${formatter.format(value)} PawSpark`;
}

export function formatUsd(value: number | null | undefined, locale: Locale) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return "-";
  }

  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(value);
}

export function formatDuration(value: number | null | undefined, isRu: boolean) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return "-";
  }

  const rounded = Math.round(value);
  const minutes = Math.floor(rounded / 60);
  const seconds = rounded % 60;

  if (minutes > 0) {
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  }

  return `${rounded} ${isRu ? "сек" : "sec"}`;
}

export function formatRangeDuration(
  startedAtUtc: string | null | undefined,
  completedAtUtc: string | null | undefined,
  isRu: boolean
) {
  if (!startedAtUtc || !completedAtUtc) {
    return "-";
  }

  const started = new Date(startedAtUtc).getTime();
  const completed = new Date(completedAtUtc).getTime();
  if (Number.isNaN(started) || Number.isNaN(completed) || completed < started) {
    return "-";
  }

  return formatDuration(Math.round((completed - started) / 1000), isRu);
}

export function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export function formatShortDate(value: string, locale: Locale) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
  }).format(date);
}

export function formatModelSummary(
  preprocessingModel: string | null | undefined,
  klingModel: string | null | undefined
) {
  const values = [preprocessingModel, klingModel].filter(Boolean).map((value) => {
    return formatModelValue(value);
  });

  return values.length ? values.join(" + ") : "-";
}

export function formatModelValue(value: string | null | undefined) {
  if (!value) {
    return "-";
  }

  const safeValue = sanitizeSensitiveText(value, 120);
  if (safeValue.includes("://")) {
    return safeValue;
  }

  const parts = safeValue.split("/");
  return parts.length >= 2 ? parts.slice(-2).join("/") : safeValue;
}

export function shortenId(value: string) {
  return value.length > 13 ? `${value.slice(0, 8)}...${value.slice(-4)}` : value;
}

function getUtcDay(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return 0;
  }

  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}
