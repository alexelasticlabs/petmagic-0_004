"use client";

import { useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";

import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  maximumPersistedSelectionCount,
  readPersistedSelection,
  selectionStoragePrefix,
} from "@/components/email-recipient-selection";
import { Button } from "@/components/ui/button";
import styles from "@/components/users-bulk-email-dialog.module.css";
import { getUsersManagementPageText } from "@/components/users-management-page.content";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchUsers, useAuthSession } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText, shortIdentifier } from "@/lib/sensitive-display";

export function EmailRecipientPicker({
  locale,
  selectedIds,
  onChange,
}: {
  locale: Locale;
  selectedIds: readonly string[];
  onChange: (ids: readonly string[]) => void;
}) {
  const copy = getUsersManagementPageText(locale);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [page, setPage] = useState(1);
  const session = useAuthSession();
  const [labels, setLabels] = useState<Record<string, string>>(() =>
    session
      ? Object.fromEntries(
          [
            ...readPersistedSelection(`${selectionStoragePrefix}:${session.user.userId}`).values(),
          ].map((item) => [item.id, item.label])
        )
      : {}
  );
  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedSearch(search.trim());
      setPage(1);
    }, 350);
    return () => window.clearTimeout(timer);
  }, [search]);
  const query = { skip: (page - 1) * 8, take: 8, search: debouncedSearch, status: "active" };
  const usersQuery = useQuery({
    queryKey: adminQueryKeys.users(query),
    queryFn: ({ signal }) => fetchUsers(query, signal),
  });
  const totalPages = Math.max(1, Math.ceil((usersQuery.data?.totalCount ?? 0) / 8));

  return (
    <div className={styles.recipientPicker}>
      <label className={styles.field}>
        <span>{copy.searchLabel}</span>
        <input
          value={search}
          maxLength={120}
          placeholder={copy.searchPlaceholder}
          onChange={(event) => setSearch(event.target.value)}
        />
      </label>
      <div className={styles.recipientSummary}>
        <strong role="status">
          {copy.bulkEmail.selectedCount(selectedIds.length)} / {maximumPersistedSelectionCount}
        </strong>
        {selectedIds.length ? (
          <Button variant="secondary" size="sm" onClick={() => onChange([])}>
            {copy.bulkEmail.selectionClear}
          </Button>
        ) : null}
      </div>
      {selectedIds.length ? (
        <ul className={styles.selectedRecipients} aria-label={copy.bulkEmail.selectionTrayLabel}>
          {selectedIds.map((id) => (
            <li key={id}>
              <span>{labels[id] ?? shortIdentifier(id)}</span>
              <button
                type="button"
                aria-label={
                  copy.bulkEmail.selectionRemove + ": " + (labels[id] ?? shortIdentifier(id))
                }
                onClick={() => onChange(selectedIds.filter((value) => value !== id))}
              >
                ×
              </button>
            </li>
          ))}
        </ul>
      ) : null}
      {usersQuery.isPending ? (
        <p role="status">{copy.loadingTitle}</p>
      ) : usersQuery.isError ? (
        <p role="alert">
          {copy.summaryUnavailable}{" "}
          <Button variant="secondary" size="sm" onClick={() => void usersQuery.refetch()}>
            {copy.summaryRetry}
          </Button>
        </p>
      ) : (
        <>
          {usersQuery.data.items.length === 0 ? (
            <p>{copy.noSearchResults}</p>
          ) : (
            <ul className={styles.recipientResults}>
              {usersQuery.data.items.map((user) => {
                const label = sanitizeSensitiveText(
                  user.displayName?.trim() || maskEmail(user.email),
                  96
                );
                const eligible = user.isActive && user.emailConfirmed;
                const selected = selectedIds.includes(user.userId);
                return (
                  <li key={user.userId}>
                    <label
                      className={styles.recipientRow}
                      title={eligible ? undefined : copy.bulkEmail.unavailableRecipientLabel}
                    >
                      <input
                        type="checkbox"
                        checked={selected}
                        disabled={
                          !eligible ||
                          (!selected && selectedIds.length >= maximumPersistedSelectionCount)
                        }
                        aria-label={copy.bulkEmail.selectUserLabel(label)}
                        onChange={(event) => {
                          setLabels((current) => ({ ...current, [user.userId]: label }));
                          onChange(
                            event.target.checked
                              ? [...selectedIds, user.userId]
                              : selectedIds.filter((id) => id !== user.userId)
                          );
                        }}
                      />
                      <span>
                        <strong>{label}</strong>
                        <small>
                          {maskEmail(user.email)}
                          {!eligible ? " · " + copy.unconfirmedBadge : ""}
                        </small>
                      </span>
                    </label>
                  </li>
                );
              })}
            </ul>
          )}
          <AdminPagination
            page={page}
            totalPages={totalPages}
            disabled={usersQuery.isFetching}
            labels={{
              navigation: copy.bulkEmail.audienceSelected,
              previous: copy.previousPageLabel,
              next: copy.nextPageLabel,
              page: (value) => copy.pageInfo + " " + value,
            }}
            onPageChange={setPage}
          />
        </>
      )}
    </div>
  );
}
