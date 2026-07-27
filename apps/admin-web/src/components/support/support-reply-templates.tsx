"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";

import { AdminDetailsDrawer } from "@/components/admin/admin-details-drawer";
import styles from "@/components/support/support-reply-templates.module.css";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  createSupportReplyTemplate,
  fetchSupportReplyTemplates,
  fetchSupportReplyTemplateVersions,
  updateSupportReplyTemplate,
  type AdminSupportReplyTemplate,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

const templatePlaceholder = "__select_template__";

type TemplateDraft = {
  templateId: string | null;
  title: string;
  body: string;
  sortOrder: string;
  isEnabled: boolean;
  expectedVersion?: number;
  reason: string;
};

const emptyDraft: TemplateDraft = {
  templateId: null,
  title: "",
  body: "",
  sortOrder: "0",
  isEnabled: true,
  reason: "",
};

type SupportReplyTemplatesProps = {
  locale: Locale;
  disabled: boolean;
  canManageTemplates: boolean;
  setReply: (value: string) => void;
};

export function SupportReplyTemplates({
  locale,
  disabled,
  canManageTemplates,
  setReply,
}: SupportReplyTemplatesProps) {
  const queryClient = useQueryClient();
  const [selectedTemplateId, setSelectedTemplateId] = useState(templatePlaceholder);
  const [managerOpen, setManagerOpen] = useState(false);
  const [draft, setDraft] = useState<TemplateDraft | null>(null);
  const [historyTemplateId, setHistoryTemplateId] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const copy =
    locale === "ru"
      ? {
          picker: "Шаблон ответа",
          placeholder: "Выбрать готовый ответ",
          manage: "Управление шаблонами",
          managerDescription: "Версии, порядок и доступность быстрых ответов.",
          close: "Закрыть",
          create: "Новый шаблон",
          edit: "Изменить",
          history: "Версии",
          save: "Сохранить версию",
          cancel: "Отмена",
          title: "Название",
          body: "Текст ответа",
          order: "Порядок",
          reason: "Причина изменения",
          reasonPlaceholder: "Обязательна для новой версии или отключения",
          enabled: "Доступен операторам",
          disabled: "Отключён",
          version: "Версия",
          failed: "Не удалось сохранить шаблон.",
          empty: "Шаблонов пока нет.",
        }
      : {
          picker: "Reply template",
          placeholder: "Choose a prepared reply",
          manage: "Manage templates",
          managerDescription: "Versions, ordering and availability of prepared replies.",
          close: "Close",
          create: "New template",
          edit: "Edit",
          history: "Versions",
          save: "Save version",
          cancel: "Cancel",
          title: "Title",
          body: "Reply text",
          order: "Order",
          reason: "Change reason",
          reasonPlaceholder: "Required for a new version or disabling",
          enabled: "Available to operators",
          disabled: "Disabled",
          version: "Version",
          failed: "Could not save the template.",
          empty: "No templates yet.",
        };

  const enabledQuery = useQuery({
    queryKey: adminQueryKeys.supportTemplateList(false),
    queryFn: ({ signal }) => fetchSupportReplyTemplates(signal),
    staleTime: 60_000,
  });
  const allQuery = useQuery({
    queryKey: adminQueryKeys.supportTemplateList(true),
    queryFn: ({ signal }) => fetchSupportReplyTemplates(signal, true),
    enabled: managerOpen && canManageTemplates,
    staleTime: 30_000,
  });
  const historyQuery = useQuery({
    queryKey: adminQueryKeys.supportTemplateVersions(historyTemplateId ?? "disabled"),
    queryFn: ({ signal }) => fetchSupportReplyTemplateVersions(historyTemplateId!, signal),
    enabled: Boolean(managerOpen && canManageTemplates && historyTemplateId),
  });

  const pickerOptions = useMemo(
    () => [
      { value: templatePlaceholder, label: copy.placeholder },
      ...(enabledQuery.data ?? []).map((template) => ({
        value: template.templateId,
        label: template.title,
        description: template.body.slice(0, 120),
      })),
    ],
    [copy.placeholder, enabledQuery.data]
  );

  const saveMutation = useMutation({
    mutationFn: async (value: TemplateDraft) => {
      const sortOrder = Number.parseInt(value.sortOrder, 10);
      const payload = {
        title: value.title.trim(),
        body: value.body.trim(),
        isEnabled: value.isEnabled,
        sortOrder: Number.isFinite(sortOrder) ? Math.max(0, sortOrder) : 0,
        expectedVersion: value.expectedVersion,
        reason: value.reason.trim() || undefined,
      };
      return value.templateId
        ? updateSupportReplyTemplate(value.templateId, payload)
        : createSupportReplyTemplate(payload);
    },
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportTemplates }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportTemplateList(false) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportTemplateList(true) }),
      ]);
      setDraft(null);
      setHistoryTemplateId(null);
      setErrorMessage(null);
    },
    onError: (error) => {
      setErrorMessage(getAdminErrorMessage(error, copy.failed));
      void allQuery.refetch();
    },
  });

  const beginEdit = (template: AdminSupportReplyTemplate) => {
    setDraft({
      templateId: template.templateId,
      title: template.title,
      body: template.body,
      sortOrder: String(template.sortOrder),
      isEnabled: template.isEnabled,
      expectedVersion: template.version,
      reason: "",
    });
    setHistoryTemplateId(null);
    setErrorMessage(null);
  };
  const canSaveDraft = Boolean(
    draft &&
    draft.title.trim() &&
    draft.body.trim() &&
    (!draft.templateId || draft.reason.trim().length >= 3) &&
    !saveMutation.isPending
  );

  return (
    <>
      <div className={styles.toolbar} data-testid="support-reply-template-picker">
        <Select
          value={selectedTemplateId}
          ariaLabel={copy.picker}
          options={pickerOptions}
          disabled={disabled || enabledQuery.isLoading}
          showSelectedDescription={false}
          onChange={(templateId) => {
            setSelectedTemplateId(templateId);
            const template = enabledQuery.data?.find((item) => item.templateId === templateId);
            if (template) {
              setReply(template.body);
            }
          }}
        />
        {canManageTemplates ? (
          <Button type="button" size="sm" variant="secondary" onClick={() => setManagerOpen(true)}>
            {copy.manage}
          </Button>
        ) : null}
      </div>

      <AdminDetailsDrawer
        open={managerOpen}
        title={copy.manage}
        description={copy.managerDescription}
        closeLabel={copy.close}
        onClose={() => {
          if (!saveMutation.isPending) {
            setManagerOpen(false);
            setDraft(null);
            setHistoryTemplateId(null);
          }
        }}
      >
        <div className={styles.manager}>
          <div className={styles.managerHeader}>
            <span className={styles.hint}>
              {allQuery.data?.length ?? 0} · {copy.version}
            </span>
            <Button
              type="button"
              size="sm"
              variant="primary"
              onClick={() => {
                setDraft({ ...emptyDraft });
                setHistoryTemplateId(null);
                setErrorMessage(null);
              }}
              disabled={saveMutation.isPending}
            >
              {copy.create}
            </Button>
          </div>

          {draft ? (
            <div className={styles.form}>
              <label className={styles.field}>
                <span>{copy.title}</span>
                <input
                  className={styles.input}
                  value={draft.title}
                  maxLength={120}
                  onChange={(event) => setDraft({ ...draft, title: event.target.value })}
                />
              </label>
              <label className={styles.field}>
                <span>{copy.body}</span>
                <textarea
                  className={styles.textarea}
                  value={draft.body}
                  maxLength={4000}
                  onChange={(event) => setDraft({ ...draft, body: event.target.value })}
                />
              </label>
              <label className={styles.field}>
                <span>{copy.order}</span>
                <input
                  className={styles.input}
                  type="number"
                  min={0}
                  value={draft.sortOrder}
                  onChange={(event) => setDraft({ ...draft, sortOrder: event.target.value })}
                />
              </label>
              <label className={styles.field}>
                <span>{copy.reason}</span>
                <textarea
                  className={styles.textarea}
                  value={draft.reason}
                  maxLength={500}
                  placeholder={copy.reasonPlaceholder}
                  onChange={(event) => setDraft({ ...draft, reason: event.target.value })}
                />
              </label>
              <label className={styles.field}>
                <span>
                  <input
                    type="checkbox"
                    checked={draft.isEnabled}
                    onChange={(event) => setDraft({ ...draft, isEnabled: event.target.checked })}
                  />{" "}
                  {copy.enabled}
                </span>
              </label>
              {errorMessage ? (
                <p className={styles.error} role="alert">
                  {errorMessage}
                </p>
              ) : null}
              <div className={styles.formActions}>
                <Button
                  type="button"
                  variant="primary"
                  onClick={() => draft && saveMutation.mutate(draft)}
                  disabled={!canSaveDraft}
                >
                  {copy.save}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setDraft(null)}
                  disabled={saveMutation.isPending}
                >
                  {copy.cancel}
                </Button>
              </div>
            </div>
          ) : historyTemplateId ? (
            <div className={styles.history}>
              {(historyQuery.data ?? []).map((version) => (
                <div
                  key={`${version.templateId}:${version.version}`}
                  className={styles.historyItem}
                >
                  <strong>
                    {copy.version} {version.version}
                    {version.isCurrent ? " · current" : ""}
                  </strong>
                  <span>{version.title}</span>
                  {version.reason ? <span>{version.reason}</span> : null}
                </div>
              ))}
              <Button type="button" variant="secondary" onClick={() => setHistoryTemplateId(null)}>
                {copy.cancel}
              </Button>
            </div>
          ) : allQuery.data?.length ? (
            <div className={styles.templateList}>
              {allQuery.data.map((template) => (
                <article
                  key={template.templateId}
                  className={styles.templateCard}
                  data-disabled={!template.isEnabled}
                >
                  <div className={styles.templateHeader}>
                    <strong>{template.title}</strong>
                    <span className={styles.templateMeta}>
                      {copy.version} {template.version}
                      {!template.isEnabled ? ` · ${copy.disabled}` : ""}
                    </span>
                  </div>
                  <p className={styles.bodyPreview}>{template.body.slice(0, 220)}</p>
                  <div className={styles.templateActions}>
                    <Button
                      type="button"
                      size="sm"
                      variant="secondary"
                      onClick={() => beginEdit(template)}
                    >
                      {copy.edit}
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      onClick={() => setHistoryTemplateId(template.templateId)}
                    >
                      {copy.history}
                    </Button>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <span className={styles.hint}>{copy.empty}</span>
          )}
        </div>
      </AdminDetailsDrawer>
    </>
  );
}
