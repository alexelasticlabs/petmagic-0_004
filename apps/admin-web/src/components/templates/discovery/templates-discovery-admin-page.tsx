"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminContextBar,
  AdminPage,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { useAdminTemplateCategories } from "@/components/templates/use-admin-template-categories";
import { Button } from "@/components/ui/button";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { useAuthSession } from "@/lib/api-client.core";
import {
  createDiscoveryDraft,
  discardDiscoveryDraft,
  discoveryLocales,
  fetchDiscovery,
  fetchDiscoveryHistory,
  previewDiscovery,
  publishDiscovery,
  saveDiscoveryDraft,
  validateDiscovery,
  type DiscoveryAdmin,
  type DiscoveryDocument,
  type DiscoveryLocale,
  type DiscoveryRevision,
} from "@/lib/api-client.discovery";
import type { AdminTemplateCategory } from "@/lib/api-client.types.templates";
import type { Locale } from "@/lib/i18n";

import {
  discoveryDiff,
  discoverySectionTitle,
  moveDiscoveryItem,
  newDiscoverySection,
} from "./discovery-editor-model";
import { getDiscoveryText, type DiscoveryText } from "./discovery-editor.content";
import styles from "./discovery-editor.module.css";
import { DiscoveryPhonePreview, PreviewError } from "./discovery-preview";
import { DiscoveryCopyFields, DiscoverySectionEditor } from "./discovery-section-editor";

export function TemplatesDiscoveryAdminPage({ locale }: { locale: Locale }) {
  const text = getDiscoveryText(locale);
  const session = useAuthSession();
  const canRead =
    session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false;
  const canManage = session?.user.roles.includes("Admin") ?? false;
  const [epoch, setEpoch] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const queryClient = useQueryClient();
  const state = useQuery({
    queryKey: ["discovery-admin"],
    queryFn: ({ signal }) => fetchDiscovery(signal),
    enabled: canRead,
    refetchOnWindowFocus: false,
  });
  const categories = useAdminTemplateCategories({ enabled: canRead, includeArchived: true });
  async function refresh(reset = false) {
    const result = await state.refetch();
    if (result.error) throw result.error;
    await queryClient.invalidateQueries({ queryKey: ["discovery-history"] });
    if (reset) setEpoch((value) => value + 1);
  }
  async function create(sourceId?: string) {
    if (!state.data || busy || !canManage) return;
    setBusy(true);
    setError("");
    try {
      await createDiscoveryDraft(state.data.pageVersion, sourceId);
      await refresh();
    } catch (cause) {
      setError(getDiscoveryError(cause, text));
    } finally {
      setBusy(false);
    }
  }
  const revision = state.data?.draft ?? state.data?.published;
  return (
    <AdminPage className={styles.page}>
      {error ? <AdminStateCard tone="danger" description={error} /> : null}
      {state.isError || categories.hasError ? (
        <AdminStateCard
          tone="danger"
          title={text.failed}
          action={
            <Button
              onClick={() => {
                void state.refetch();
                void categories.refresh();
              }}
            >
              {text.retry}
            </Button>
          }
        />
      ) : null}
      {state.isPending || categories.isLoading ? (
        <AdminStateCard description={<span role="status">{text.loading}</span>} />
      ) : state.data ? (
        revision ? (
          <DiscoveryWorkspace
            key={`${revision.id}:${epoch}`}
            data={state.data}
            initialRevision={revision}
            categories={categories.categories}
            locale={locale}
            canManage={canManage}
            parentBusy={busy}
            text={text}
            onRefresh={refresh}
            onCreate={create}
          />
        ) : (
          <>
            <AdminContextBar
              label={text.intro}
              badge={<AdminBadge>{text.automatic}</AdminBadge>}
              actions={
                <Button
                  variant="primary"
                  disabled={!canManage || busy}
                  onClick={() => void create()}
                >
                  {text.create}
                </Button>
              }
            />
            <AdminStateCard title={text.automatic} description={text.intro} />
            <DiscoveryHistory
              text={text}
              locale={locale}
              disabled={!canManage || busy}
              onRestore={create}
            />
          </>
        )
      ) : null}
    </AdminPage>
  );
}

function getDiscoveryError(error: unknown, text: DiscoveryText) {
  return typeof error === "object" && error !== null && "status" in error && error.status === 409
    ? text.conflict
    : getAdminErrorMessage(error, text.failed);
}

