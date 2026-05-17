import { type TemplatePromoBadgeMode, type TemplateStatus } from "@/lib/api-client";

export const NEW_PROMO_BADGE_DAYS = 30;
export const TRENDING_PROMO_BADGE_DAYS = 14;
export const POPULAR_PROMO_BADGE_TOKEN_COST_THRESHOLD = 60;
export const FUNNY_PROMO_BADGE_KEYWORDS = ["funny", "meme", "viral", "dance", "lol", "cute"];

type AutoPromoBadgeContext = {
  createdAtUtc?: string | null;
  updatedAtUtc?: string | null;
  status?: TemplateStatus;
  isPremium: boolean;
  tokenCost: number;
  searchFragments: ReadonlyArray<string | null | undefined>;
  now?: number;
};

export function resolveAutoPromoBadge(context: AutoPromoBadgeContext): Exclude<TemplatePromoBadgeMode, "Auto"> | undefined {
  const now = context.now ?? Date.now();
  const createdAt = context.createdAtUtc ? new Date(context.createdAtUtc).getTime() : now;
  const updatedAt = context.updatedAtUtc ? new Date(context.updatedAtUtc).getTime() : now;

  if (createdAt >= now - NEW_PROMO_BADGE_DAYS * 24 * 60 * 60 * 1000) {
    return "New";
  }

  if (context.status === "Active" && updatedAt >= now - TRENDING_PROMO_BADGE_DAYS * 24 * 60 * 60 * 1000) {
    return "Trending";
  }

  if (context.status === "Active" && (context.isPremium || context.tokenCost >= POPULAR_PROMO_BADGE_TOKEN_COST_THRESHOLD)) {
    return "Popular";
  }

  const searchText = context.searchFragments
    .filter((fragment): fragment is string => typeof fragment === "string" && fragment.trim().length > 0)
    .join(" ")
    .toLowerCase();

  return FUNNY_PROMO_BADGE_KEYWORDS.some((keyword) => searchText.includes(keyword))
    ? "Funny"
    : undefined;
}