"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRef, useState } from "react";

import { AdminBadge, AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Button } from "@/components/ui/button";
import styles from "@/components/users/user-sessions-panel.module.css";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminUserSessions,
  revokeAdminUserSession,
  revokeAllAdminUserSessions,
  USER_SESSION_REVOKE_REASON_MAX_LENGTH,
  type AdminUserSession,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type PendingSessionAction =
  | { idempotencyKey: string; kind: "all" }
  | { idempotencyKey: string; kind: "single"; session: AdminUserSession };

type SessionFeedback = {
  message: string;
  tone: "danger" | "success" | "warning";
};

type UserSessionsPanelProps = {
  locale: Locale;
  userId: string;
};

const sessionText = {
  en: {
    title: "User sessions",
    description: "Review refresh sessions and terminate access without exposing token material.",
    activeCount: "Active",
    totalCount: "Total",
    revokeAll: "Revoke all active sessions",
    revoke: "Revoke session",
    retry: "Try again",
    loading: "Loading sessions…",
    loadError: "Could not load user sessions.",
    empty: "No sessions have been issued for this account.",
    truncated: "Only the 100 most recent sessions are shown.",
    created: "Created",
    expires: "Expires",
    revoked: "Revoked",
    statusActive: "Active",
    statusExpired: "Expired",
    statusRevoked: "Revoked",
    confirmSingleTitle: "Revoke this session?",
    confirmSingleDescription:
      "The refresh token and its session-bound access token will stop working immediately.",
    confirmAllTitle: "Revoke all active sessions?",
    confirmAllDescription:
      "All active refresh sessions and current access tokens for this user will be invalidated.",
    reasonLabel: "Reason",
    reasonPlaceholder: "For example: verified account owner request",
    reasonHint: "Required and recorded in the audit trail.",
    cancel: "Cancel",
    successSingle: "The session was revoked.",
    successAll: "All active sessions were revoked.",
    actionError: "Could not revoke the selected session state.",
    noActive: "There are no active sessions to revoke.",
    sessionLabel: "Session",
  },
  ru: {
    title: "Сессии пользователя",
    description: "Просмотр refresh-сессий и завершение доступа без раскрытия token material.",
    activeCount: "Активные",
    totalCount: "Всего",
    revokeAll: "Отозвать все активные сессии",
    revoke: "Отозвать сессию",
    retry: "Повторить",
    loading: "Загрузка сессий…",
    loadError: "Не удалось загрузить сессии пользователя.",
    empty: "Для этой учётной записи ещё не создавались сессии.",
    truncated: "Показаны только 100 последних сессий.",
    created: "Создана",
    expires: "Истекает",
    revoked: "Отозвана",
    statusActive: "Активна",
    statusExpired: "Истекла",
    statusRevoked: "Отозвана",
    confirmSingleTitle: "Отозвать эту сессию?",
    confirmSingleDescription:
      "Refresh token и связанный с этой сессией access token сразу перестанут работать.",
    confirmAllTitle: "Отозвать все активные сессии?",
    confirmAllDescription:
      "Все активные refresh-сессии и текущие access tokens пользователя будут аннулированы.",
    reasonLabel: "Причина",
    reasonPlaceholder: "Например: подтверждённый запрос владельца аккаунта",
    reasonHint: "Обязательна и сохраняется в audit trail.",
    cancel: "Отмена",
    successSingle: "Сессия отозвана.",
    successAll: "Все активные сессии отозваны.",
    actionError: "Не удалось отозвать выбранные сессии.",
    noActive: "Активных сессий для отзыва нет.",
    sessionLabel: "Сессия",
  },
} as const;

function getSessionStatusLabel(session: AdminUserSession, locale: Locale): string {
  const text = sessionText[locale];
  if (session.status === "active") {
    return text.statusActive;
  }
  if (session.status === "expired") {
    return text.statusExpired;
  }
  return text.statusRevoked;
}

function getSessionStatusTone(session: AdminUserSession): "neutral" | "success" | "warning" {
  if (session.status === "active") {
    return "success";
  }
  if (session.status === "expired") {
    return "warning";
  }
  return "neutral";
}