function DiscoveryWorkspace({
  data,
  initialRevision,
  categories,
  locale,
  canManage,
  parentBusy,
  text,
  onRefresh,
  onCreate,
}: {
  data: DiscoveryAdmin;
  initialRevision: DiscoveryRevision;
  categories: AdminTemplateCategory[];
  locale: Locale;
  canManage: boolean;
  parentBusy: boolean;
  text: DiscoveryText;
  onRefresh: (reset?: boolean) => Promise<void>;
  onCreate: (sourceId?: string) => Promise<void>;
}) {
  const [saved, setSaved] = useState(initialRevision);
  const [document, setDocument] = useState<DiscoveryDocument>(initialRevision.document);
  const [selectedId, setSelectedId] = useState(initialRevision.document.sections[0]?.id ?? "");
  const [tab, setTab] = useState<"layout" | "settings" | "history">("layout");
  const [contentLocale, setContentLocale] = useState<DiscoveryLocale>(locale);
  const [addCategory, setAddCategory] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [dialog, setDialog] = useState<"publish" | "discard" | "reload" | null>(null);
  const [reason, setReason] = useState("");
  const dragIndex = useRef<number | null>(null);
  const publishing = useRef<{ signature: string; key: string } | null>(null);
  const dirty = JSON.stringify(document) !== JSON.stringify(saved.document);
  const editable = canManage && saved.state === "Draft";
  const locked = busy || parentBusy;
  const selected =
    document.sections.find((section) => section.id === selectedId) ?? document.sections[0];
  const categoryNames = new Map(categories.map((category) => [category.categoryId, category.name]));
  const queryClient = useQueryClient();
  const preview = useQuery({
    queryKey: ["discovery-preview", saved.id, saved.editVersion, contentLocale],
    queryFn: ({ signal }) => previewDiscovery(saved.id, contentLocale, signal),
    refetchOnWindowFocus: false,
  });
  const validation = useQuery({
    queryKey: ["discovery-validation", saved.id, saved.editVersion],
    queryFn: ({ signal }) => validateDiscovery(saved.id, signal),
    enabled: saved.state === "Draft",
    refetchOnWindowFocus: false,
  });
  const diff = discoveryDiff(data.published?.document, saved.document);

  useEffect(() => {
    if (!dirty) return;
    function beforeUnload(event: BeforeUnloadEvent) {
      event.preventDefault();
    }
    function beforeNavigation(event: MouseEvent) {
      const target = event.target instanceof Element ? event.target.closest("a[href]") : null;
      if (
        target instanceof HTMLAnchorElement &&
        target.href !== window.location.href &&
        target.target !== "_blank" &&
        !window.confirm(text.leave)
      ) {
        event.preventDefault();
        event.stopPropagation();
      }
    }
    window.addEventListener("beforeunload", beforeUnload);
    window.document.addEventListener("click", beforeNavigation, true);
    return () => {
      window.removeEventListener("beforeunload", beforeUnload);
      window.document.removeEventListener("click", beforeNavigation, true);
    };
  }, [dirty, text.leave]);

  async function act(action: () => Promise<void>) {
    if (locked) return;
    setBusy(true);
    setError("");
    setNotice("");
    try {
      await action();
    } catch (cause) {
      setError(getDiscoveryError(cause, text));
    } finally {
      setBusy(false);
    }
  }
  async function save() {
    if (!editable) return;
    await act(async () => {
      const result = await saveDiscoveryDraft(saved.id, saved.editVersion, document);
      setSaved(result);
      setDocument(result.document);
      setNotice(text.saved);
      await queryClient.invalidateQueries({ queryKey: ["discovery-history"] });
    });
  }
  async function confirm() {
    await act(async () => {
      if (dialog === "reload") {
        await onRefresh(true);
        return;
      }
      if (!editable) return;
      if (dialog === "discard") {
        await discardDiscoveryDraft(saved.id, saved.editVersion, data.pageVersion);
        setDocument(saved.document);
        await onRefresh(true);
        return;
      }
      if (dialog === "publish" && !dirty) {
        const signature = JSON.stringify([
          saved.id,
          saved.editVersion,
          data.pageVersion,
          reason.trim(),
        ]);
        if (publishing.current?.signature !== signature)
          publishing.current = { signature, key: crypto.randomUUID() };
        const result = await publishDiscovery(
          saved.id,
          saved.editVersion,
          data.pageVersion,
          reason.trim(),
          publishing.current.key
        );
        setSaved(result);
        setNotice(text.publishedNotice);
        setDialog(null);
        await onRefresh(true);
      }
    });
  }
  return (
    <>
      <AdminContextBar
        label={text.intro}
        badge={
          <AdminBadge tone={saved.state === "Draft" ? "warning" : "success"}>
            {saved.state === "Draft" ? text.draft : text.published} v{saved.number}
          </AdminBadge>
        }
        metaItems={[
          data.published ? `${text.published}: v${data.published.number}` : text.automatic,
          editable ? (dirty ? text.dirty : text.clean) : text.readonly,
        ]}
        actions={
          <>
            <Button disabled={locked} onClick={() => setDialog("reload")}>
              {text.reload}
            </Button>
            {editable ? (
              <>
                <Button disabled={locked || !dirty} onClick={() => void save()}>
                  {text.save}
                </Button>
                <Button
                  variant="primary"
                  disabled={locked || dirty || !validation.data?.isValid || validation.isFetching}
                  onClick={() => setDialog("publish")}
                >
                  {text.publish}
                </Button>
              </>
            ) : (
              <Button
                variant="primary"
                disabled={locked || !canManage}
                onClick={() => void onCreate()}
              >
                {text.create}
              </Button>
            )}
          </>
        }
      />
      {error ? <AdminStateCard tone="danger" description={error} /> : null}
      {notice ? (
        <p role="status" className={styles.notice}>
          {notice}
        </p>
      ) : null}
      <div className={styles.tabs} role="tablist" aria-label={text.title}>
        {(["layout", "settings", "history"] as const).map((value) => (
          <button
            key={value}
            type="button"
            role="tab"
            id={`discovery-tab-${value}`}
            aria-selected={tab === value}
            aria-controls="discovery-panel"
            onClick={() => setTab(value)}
          >
            {text[value]}
          </button>
        ))}
      </div>
      <div id="discovery-panel" role="tabpanel" aria-labelledby={`discovery-tab-${tab}`}>
        {tab === "history" ? (
          <DiscoveryHistory
            text={text}
            locale={locale}
            disabled={!canManage || locked || Boolean(data.draft)}
            onRestore={onCreate}
          />
        ) : (
          <div
            className={`${styles.workspace} ${tab === "settings" ? styles.settingsWorkspace : ""}`}
          >
            {tab === "layout" ? (
              <AdminCard title={text.sections} className={styles.structure}>
                <ol className={styles.sectionList}>
                  {document.sections.map((section, index) => (
                    <li
                      key={section.id}
                      draggable={editable && !locked}
                      onDragStart={() => {
                        dragIndex.current = index;
                      }}
                      onDragEnd={() => {
                        dragIndex.current = null;
                      }}
                      onDragOver={(event) => {
                        if (editable && !locked) event.preventDefault();
                      }}
                      onDrop={(event) => {
                        event.preventDefault();
                        if (editable && !locked && dragIndex.current !== null)
                          setDocument((value) => ({
                            ...value,
                            sections: moveDiscoveryItem(value.sections, dragIndex.current!, index),
                          }));
                        dragIndex.current = null;
                      }}
                      className={selected?.id === section.id ? styles.selectedSection : undefined}
                    >
                      <button
                        type="button"
                        className={styles.sectionSelect}
                        aria-pressed={selected?.id === section.id}
                        onClick={() => setSelectedId(section.id)}
                      >
                        <span className={styles.sectionNumber}>
                          {String(index + 1).padStart(2, "0")}
                        </span>
                        <span>
                          <strong>
                            {discoverySectionTitle(
                              section,
                              contentLocale,
                              categoryNames.get(section.categoryId)
                            )}
                          </strong>
                          <small>
                            {section.isEnabled ? text[section.selectionMode] : text.Discarded}
                          </small>
                        </span>
                      </button>
                      <div className={styles.sectionMoves}>
                        <Button
                          size="sm"
                          aria-label={`${text.up}: ${categoryNames.get(section.categoryId)}`}
                          disabled={!editable || locked || index === 0}
                          onClick={() =>
                            setDocument((value) => ({
                              ...value,
                              sections: moveDiscoveryItem(value.sections, index, index - 1),
                            }))
                          }
                        >
                          ↑
                        </Button>
                        <Button
                          size="sm"
                          aria-label={`${text.down}: ${categoryNames.get(section.categoryId)}`}
                          disabled={!editable || locked || index === document.sections.length - 1}
                          onClick={() =>
                            setDocument((value) => ({
                              ...value,
                              sections: moveDiscoveryItem(value.sections, index, index + 1),
                            }))
                          }
                        >
                          ↓
                        </Button>
                      </div>
                    </li>
                  ))}
                </ol>
                <label className={styles.field}>
                  {text.add}
                  <select
                    value={addCategory}
                    disabled={!editable || locked || document.sections.length >= 24}
                    onChange={(event) => setAddCategory(event.target.value)}
                  >
                    <option value="">{text.selectCategory}</option>
                    {categories
                      .filter(
                        (category) =>
                          !category.isArchived &&
                          !document.sections.some(
                            (section) => section.categoryId === category.categoryId
                          )
                      )
                      .map((category) => (
                        <option key={category.categoryId} value={category.categoryId}>
                          {category.name}
                        </option>
                      ))}
                  </select>
                </label>
                <Button
                  disabled={!editable || locked || !addCategory || document.sections.length >= 24}
                  onClick={() => {
                    const section = newDiscoverySection(
                      addCategory,
                      categoryNames.get(addCategory) ?? ""
                    );
                    setDocument((value) => ({ ...value, sections: [...value.sections, section] }));
                    setSelectedId(section.id);
                    setAddCategory("");
                  }}
                >
                  {text.add}
                </Button>
              </AdminCard>
            ) : null}
            <AdminCard
              className={styles.editor}
              title={tab === "settings" ? text.settings : undefined}
            >
              {tab === "settings" ? (
                <fieldset className={styles.editorFields} disabled={!editable || locked}>
                  <DiscoveryCopyFields
                    copy={document.copy}
                    locale={contentLocale}
                    onLocale={setContentLocale}
                    onChange={(copy) => setDocument((value) => ({ ...value, copy }))}
                    title={text.pageTitle}
                    subtitle={text.pageSubtitle}
                    text={text}
                  />
                  {(["searchEnabled", "carouselEnabled", "autoplayEnabled"] as const).map(
                    (key, index) => (
                      <label key={key} className={styles.check}>
                        <input
                          type="checkbox"
                          checked={document[key]}
                          onChange={(event) =>
                            setDocument((value) => ({ ...value, [key]: event.target.checked }))
                          }
                        />
                        {[text.search, text.showCarousel, text.autoplay][index]}
                      </label>
                    )
                  )}
                  <label className={styles.field}>
                    {text.interval}
                    <select
                      value={document.autoplayIntervalMs}
                      onChange={(event) =>
                        setDocument((value) => ({
                          ...value,
                          autoplayIntervalMs: Number(event.target.value),
                        }))
                      }
                    >
                      {Array.from({ length: 26 }, (_, index) => (index + 5) * 1000).map((value) => (
                        <option key={value} value={value}>
                          {value / 1000}
                        </option>
                      ))}
                    </select>
                  </label>
                </fieldset>
              ) : selected ? (
                <DiscoverySectionEditor
                  key={selected.id}
                  section={selected}
                  categoryName={categoryNames.get(selected.categoryId) ?? ""}
                  disabled={!editable || locked}
                  locale={contentLocale}
                  onLocale={setContentLocale}
                  preview={preview.data}
                  text={text}
                  onChange={(next) =>
                    setDocument((value) => ({
                      ...value,
                      sections: value.sections.map((section) =>
                        section.id === next.id ? next : section
                      ),
                    }))
                  }
                  onRemove={() =>
                    setDocument((value) => ({
                      ...value,
                      sections: value.sections.filter((section) => section.id !== selected.id),
                    }))
                  }
                />
              ) : (
                <p>{text.empty}</p>
              )}
            </AdminCard>
            <aside className={styles.previewColumn}>
              <div className={styles.previewHeader}>
                <h2>{text.preview}</h2>
                <select
                  aria-label={`${text.preview}: ${text.contentLocale}`}
                  value={contentLocale}
                  onChange={(event) => setContentLocale(event.target.value as DiscoveryLocale)}
                >
                  {discoveryLocales.map((value) => (
                    <option key={value} value={value}>
                      {value.toUpperCase()}
                    </option>
                  ))}
                </select>
              </div>
              <p className={styles.hint}>{dirty ? text.previewStale : text.previewHint}</p>
              {preview.isPending ? (
                <p role="status">{text.previewLoading}</p>
              ) : preview.isError ? (
                <PreviewError text={text} retry={() => void preview.refetch()} />
              ) : (
                <DiscoveryPhonePreview
                  key={preview.data.revision}
                  data={preview.data}
                  text={text}
                />
              )}
            </aside>
          </div>
        )}
      </div>
      {saved.state === "Draft" ? (
        <AdminCard
          title={text.validation}
          action={
            <Button
              disabled={locked || validation.isFetching}
              onClick={() => void validation.refetch()}
            >
              {text.retry}
            </Button>
          }
        >
          {dirty ? <p className={styles.hint}>{text.previewStale}</p> : null}
          {validation.isError ? (
            <p role="alert">{text.failed}</p>
          ) : validation.data?.isValid ? (
            <p className={styles.notice}>{text.valid}</p>
          ) : (
            <ul className={styles.issues}>
              {validation.data?.issues.map((issue, index) => (
                <li key={`${issue.path}:${index}`}>
                  <code>{issue.path}</code> {issue.message}
                </li>
              ))}
            </ul>
          )}
          {editable ? (
            <Button variant="ghost" disabled={locked} onClick={() => setDialog("discard")}>
              {text.discard}
            </Button>
          ) : null}
        </AdminCard>
      ) : null}
      <ConfirmationDialog
        open={dialog !== null}
        title={
          dialog === "publish"
            ? text.publishTitle
            : dialog === "discard"
              ? text.discardTitle
              : text.reloadTitle
        }
        description={
          dialog === "publish"
            ? text.publishDescription
            : dialog === "discard"
              ? text.discardDescription
              : text.reloadDescription
        }
        confirmLabel={
          dialog === "publish" ? text.publish : dialog === "discard" ? text.discard : text.reload
        }
        cancelLabel={text.cancel}
        isSubmitting={locked}
        tone={dialog === "publish" ? "primary" : "danger"}
        confirmDisabled={dialog === "publish" && (!reason.trim() || dirty)}
        onCancel={() => {
          if (!locked) setDialog(null);
        }}
        onConfirm={() => void confirm()}
      >
        {dialog === "publish" ? (
          <div className={styles.editorFields}>
            <dl className={styles.diff}>
              {(["added", "removed", "changed", "reordered", "pageChanged"] as const).map((key) => (
                <div key={key}>
                  <dt>{text[key]}</dt>
                  <dd>
                    {typeof diff[key] === "boolean" ? (diff[key] ? text.yes : text.no) : diff[key]}
                  </dd>
                </div>
              ))}
            </dl>
            <label className={styles.field}>
              {text.reason}
              <textarea
                value={reason}
                disabled={locked}
                maxLength={500}
                placeholder={text.reasonPlaceholder}
                onChange={(event) => setReason(event.target.value)}
              />
            </label>
          </div>
        ) : null}
        {error ? <p role="alert">{error}</p> : null}
      </ConfirmationDialog>
    </>
  );
}

