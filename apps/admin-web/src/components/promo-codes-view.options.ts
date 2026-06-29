import {
  buildPromoCodesPageSizeLabel,
  getPromoCodesViewText,
} from "@/components/promo-codes-view.content";
import { type PromoSortMode, type PromoStatusFilter } from "@/components/promo-codes-view.helpers";
import { type SelectOption } from "@/components/ui/select";
import { type AdminRedeemRewardKind } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

const PAGE_SIZE_OPTIONS = [6, 10, 20] as const;

export function buildPromoCodesViewOptions(
  locale: Locale,
  text: ReturnType<typeof getDictionary>
): {
  statusTabs: Array<{ value: PromoStatusFilter; label: string }>;
  statusOptions: SelectOption[];
  rewardOptions: SelectOption[];
  formStatusOptions: SelectOption[];
  sortOptions: SelectOption[];
  pageSizeOptions: SelectOption[];
} {
  const promoText = getPromoCodesViewText(locale);
  const statusTabs: Array<{ value: PromoStatusFilter; label: string }> = [
    { value: "all", label: promoText.statusTabAll },
    { value: "active", label: promoText.statusTabActive },
    { value: "draft", label: promoText.statusTabDraft },
    { value: "paused", label: promoText.statusTabPaused },
    { value: "expired", label: promoText.statusTabExpired },
    { value: "archived", label: promoText.statusTabArchived },
  ];

  const statusOptions: SelectOption[] = [
    { value: "all", label: text.promoCodesStatusAll, tone: "neutral" },
    { value: "draft", label: text.promoCodesStatusDraft, tone: "neutral" },
    { value: "active", label: text.promoCodesStatusActiveOption, tone: "recommended" },
    { value: "scheduled", label: text.promoCodesStatusScheduled, tone: "fast" },
    { value: "paused", label: text.promoCodesStatusPaused, tone: "premium" },
    { value: "exhausted", label: text.promoCodesStatusLimitReached, tone: "premium" },
    { value: "expired", label: text.promoCodesStatusExpired, tone: "neutral" },
    { value: "archived", label: text.promoCodesStatusArchived, tone: "neutral" },
  ];

  const rewardOptions: SelectOption[] = [
    { value: "all", label: promoText.rewardAllLabel, tone: "neutral" },
    { value: "spark", label: text.promoCodesRewardTypeSparkOption, tone: "recommended" },
  ];

  const formStatusOptions: SelectOption[] = [
    { value: "active", label: text.promoCodesStatusActiveOption, tone: "recommended" },
    { value: "paused", label: text.promoCodesStatusPausedOption, tone: "premium" },
  ];

  const sortOptions: SelectOption[] = [
    { value: "updated", label: text.promoCodesSortUpdated, tone: "recommended" },
    { value: "usage", label: text.promoCodesSortUsage, tone: "premium" },
    { value: "reward", label: text.promoCodesSortReward, tone: "fast" },
    { value: "code", label: text.promoCodesSortCode, tone: "neutral" },
    { value: "expiry", label: text.promoCodesSortExpiry, tone: "neutral" },
  ];

  const pageSizeOptions: SelectOption[] = PAGE_SIZE_OPTIONS.map((option) => ({
    value: option.toString(),
    label: buildPromoCodesPageSizeLabel(locale, option),
    tone: "neutral",
  }));

  return {
    statusTabs,
    statusOptions,
    rewardOptions,
    formStatusOptions,
    sortOptions,
    pageSizeOptions,
  };
}

export type PromoCodesViewRewardFilter = "all" | AdminRedeemRewardKind;
export type PromoCodesViewSortMode = PromoSortMode;