export function UserSessionsPanel({ locale, userId }: UserSessionsPanelProps) {
  const text = sessionText[locale];
  const queryClient = useQueryClient();
  const reasonRef = useRef<HTMLTextAreaElement>(null);
  const [pendingAction, setPendingAction] = useState<PendingSessionAction | null>(null);
  const [reason, setReason] = useState("");
  const [feedback, setFeedback] = useState<SessionFeedback | null>(null);
  const sessionsQuery = useQuery({
    queryKey: adminQueryKeys.userSessions(userId),
    queryFn: ({ signal }) => fetchAdminUserSessions(userId, signal),
    enabled: Boolean(userId),
    staleTime: 15_000,
  });
  const revokeMutation = useMutation({
    mutationFn: async ({
      action,
      normalizedReason,
    }: {
      action: PendingSessionAction;
      normalizedReason: string;
    }) => {
      if (action.kind === "all") {
        return revokeAllAdminUserSessions(userId, normalizedReason, action.idempotencyKey);
      }

      return revokeAdminUserSession(
        userId,
        action.session.sessionId,
        normalizedReason,
        action.idempotencyKey
      );
    },
  });
  const normalizedReason = reason.trim();
  const sessions = sessionsQuery.data;
  const isBusy = sessionsQuery.isFetching || revokeMutation.isPending;

  function requestSingleRevoke(session: AdminUserSession) {
    if (!session.canRevoke || revokeMutation.isPending) {
      return;
    }

    setFeedback(null);
    setReason("");
    setPendingAction({
      kind: "single",
      session,
      idempotencyKey: `user-session-revoke:${createAdminCorrelationId()}`,
    });
  }

  function requestRevokeAll() {
    if (!sessions?.activeCount || revokeMutation.isPending) {
      return;
    }

    setFeedback(null);
    setReason("");
    setPendingAction({
      kind: "all",
      idempotencyKey: `user-session-revoke:${createAdminCorrelationId()}`,
    });
  }

  async function confirmRevoke() {
    if (!pendingAction || !normalizedReason || revokeMutation.isPending) {
      return;
    }

    const action = pendingAction;
    setFeedback(null);
    try {
      await revokeMutation.mutateAsync({ action, normalizedReason });
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.userSessions(userId) });
      setPendingAction(null);
      setReason("");
      setFeedback({
        tone: "success",
        message: action.kind === "all" ? text.successAll : text.successSingle,
      });
    } catch (error) {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.actionError),
      });
    }
  }

  return (
    <>
      <AdminCard
        className={styles.card}
        title={text.title}
        description={text.description}
        action={
          <Button
            variant="danger"
            size="sm"
            disabled={!sessions?.activeCount || isBusy}
            title={!sessions?.activeCount ? text.noActive : undefined}
            onClick={requestRevokeAll}
          >
            {text.revokeAll}
          </Button>
        }
      >
        {feedback && pendingAction === null ? (
          <AdminStateCard tone={feedback.tone} title={feedback.message} />
        ) : null}

        {sessionsQuery.isError && !sessions ? (
          <AdminStateCard
            tone="danger"
            title={text.loadError}
            action={
              <Button
                variant="ghost"
                size="sm"
                disabled={sessionsQuery.isFetching}
                onClick={() => void sessionsQuery.refetch().catch(() => undefined)}
              >
                {text.retry}
              </Button>
            }
          />
        ) : sessionsQuery.isPending && !sessions ? (
          <AdminStateCard tone="info" title={text.loading} />
        ) : sessions ? (
          <div className={styles.workspace} aria-busy={isBusy ? "true" : undefined}>
            {sessionsQuery.isError ? (
              <AdminStateCard
                tone="warning"
                title={text.loadError}
                action={
                  <Button
                    variant="ghost"
                    size="sm"
                    disabled={sessionsQuery.isFetching}
                    onClick={() => void sessionsQuery.refetch().catch(() => undefined)}
                  >
                    {text.retry}
                  </Button>
                }
              />
            ) : null}
            <dl className={styles.summary}>
              <div>
                <dt>{text.activeCount}</dt>
                <dd>{sessions.activeCount}</dd>
              </div>
              <div>
                <dt>{text.totalCount}</dt>
                <dd>{sessions.totalCount}</dd>
              </div>
            </dl>

            {sessions.items.length ? (
              <div className={styles.list} role="list">
                {sessions.items.map((session) => {
                  const safeSessionLabel = sanitizeSensitiveText(session.sessionId.slice(0, 8), 12);
                  return (
                    <article key={session.sessionId} className={styles.session} role="listitem">
                      <div className={styles.sessionHeader}>
                        <strong>
                          {text.sessionLabel} {safeSessionLabel}
                        </strong>
                        <AdminBadge tone={getSessionStatusTone(session)}>
                          {getSessionStatusLabel(session, locale)}
                        </AdminBadge>
                      </div>
                      <dl className={styles.metadata}>
                        <div>
                          <dt>{text.created}</dt>
                          <dd>
                            <time dateTime={session.createdAtUtc}>
                              {formatDateTime(session.createdAtUtc, locale)}
                            </time>
                          </dd>
                        </div>
                        <div>
                          <dt>{text.expires}</dt>
                          <dd>
                            <time dateTime={session.expiresAtUtc}>
                              {formatDateTime(session.expiresAtUtc, locale)}
                            </time>
                          </dd>
                        </div>
                        {session.revokedAtUtc ? (
                          <div>
                            <dt>{text.revoked}</dt>
                            <dd>
                              <time dateTime={session.revokedAtUtc}>
                                {formatDateTime(session.revokedAtUtc, locale)}
                              </time>
                            </dd>
                          </div>
                        ) : null}
                      </dl>
                      {session.canRevoke ? (
                        <div className={styles.sessionAction}>
                          <Button
                            variant="danger"
                            size="sm"
                            disabled={revokeMutation.isPending}
                            onClick={() => requestSingleRevoke(session)}
                          >
                            {text.revoke}
                          </Button>
                        </div>
                      ) : null}
                    </article>
                  );
                })}
              </div>
            ) : (
              <p className={styles.empty} role="status">
                {text.empty}
              </p>
            )}

            {sessions.hasMore ? <AdminStateCard tone="info" title={text.truncated} /> : null}
          </div>
        ) : null}
      </AdminCard>

      <ConfirmationDialog
        open={pendingAction !== null}
        title={pendingAction?.kind === "all" ? text.confirmAllTitle : text.confirmSingleTitle}
        description={
          pendingAction?.kind === "all" ? text.confirmAllDescription : text.confirmSingleDescription
        }
        confirmLabel={pendingAction?.kind === "all" ? text.revokeAll : text.revoke}
        cancelLabel={text.cancel}
        confirmDisabled={!normalizedReason}
        initialFocusRef={reasonRef}
        isSubmitting={revokeMutation.isPending}
        tone="danger"
        onCancel={() => {
          if (!revokeMutation.isPending) {
            setPendingAction(null);
            setReason("");
            setFeedback(null);
          }
        }}
        onConfirm={() => void confirmRevoke()}
      >
        {feedback?.tone === "danger" ? (
          <AdminStateCard tone="danger" title={feedback.message} />
        ) : null}
        <label className={styles.reasonField}>
          <span>{text.reasonLabel}</span>
          <textarea
            ref={reasonRef}
            value={reason}
            maxLength={USER_SESSION_REVOKE_REASON_MAX_LENGTH}
            required
            aria-describedby="user-session-revoke-reason-hint"
            onChange={(event) =>
              setReason(event.target.value.slice(0, USER_SESSION_REVOKE_REASON_MAX_LENGTH))
            }
            placeholder={text.reasonPlaceholder}
          />
          <small id="user-session-revoke-reason-hint">
            {text.reasonHint} {reason.length}/{USER_SESSION_REVOKE_REASON_MAX_LENGTH}
          </small>
        </label>
      </ConfirmationDialog>
    </>
  );
}
