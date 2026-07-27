export const ADMIN_URL_STATE_KEYS = {
  sort: "sort",
  page: "page",
  selected: "selected",
  tab: "tab",
} as const;

export type AdminUrlState = {
  filters: Readonly<Record<string, string>>;
  sort: string | null;
  page: number;
  selected: string | null;
  tab: string | null;
};

export type AdminUrlStatePatch = {
  filters?: Readonly<Record<string, string | null | undefined>>;
  sort?: string | null;
  page?: number | null;
  selected?: string | null;
  tab?: string | null;
};

type ReadAdminUrlStateOptions = {
  filterKeys?: readonly string[];
  defaultPage?: number;
};

type UpdateAdminUrlStateOptions = {
  resetPageOnQueryChange?: boolean;
};

type URLSearchParamsLike = Pick<URLSearchParams, "get" | "toString">;

const adminUrlFilterKeyPattern = /^[a-z][a-z0-9_-]{0,63}$/i;
const maximumAdminUrlValueLength = 256;
const reservedAdminUrlStateKeys = new Set<string>(Object.values(ADMIN_URL_STATE_KEYS));

function normalizeAdminUrlValue(value: string | null | undefined) {
  const normalized = value?.trim() ?? "";
  return normalized ? normalized.slice(0, maximumAdminUrlValueLength) : null;
}

function normalizeAdminUrlFilterKey(key: string) {
  const normalized = key.trim();
  return adminUrlFilterKeyPattern.test(normalized) && !reservedAdminUrlStateKeys.has(normalized)
    ? normalized
    : null;
}

function normalizeAdminUrlPage(value: number, fallback = 1) {
  return Number.isSafeInteger(value) && value > 0 ? value : fallback;
}

function setAdminUrlValue(searchParams: URLSearchParams, key: string, value: string | null) {
  if (value) {
    searchParams.set(key, value);
  } else {
    searchParams.delete(key);
  }
}

export function readAdminUrlState(
  searchParams: URLSearchParamsLike,
  { filterKeys = [], defaultPage = 1 }: ReadAdminUrlStateOptions = {}
): AdminUrlState {
  const filters: Record<string, string> = {};
  for (const filterKey of filterKeys) {
    const normalizedKey = normalizeAdminUrlFilterKey(filterKey);
    const value = normalizedKey ? normalizeAdminUrlValue(searchParams.get(normalizedKey)) : null;
    if (normalizedKey && value) {
      filters[normalizedKey] = value;
    }
  }

  const rawPage = Number(searchParams.get(ADMIN_URL_STATE_KEYS.page));

  return {
    filters,
    sort: normalizeAdminUrlValue(searchParams.get(ADMIN_URL_STATE_KEYS.sort)),
    page: normalizeAdminUrlPage(rawPage, normalizeAdminUrlPage(defaultPage)),
    selected: normalizeAdminUrlValue(searchParams.get(ADMIN_URL_STATE_KEYS.selected)),
    tab: normalizeAdminUrlValue(searchParams.get(ADMIN_URL_STATE_KEYS.tab)),
  };
}

export function updateAdminUrlState(
  currentSearchParams: URLSearchParamsLike,
  patch: AdminUrlStatePatch,
  { resetPageOnQueryChange = true }: UpdateAdminUrlStateOptions = {}
) {
  const nextSearchParams = new URLSearchParams(currentSearchParams.toString());

  if (patch.filters) {
    for (const [rawKey, rawValue] of Object.entries(patch.filters)) {
      const key = normalizeAdminUrlFilterKey(rawKey);
      if (key) {
        setAdminUrlValue(nextSearchParams, key, normalizeAdminUrlValue(rawValue));
      }
    }
  }

  if (patch.sort !== undefined) {
    setAdminUrlValue(
      nextSearchParams,
      ADMIN_URL_STATE_KEYS.sort,
      normalizeAdminUrlValue(patch.sort)
    );
  }
  if (patch.selected !== undefined) {
    setAdminUrlValue(
      nextSearchParams,
      ADMIN_URL_STATE_KEYS.selected,
      normalizeAdminUrlValue(patch.selected)
    );
  }
  if (patch.tab !== undefined) {
    setAdminUrlValue(nextSearchParams, ADMIN_URL_STATE_KEYS.tab, normalizeAdminUrlValue(patch.tab));
  }

  const queryChanged = patch.filters !== undefined || patch.sort !== undefined;
  if (patch.page !== undefined) {
    const normalizedPage = patch.page === null ? 1 : normalizeAdminUrlPage(patch.page);
    setAdminUrlValue(
      nextSearchParams,
      ADMIN_URL_STATE_KEYS.page,
      normalizedPage > 1 ? String(normalizedPage) : null
    );
  } else if (queryChanged && resetPageOnQueryChange) {
    nextSearchParams.delete(ADMIN_URL_STATE_KEYS.page);
  }

  return nextSearchParams;
}

export function buildAdminUrlStateHref(
  pathname: string,
  currentSearchParams: URLSearchParamsLike,
  patch: AdminUrlStatePatch,
  options?: UpdateAdminUrlStateOptions
) {
  const nextSearch = updateAdminUrlState(currentSearchParams, patch, options).toString();
  return nextSearch ? `${pathname}?${nextSearch}` : pathname;
}
