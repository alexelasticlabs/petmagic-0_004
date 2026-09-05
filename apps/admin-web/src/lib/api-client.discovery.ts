import { apiRequest, encodePathSegment } from "./api-client.core";

export const discoveryLocales = ["en", "ru", "de", "es", "fr", "it", "pl"] as const;
export type DiscoveryLocale = (typeof discoveryLocales)[number];
export type DiscoveryCopy = { title: string; subtitle: string };
export type DiscoverySection = {
  id: string;
  categoryId: string;
  isEnabled: boolean;
  showInCarousel: boolean;
  showAsRail: boolean;
  heroTemplateId: string | null;
  selectionMode: "Latest" | "Manual" | "Hybrid";
  itemLimit: number;
  templateIds: string[];
  copy: Partial<Record<DiscoveryLocale, DiscoveryCopy>>;
};
export type DiscoveryDocument = {
  schemaVersion: number;
  copy: Partial<Record<DiscoveryLocale, DiscoveryCopy>>;
  searchEnabled: boolean;
  carouselEnabled: boolean;
  autoplayEnabled: boolean;
  autoplayIntervalMs: number;
  sections: DiscoverySection[];
};
export type DiscoveryRevision = {
  id: string;
  number: number;
  editVersion: number;
  state: "Draft" | "Published" | "Discarded";
  document: DiscoveryDocument;
  basedOnRevisionId: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
  publishedAtUtc: string | null;
  createdBy: string;
  updatedBy: string;
  publishedBy: string | null;
  reason: string | null;
};
export type DiscoveryAdmin = {
  pageVersion: number;
  published: DiscoveryRevision | null;
  draft: DiscoveryRevision | null;
};
export type DiscoveryHistoryItem = Pick<
  DiscoveryRevision,
  "id" | "number" | "state" | "updatedAtUtc" | "publishedAtUtc" | "updatedBy" | "reason"
>;
export type DiscoveryIssue = { path: string; code: string; message: string };
export type DiscoveryValidation = { isValid: boolean; issues: DiscoveryIssue[] };
export type DiscoveryFeedItem = {
  id: string;
  title: string;
  type: string;
  tokenCost: number;
  thumbnailUrl: string | null;
  media: {
    thumbnailUrl: string | null;
    feedLoopLowUrl: string | null;
    animatedPreviewUrl: string | null;
    mediaKind: string;
  };
};
export type DiscoveryPreview = {
  revision: number | null;
  page: {
    title: string;
    subtitle: string;
    searchEnabled: boolean;
    carouselEnabled: boolean;
    autoplayEnabled: boolean;
    autoplayIntervalMs: number;
  } | null;
  sections: {
    sectionId: string;
    categoryId: string;
    category: string;
    title: string;
    subtitle: string;
    showInCarousel: boolean;
    showAsRail: boolean;
    items: DiscoveryFeedItem[];
  }[];
};

const base = "/api/admin/templates/discovery";
const draftPath = (id: string) => `${base}/drafts/${encodePathSegment(id)}`;
export const fetchDiscovery = (signal?: AbortSignal) =>
  apiRequest<DiscoveryAdmin>(`${base}/`, { method: "GET", signal, cache: "no-store" });
export const fetchDiscoveryHistory = (skip = 0, signal?: AbortSignal) =>
  apiRequest<{ items: DiscoveryHistoryItem[]; hasMore: boolean }>(
    `${base}/revisions?skip=${Math.max(0, skip)}&take=20`,
    { method: "GET", signal, cache: "no-store" }
  );
export const createDiscoveryDraft = (expectedPageVersion: number, sourceRevisionId?: string) =>
  apiRequest<DiscoveryRevision>(`${base}/drafts`, {
    method: "POST",
    body: JSON.stringify({ expectedPageVersion, sourceRevisionId }),
  });
export const saveDiscoveryDraft = (
  id: string,
  expectedVersion: number,
  document: DiscoveryDocument
) =>
  apiRequest<DiscoveryRevision>(draftPath(id), {
    method: "PUT",
    body: JSON.stringify({ expectedVersion, document }),
  });
export const validateDiscovery = (id: string, signal?: AbortSignal) =>
  apiRequest<DiscoveryValidation>(`${draftPath(id)}/validate`, { method: "POST", signal });
export const previewDiscovery = (id: string, locale: DiscoveryLocale, signal?: AbortSignal) =>
  apiRequest<DiscoveryPreview>(`${draftPath(id)}/preview?locale=${locale}`, {
    method: "GET",
    signal,
    cache: "no-store",
  });
export const publishDiscovery = (
  id: string,
  expectedVersion: number,
  expectedPageVersion: number,
  reason: string,
  idempotencyKey: string
) =>
  apiRequest<DiscoveryRevision>(`${draftPath(id)}/publish`, {
    method: "POST",
    headers: { "Idempotency-Key": idempotencyKey },
    body: JSON.stringify({ expectedVersion, expectedPageVersion, reason }),
  });
export const discardDiscoveryDraft = (
  id: string,
  expectedVersion: number,
  expectedPageVersion: number
) =>
  apiRequest<boolean>(`${draftPath(id)}/discard`, {
    method: "POST",
    body: JSON.stringify({ expectedVersion, expectedPageVersion }),
  });
