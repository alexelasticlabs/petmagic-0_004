"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";

import {
  canOpenSupportAssignmentEditor,
  canSubmitSupportAssignment,
  SUPPORT_UNASSIGNED_OPERATOR_VALUE,
} from "@/components/support/support-assignment-control.helpers";
import styles from "@/components/support/support-assignment-control.module.css";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignSupportConversation,
  fetchUsers,
  type AdminSupportConversation,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type SupportAssignmentControlProps = {
  conversation: AdminSupportConversation;
  canManageSupportWorkspace: boolean;
  sessionUserId: string | null;
  sessionUserRoles: string[];
  locale: Locale;
};

export function SupportAssignmentControl({
  conversation,
  canManageSupportWorkspace,
  sessionUserId,
  sessionUserRoles,
  locale,
}: SupportAssignmentControlProps) {
  const queryClient = useQueryClient();
  const [editorOpen, setEditorOpen] = useState(false);
  const [selectedOperatorId, setSelectedOperatorId] = useState(
    conversation.assignedAdminId ?? SUPPORT_UNASSIGNED_OPERATOR_VALUE
  );
  const [reason, setReason] = useState("");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const isAdmin = sessionUserRoles.includes("Admin");
  const isModerator = sessionUserRoles.includes("Moderator");
  const copy =
    locale === "ru"
      ? {
          claim: "Взять тикет",
          change: "Изменить назначение",
          assignee: "Ответственный оператор",
          unassigned: "Без ответственного",
          self: "Вы",
          currentOperator: "Текущий оператор",
          reason: "Причина изменения",
          reasonPlaceholder: "Кратко объясните передачу или снятие назначения",
          reasonHint: "Причина попадёт в audit trail. Минимум 3 символа.",
          confirm: "Подтвердить назначение",
          cancel: "Отмена",
          loading: "Загрузка операторов…",
          failed: "Не удалось изменить назначение. Обновите тикет и повторите.",
        }
      : {
          claim: "Claim ticket",
          change: "Change assignment",
          assignee: "Responsible operator",
          unassigned: "No assignee",
          self: "You",
          currentOperator: "Current operator",
          reason: "Change reason",
          reasonPlaceholder: "Briefly explain the handoff or unassignment",
          reasonHint: "The reason is stored in the audit trail. Minimum 3 characters.",
          confirm: "Confirm assignment",
          cancel: "Cancel",
          loading: "Loading operators…",
          failed: "Could not change assignment. Refresh the ticket and retry.",
        };

  const operatorsQuery = useQuery({
    queryKey: adminQueryKeys.users({
      scope: "support-assignment",
      conversationId: conversation.conversationId,
    }),
    queryFn: ({ signal }) => fetchUsers({ skip: 0, take: 100, sort: "last_activity_desc" }, signal),
    enabled: editorOpen && isAdmin,
    staleTime: 60_000,
  });

  const operatorOptions = useMemo(() => {
    const options = [{ value: SUPPORT_UNASSIGNED_OPERATOR_VALUE, label: copy.unassigned }];
    const knownOperatorIds = new Set([SUPPORT_UNASSIGNED_OPERATOR_VALUE]);
    if (isAdmin && conversation.assignedAdminId && conversation.assignedAdminId !== sessionUserId) {
      options.push({
        value: conversation.assignedAdminId,
        label: sanitizeSensitiveText(
          conversation.assignedAdminDisplayName?.trim() || copy.currentOperator,
          96
        ),
      });
      knownOperatorIds.add(conversation.assignedAdminId);
    }
    if (sessionUserId) {
      options.push({ value: sessionUserId, label: copy.self });
      knownOperatorIds.add(sessionUserId);
    }
    if (isAdmin) {
      for (const user of operatorsQuery.data?.items ?? []) {
        if (
          !user.isActive ||
          knownOperatorIds.has(user.userId) ||
          (!user.roles.includes("Admin") && !user.roles.includes("Moderator"))
        ) {
          continue;
        }
        const name = sanitizeSensitiveText(user.displayName?.trim() || maskEmail(user.email), 96);
        options.push({
          value: user.userId,
          label: `${name} · ${user.roles.includes("Admin") ? "Admin" : "Moderator"}`,
        });
        knownOperatorIds.add(user.userId);
      }
    }
    return options;
  }, [
    conversation.assignedAdminId,
    conversation.assignedAdminDisplayName,
    copy.currentOperator,
    copy.self,
    copy.unassigned,
    isAdmin,
    operatorsQuery.data?.items,
    sessionUserId,
  ]);

  const canOpenEditor = canOpenSupportAssignmentEditor({
    assignedAdminId: conversation.assignedAdminId,
    canManageSupportWorkspace,
    isAdmin,
    isModerator,
    sessionUserId,
    version: conversation.version,
  });
  const assignmentPayloadValid = canSubmitSupportAssignment({
    assignedAdminId: conversation.assignedAdminId,
    canManageSupportWorkspace,
    isAdmin,
    isModerator,
    isPending: false,
    reason,
    selectedOperatorId,
    sessionUserId,
    version: conversation.version,
  });

  const assignmentMutation = useMutation({
    mutationFn: () => {
      if (!assignmentPayloadValid) {
        throw new Error(copy.failed);
      }

      return assignSupportConversation(conversation.conversationId, {
        assignedAdminId:
          selectedOperatorId === SUPPORT_UNASSIGNED_OPERATOR_VALUE ? null : selectedOperatorId,
        expectedVersion: conversation.version,
        reason: reason.trim(),
      });
    },
    onSuccess: async (updatedConversation) => {
      queryClient.setQueryData(
        adminQueryKeys.supportConversation(conversation.conversationId),
        updatedConversation
      );
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxMetrics }),
      ]);
      setEditorOpen(false);
      setReason("");
      setErrorMessage(null);
    },
    onError: (error) => {
      setErrorMessage(getAdminErrorMessage(error, copy.failed));
      void queryClient.invalidateQueries({
        queryKey: adminQueryKeys.supportConversation(conversation.conversationId),
      });
    },
  });

  const canSubmit = assignmentPayloadValid && !assignmentMutation.isPending;

  return (
    <div className={styles.root}>
      <div className={styles.actions}>
        {!conversation.assignedAdminId && (isAdmin || isModerator) ? (
          <Button
            type="button"
            size="sm"
            variant="primary"
            onClick={() => {
              if (!canOpenEditor || !sessionUserId) return;
              setSelectedOperatorId(sessionUserId);
              setEditorOpen(true);
              setReason("");
              setErrorMessage(null);
            }}
            disabled={!canOpenEditor || assignmentMutation.isPending}
          >
            {copy.claim}
          </Button>
        ) : null}
        {conversation.assignedAdminId && canOpenEditor ? (
          <Button
            type="button"
            size="sm"
            variant="secondary"
            onClick={() => {
              setEditorOpen((current) => !current);
              setSelectedOperatorId(
                conversation.assignedAdminId ?? SUPPORT_UNASSIGNED_OPERATOR_VALUE
              );
              setReason("");
              setErrorMessage(null);
            }}
            disabled={assignmentMutation.isPending}
            aria-expanded={editorOpen}
          >
            {copy.change}
          </Button>
        ) : null}
      </div>

      {editorOpen ? (
        <div className={styles.editor}>
          <label className={styles.field}>
            <span>{copy.assignee}</span>
            <Select
              value={selectedOperatorId}
              ariaLabel={copy.assignee}
              options={
                operatorsQuery.isLoading
                  ? [{ value: selectedOperatorId, label: copy.loading }]
                  : operatorOptions
              }
              onChange={setSelectedOperatorId}
              disabled={operatorsQuery.isLoading || assignmentMutation.isPending}
              showSelectedDescription={false}
              menuMode="inline"
            />
          </label>
          <label className={styles.field}>
            <span>{copy.reason}</span>
            <textarea
              className={styles.reason}
              value={reason}
              maxLength={500}
              placeholder={copy.reasonPlaceholder}
              onChange={(event) => setReason(event.target.value)}
              disabled={assignmentMutation.isPending}
            />
          </label>
          <span className={styles.hint}>{copy.reasonHint}</span>
          {errorMessage ? (
            <p className={styles.error} role="alert">
              {errorMessage}
            </p>
          ) : null}
          <div className={styles.actions}>
            <Button
              type="button"
              size="sm"
              variant="primary"
              onClick={() => assignmentMutation.mutate()}
              disabled={!canSubmit}
            >
              {copy.confirm}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="secondary"
              onClick={() => {
                setEditorOpen(false);
                setReason("");
                setErrorMessage(null);
              }}
              disabled={assignmentMutation.isPending}
            >
              {copy.cancel}
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