function DiscoveryHistory({
  text,
  locale,
  disabled,
  onRestore,
}: {
  text: DiscoveryText;
  locale: Locale;
  disabled: boolean;
  onRestore: (sourceId?: string) => Promise<void>;
}) {
  const [skip, setSkip] = useState(0);
  const [restoreId, setRestoreId] = useState<string | null>(null);
  const history = useQuery({
    queryKey: ["discovery-history", skip],
    queryFn: ({ signal }) => fetchDiscoveryHistory(skip, signal),
  });
  return (
    <AdminCard title={text.history}>
      {history.isError ? (
        <PreviewError text={text} retry={() => void history.refetch()} />
      ) : history.isPending ? (
        <p role="status">{text.loading}</p>
      ) : (
        <>
          {history.data.items.length === 0 ? (
            <p>{text.noHistory}</p>
          ) : (
            <div className={styles.historyList}>
              {history.data.items.map((item) => (
                <article key={item.id} className={styles.historyItem}>
                  <div>
                    <strong>
                      {text.revision} {item.number}
                    </strong>
                    <AdminBadge tone={item.state === "Published" ? "success" : "neutral"}>
                      {text[item.state]}
                    </AdminBadge>
                    <time dateTime={item.updatedAtUtc}>
                      {new Date(item.updatedAtUtc).toLocaleString(locale)}
                    </time>
                    <p>{item.reason}</p>
                  </div>
                  {item.state === "Published" ? (
                    <Button disabled={disabled} onClick={() => setRestoreId(item.id)}>
                      {text.restore}
                    </Button>
                  ) : null}
                </article>
              ))}
            </div>
          )}
          <div className={styles.rowActions}>
            <Button disabled={skip === 0} onClick={() => setSkip(Math.max(0, skip - 20))}>
              {text.previous}
            </Button>
            <Button disabled={!history.data.hasMore} onClick={() => setSkip(skip + 20)}>
              {text.next}
            </Button>
          </div>
        </>
      )}
      <ConfirmationDialog
        open={restoreId !== null}
        title={text.restoreTitle}
        description={text.restoreDescription}
        confirmLabel={text.restore}
        cancelLabel={text.cancel}
        tone="primary"
        isSubmitting={disabled}
        onCancel={() => setRestoreId(null)}
        onConfirm={() => {
          if (restoreId) {
            const id = restoreId;
            setRestoreId(null);
            void onRestore(id);
          }
        }}
      />
    </AdminCard>
  );
}
