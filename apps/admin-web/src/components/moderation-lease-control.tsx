"use client";

import { useMutation, useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";

import styles from "@/components/moderation-lease-control.module.css";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  claimAdminModerationItem,
  fetchUsers,
  handoffAdminModerationItem,
  releaseAdminModerationItem,
  type AdminModerationQueueItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type LeaseEditor = "release" | "handoff" | null;

const conflictCodes = new Set([
  "templates.moderation_lease_conflict",
  "templates.moderation_lease_required",
  "templates.moderation_lease_not_owned",
  "templates.moderation_item_not_pending",
]);

function errorCode(error: unknown) {
  if (!error || typeof error !== "object" || !("code" in error)) return null;
  return typeof (error as { code?: unknown }).code === "string"
    ? (error as { code: string }).code
    : null;
}

export function hasActiveModerationLease(item: AdminModerationQueueItem, now = Date.now()) {
  if (!item.leaseOwnerUserId || !item.leaseExpiresAtUtc) return false;
  const expiresAt = Date.parse(item.leaseExpiresAtUtc);
  return Number.isFinite(expiresAt) && expiresAt > now;
}

type ModerationLeaseControlProps = {
  item: AdminModerationQueueItem;
  currentUserId: string | null;
  roles: readonly string[];
  locale: Locale;
  onUpdated: (item: AdminModerationQueueItem) => void;
  onConflict: (message: string) => void;
};

export function ModerationLeaseControl({
  item,
  currentUserId,
  roles,
  locale,
  onUpdated,
  onConflict,
}: ModerationLeaseControlProps) {
  const [editor, setEditor] = useState<LeaseEditor>(null);
  const [reason, setReason] = useState("");
  const [assigneeUserId, setAssigneeUserId] = useState("");
  const [actionError, setActionError] = useState<string | null>(null);
  const isAdmin = roles.includes("Admin");
  const isModerator = roles.includes("Moderator");
  const leaseActive = hasActiveModerationLease(item);
  const ownedByCurrentUser =
    leaseActive && Boolean(currentUserId) && item.leaseOwnerUserId === currentUserId;
  const expectedVersion = item.version ?? 0;
  const copy =
    locale === "ru"
      ? {
          title: "Блокировка обработки",
          owner: "Ответственный",
          ownerYou: "Вы",
          ownerOther: "Другой модератор",
          ownerNone: "Свободно",
          expires: "Действует до",
          version: "Версия",
          take: "Взять в работу",
          renew: "Продлить",
          release: "Освободить",
          handoff: "Передать",
          assignee: "Новый ответственный",
          reason: "Причина",
          reasonPlaceholder: "Причина будет сохранена в audit trail",
          reasonHint: "От 3 до 500 символов.",
          confirmRelease: "Подтвердить освобождение",
          confirmHandoff: "Подтвердить передачу",
          cancel: "Отмена",
          loadingOperators: "Загрузка операторов…",
          noOperators: "Нет доступных операторов",
          failed: "Не удалось изменить блокировку обработки.",
          conflict:
            "Очередь уже изменилась или элемент занят другим модератором. Данные обновлены — проверьте состояние ещё раз.",
        }
      : {
          title: "Processing lease",
          owner: "Owner",
          ownerYou: "You",
          ownerOther: "Another moderator",
          ownerNone: "Available",
          expires: "Expires",
          version: "Version",
          take: "Claim",
          renew: "Renew",
          release: "Release",
          handoff: "Handoff",
          assignee: "New owner",
          reason: "Reason",
          reasonPlaceholder: "The reason is stored in the audit trail",
          reasonHint: "3 to 500 characters.",
          confirmRelease: "Confirm release",
          confirmHandoff: "Confirm handoff",
          cancel: "Cancel",
          loadingOperators: "Loading operators…",
          noOperators: "No eligible operators",
          failed: "Could not update the processing lease.",
          conflict:
            "The queue changed or another moderator owns this item. Data was refreshed; review the current state.",
        };

  const operatorsQuery = useQuery({
    queryKey: adminQueryKeys.users({ scope: "moderation-handoff", eventId: item.eventId }),
    queryFn: ({ signal }) => fetchUsers({ skip: 0, take: 100, sort: "last_activity_desc" }, signal),
    enabled: isAdmin && editor === "handoff",
    staleTime: 60_000,
  });

  const operatorOptions = useMemo(
    () =>
      (operatorsQuery.data?.items ?? [])
        .filter(
          (user) =>
            user.isActive &&
            user.userId !== item.leaseOwnerUserId &&
            (user.roles.includes("Admin") || user.roles.includes("Moderator"))
        )
        .map((user) => ({
          value: user.userId,
          label: `${sanitizeSensitiveText(user.displayName?.trim() || maskEmail(user.email), 96)} · ${
            user.roles.includes("Admin") ? "Admin" : "Moderator"
          }`,
        })),
    [item.leaseOwnerUserId, operatorsQuery.data?.items]
  );

  const mutation = useMutation({
    mutationFn: async (action: "claim" | "release" | "handoff") => {
      if (action === "claim") {
        return claimAdminModerationItem(item.eventId, {
          expectedVersion,
          leaseMinutes: 15,
        });
      }
      if (action === "release") {
        return releaseAdminModerationItem(item.eventId, {
          expectedVersion,
          reason,
        });
      }
      return handoffAdminModerationItem(item.eventId, {
        assigneeUserId,
        expectedVersion,
        reason,
        leaseMinutes: 15,
      });
    },
    onSuccess: (updatedItem) => {
      setEditor(null);
      setReason("");
      setAssigneeUserId("");
      setActionError(null);
      onUpdated(updatedItem);
    },
    onError: (error) => {
      const code = errorCode(error);
      if (code && conflictCodes.has(code)) {
        setEditor(null);
        setReason("");
        setAssigneeUserId("");
        setActionError(copy.conflict);
        onConflict(copy.conflict);
        return;
      }
      setActionError(getAdminErrorMessage(error, copy.failed));
    },
  });

  const canRelease = item.status === "pending" && leaseActive && (ownedByCurrentUser || isAdmin);
  const canHandoff = item.status === "pending" && leaseActive && isAdmin;
  const canClaim =
    item.status === "pending" && (isAdmin || isModerator) && (!leaseActive || ownedByCurrentUser);
  const normalizedReason = reason.trim();
  const editorValid =
    normalizedReason.length >= 3 &&
    normalizedReason.length <= 500 &&
    (editor !== "handoff" || Boolean(assigneeUserId));

  return (
    <section className={styles.root} aria-label={copy.title}>
      <dl className={styles.status}>
        <div>
          <dt>{copy.owner}</dt>
          <dd>
            {ownedByCurrentUser ? copy.ownerYou : leaseActive ? copy.ownerOther : copy.ownerNone}
          </dd>
        </div>
        <div>
          <dt>{copy.expires}</dt>
          <dd>
            {leaseActive && item.leaseExpiresAtUtc
              ? formatDateTime(item.leaseExpiresAtUtc, locale)
              : "—"}
          </dd>
        </div>
        <div>
          <dt>{copy.version}</dt>
          <dd>v{expectedVersion}</dd>
        </div>
      </dl>

      <div className={styles.actions}>
        {canClaim ? (
          <Button
            variant={ownedByCurrentUser ? "secondary" : "primary"}
            size="sm"
            disabled={mutation.isPending}
            onClick={() => mutation.mutate("claim")}
          >
            {ownedByCurrentUser ? copy.renew : copy.take}
          </Button>
        ) : null}
        {canRelease ? (
          <Button
            variant="secondary"
            size="sm"
            disabled={mutation.isPending}
            aria-expanded={editor === "release"}
            onClick={() => {
              setEditor(editor === "release" ? null : "release");
              setActionError(null);
            }}
          >
            {copy.release}
          </Button>
        ) : null}
        {canHandoff ? (
          <Button
            variant="secondary"
            size="sm"
            disabled={mutation.isPending}
            aria-expanded={editor === "handoff"}
            onClick={() => {
              setEditor(editor === "handoff" ? null : "handoff");
              setActionError(null);
            }}
          >
            {copy.handoff}
          </Button>
        ) : null}
      </div>

      {editor ? (
        <div className={styles.editor}>
          {editor === "handoff" ? (
            <label className={styles.field}>
              <span>{copy.assignee}</span>
              <Select
                value={assigneeUserId}
                ariaLabel={copy.assignee}
                menuMode="inline"
                showSelectedDescription={false}
                disabled={operatorsQuery.isLoading || mutation.isPending}
                options={
                  operatorsQuery.isLoading
                    ? [{ value: "", label: copy.loadingOperators }]
                    : operatorOptions.length > 0
                      ? [{ value: "", label: copy.assignee }, ...operatorOptions]
                      : [{ value: "", label: copy.noOperators }]
                }
                onChange={setAssigneeUserId}
              />
            </label>
          ) : null}
          <label className={styles.field}>
            <span>{copy.reason}</span>
            <textarea
              className={styles.reason}
              value={reason}
              maxLength={500}
              placeholder={copy.reasonPlaceholder}
              disabled={mutation.isPending}
              onChange={(event) => setReason(event.target.value)}
            />
          </label>
          <span className={styles.hint}>{copy.reasonHint}</span>
          <div className={styles.actions}>
            <Button
              variant={editor === "release" ? "secondary" : "primary"}
              size="sm"
              disabled={!editorValid || mutation.isPending}
              onClick={() => mutation.mutate(editor)}
            >
              {editor === "release" ? copy.confirmRelease : copy.confirmHandoff}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              disabled={mutation.isPending}
              onClick={() => {
                setEditor(null);
                setReason("");
                setAssigneeUserId("");
              }}
            >
              {copy.cancel}
            </Button>
          </div>
        </div>
      ) : null}

      {actionError ? (
        <p className={styles.error} role="alert">
          {actionError}
        </p>
      ) : null}
    </section>
  );
}
