"use client";

import styles from "./admin-pagination.module.css";

export type AdminPaginationLabels = {
  navigation: string;
  previous: string;
  next: string;
  page: (page: number) => string;
};

export type AdminPaginationItem =
  { type: "page"; page: number } | { type: "ellipsis"; key: "start" | "end" };

type AdminPaginationProps = {
  page: number;
  totalPages: number;
  labels: AdminPaginationLabels;
  onPageChange: (page: number) => void;
  siblingCount?: number;
  disabled?: boolean;
  hideWhenSinglePage?: boolean;
  className?: string;
};

function normalizePositiveInteger(value: number) {
  return Number.isFinite(value) ? Math.max(1, Math.trunc(value)) : 1;
}

export function getAdminPaginationItems(
  page: number,
  totalPages: number,
  siblingCount = 1
): AdminPaginationItem[] {
  const normalizedTotalPages = normalizePositiveInteger(totalPages);
  const normalizedPage = Math.min(normalizePositiveInteger(page), normalizedTotalPages);
  const normalizedSiblingCount = Math.min(Math.max(Math.trunc(siblingCount), 0), 2);
  let start = Math.max(2, normalizedPage - normalizedSiblingCount);
  let end = Math.min(normalizedTotalPages - 1, normalizedPage + normalizedSiblingCount);
  if (start === 3) {
    start = 2;
  }
  if (end === normalizedTotalPages - 2) {
    end = normalizedTotalPages - 1;
  }
  const items: AdminPaginationItem[] = [{ type: "page", page: 1 }];

  if (start > 2) {
    items.push({ type: "ellipsis", key: "start" });
  }
  for (let candidate = start; candidate <= end; candidate += 1) {
    items.push({ type: "page", page: candidate });
  }
  if (end < normalizedTotalPages - 1) {
    items.push({ type: "ellipsis", key: "end" });
  }
  if (normalizedTotalPages > 1) {
    items.push({ type: "page", page: normalizedTotalPages });
  }

  return items;
}

export function AdminPagination({
  page,
  totalPages,
  labels,
  onPageChange,
  siblingCount = 1,
  disabled = false,
  hideWhenSinglePage = true,
  className,
}: AdminPaginationProps) {
  const normalizedTotalPages = normalizePositiveInteger(totalPages);
  const normalizedPage = Math.min(normalizePositiveInteger(page), normalizedTotalPages);

  if (hideWhenSinglePage && normalizedTotalPages <= 1) {
    return null;
  }

  const rootClassName = className ? `${styles.pagination} ${className}` : styles.pagination;
  const items = getAdminPaginationItems(normalizedPage, normalizedTotalPages, siblingCount);

  return (
    <nav className={rootClassName} aria-label={labels.navigation}>
      <button
        type="button"
        className={styles.directionButton}
        onClick={() => onPageChange(normalizedPage - 1)}
        disabled={disabled || normalizedPage <= 1}
        aria-label={labels.previous}
      >
        <span aria-hidden="true">←</span>
        <span>{labels.previous}</span>
      </button>
      <div className={styles.pages}>
        {items.map((item) =>
          item.type === "ellipsis" ? (
            <span key={item.key} className={styles.ellipsis} aria-hidden="true">
              …
            </span>
          ) : (
            <button
              key={item.page}
              type="button"
              className={styles.pageButton}
              data-current={item.page === normalizedPage ? "true" : "false"}
              onClick={() => onPageChange(item.page)}
              disabled={disabled || item.page === normalizedPage}
              aria-label={labels.page(item.page)}
              aria-current={item.page === normalizedPage ? "page" : undefined}
            >
              {item.page}
            </button>
          )
        )}
      </div>
      <button
        type="button"
        className={styles.directionButton}
        onClick={() => onPageChange(normalizedPage + 1)}
        disabled={disabled || normalizedPage >= normalizedTotalPages}
        aria-label={labels.next}
      >
        <span>{labels.next}</span>
        <span aria-hidden="true">→</span>
      </button>
    </nav>
  );
}
