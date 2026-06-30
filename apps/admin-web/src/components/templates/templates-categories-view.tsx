"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { useSyncToastToAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminCard,
  AdminKpiCard,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/templates/templates-catalog.module.css";
import { getTemplatesCategoriesViewText } from "@/components/templates/templates-categories-view.content";
import { TemplatesCategoriesTable } from "@/components/templates/templates-categories-view.table";
import { useAdminTemplateCategories } from "@/components/templates/use-admin-template-categories";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  changeTemplateCategoryArchiveState,
  createTemplateCategory,
  deleteTemplateCategory,
  updateTemplateCategory,
  useAuthSession,
  type AdminTemplateCategory,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCategoriesViewProps = {
  locale: Locale;
};

type ArchiveFilter = "active" | "archived";

function formatCategoryActionName(category: AdminTemplateCategory | null): string {
  return sanitizeSensitiveText(category?.name, 96);
}

function getCategoryActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getCategoryActionContext(category?: AdminTemplateCategory | null) {
  return {
    categoryId: category?.categoryId ? sanitizeSensitiveText(category.categoryId, 80) : undefined,
    categoryName: category?.name ? sanitizeSensitiveText(category.name, 96) : undefined,
  };
}

type ToastState = {
  type: "success" | "error";
  message: string;
};

const CATEGORY_NAME_MAX_LENGTH = 64;

export function TemplatesCategoriesView({ locale }: TemplatesCategoriesViewProps) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewCategories = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const canManageCategories = session?.user.roles.includes("Admin") ?? false;
  const { categories, hasError, isFetching, isLoading, refresh } = useAdminTemplateCategories({
    enabled: canViewCategories,
    includeArchived: true,
  });
  const [actionError, setActionError] = useState<string | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const [archiveFilter, setArchiveFilter] = useState<ArchiveFilter>("active");
  const [newCategoryName, setNewCategoryName] = useState("");
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [editingName, setEditingName] = useState("");
  const [busyCategoryId, setBusyCategoryId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [categoryPendingArchive, setCategoryPendingArchive] =
    useState<AdminTemplateCategory | null>(null);
  const [categoryPendingDelete, setCategoryPendingDelete] = useState<AdminTemplateCategory | null>(
    null
  );
  const isCategoryActionLocked = isSubmitting || busyCategoryId !== null || isFetching;
  const categoryText = useMemo(() => getTemplatesCategoriesViewText(locale), [locale]);
  const categoryActionsAdminOnly = categoryText.actionsAdminOnly;
  const error = actionError ?? (hasError ? text.errorLoadingTemplates : null);
  const categoryIds = useMemo(
    () => new Set(categories.map((category) => category.categoryId)),
    [categories]
  );

  useSyncToastToAdminNotifications(toast, {
    category: "templates",
    source: "template-categories",
    title: categoryText.notificationTitle,
    href: `/${locale}/templates/categories`,
  });

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    if (!canViewCategories) {
      ensureAdminSession(locale, router);
    }
  }, [canViewCategories, locale, router, session]);

  useEffect(() => {
    if (isCategoryActionLocked) {
      return;
    }

    const shouldResetArchive =
      categoryPendingArchive !== null && !categoryIds.has(categoryPendingArchive.categoryId);
    const shouldResetDelete =
      categoryPendingDelete !== null && !categoryIds.has(categoryPendingDelete.categoryId);
    const shouldResetEditing = editingCategoryId !== null && !categoryIds.has(editingCategoryId);

    if (!shouldResetArchive && !shouldResetDelete && !shouldResetEditing) {
      return;
    }

    queueMicrotask(() => {
      if (shouldResetArchive) {
        setCategoryPendingArchive(null);
      }

      if (shouldResetDelete) {
        setCategoryPendingDelete(null);
      }

      if (shouldResetEditing) {
        setEditingCategoryId(null);
        setEditingName("");
      }
    });
  }, [
    categoryIds,
    categoryPendingArchive,
    categoryPendingDelete,
    editingCategoryId,
    isCategoryActionLocked,
  ]);

  function assertCanManageCategories(): boolean {
    if (canManageCategories) {
      return true;
    }

    setCategoryPendingArchive(null);
    setCategoryPendingDelete(null);
    setActionError(categoryActionsAdminOnly);
    setToast({ type: "error", message: categoryActionsAdminOnly });
    return false;
  }

  const visibleCategories = useMemo(
    () =>
      categories.filter((category) =>
        archiveFilter === "archived" ? category.isArchived : !category.isArchived
      ),
    [archiveFilter, categories]
  );

  const stats = useMemo(
    () =>
      categories.reduce(
        (summary, category) => {
          summary.totalCategories += 1;
          summary.totalTemplates += category.totalTemplates;
          summary.totalPremium += category.premiumTemplates;

          if (category.isArchived) {
            summary.archivedCategories += 1;
          } else {
            summary.activeCategories += 1;
          }

          return summary;
        },
        {
          totalCategories: 0,
          activeCategories: 0,
          archivedCategories: 0,
          totalTemplates: 0,
          totalPremium: 0,
        }
      ),
    [categories]
  );

  async function handleCreateCategory(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!assertCanManageCategories()) {
      return;
    }

    if (isCategoryActionLocked) {
      return;
    }

    const name = normalizeCategoryName(newCategoryName);
    if (!name) {
      return;
    }

    setIsSubmitting(true);
    setActionError(null);

    try {
      await createTemplateCategory({ name });
      setNewCategoryName("");
      const result = await refresh();
      if (result.isError) {
        throw result.error;
      }
      setToast({ type: "success", message: categoryText.createSuccess });
    } catch (actionError) {
      clientLogger.warn("templates.categories_create_failed", {
        categoryName: sanitizeSensitiveText(name, 96),
        ...getCategoryActionErrorDetails(actionError),
      });
      const message = getActionErrorMessage(actionError, categoryText.createError);
      setActionError(message);
      setToast({ type: "error", message });
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleUpdateCategory(categoryId: string) {
    if (!assertCanManageCategories()) {
      return;
    }

    if (isCategoryActionLocked) {
      return;
    }

    const name = normalizeCategoryName(editingName);
    if (!name) {
      return;
    }

    setBusyCategoryId(categoryId);
    setActionError(null);

    try {
      await updateTemplateCategory(categoryId, { name });
      setEditingCategoryId(null);
      setEditingName("");
      const result = await refresh();
      if (result.isError) {
        throw result.error;
      }
      setToast({ type: "success", message: categoryText.updateSuccess });
    } catch (actionError) {
      clientLogger.warn("templates.categories_update_failed", {
        categoryId: sanitizeSensitiveText(categoryId, 80),
        categoryName: sanitizeSensitiveText(name, 96),
        ...getCategoryActionErrorDetails(actionError),
      });
      const message = getActionErrorMessage(actionError, categoryText.updateError);
      setActionError(message);
      setToast({ type: "error", message });
    } finally {
      setBusyCategoryId(null);
    }
  }

  async function handleArchiveToggle(category: AdminTemplateCategory): Promise<boolean> {
    if (!assertCanManageCategories()) {
      return false;
    }

    if (isCategoryActionLocked) {
      return false;
    }

    setBusyCategoryId(category.categoryId);
    setActionError(null);

    try {
      await changeTemplateCategoryArchiveState(category.categoryId, !category.isArchived);
      if (editingCategoryId === category.categoryId) {
        setEditingCategoryId(null);
        setEditingName("");
      }
      const result = await refresh();
      if (result.isError) {
        throw result.error;
      }
      setToast({
        type: "success",
        message: category.isArchived ? categoryText.restoreSuccess : categoryText.archiveSuccess,
      });
      return true;
    } catch (actionError) {
      clientLogger.warn("templates.categories_archive_toggle_failed", {
        ...getCategoryActionContext(category),
        nextArchivedState: !category.isArchived,
        ...getCategoryActionErrorDetails(actionError),
      });
      const message = getActionErrorMessage(actionError, categoryText.archiveError);
      setActionError(message);
      setToast({ type: "error", message });
      return false;
    } finally {
      setBusyCategoryId(null);
    }
  }

  async function handleDeleteCategory(category: AdminTemplateCategory): Promise<boolean> {
    if (!assertCanManageCategories()) {
      return false;
    }

    if (isCategoryActionLocked) {
      return false;
    }

    setBusyCategoryId(category.categoryId);
    setActionError(null);

    try {
      await deleteTemplateCategory(category.categoryId);
      if (editingCategoryId === category.categoryId) {
        setEditingCategoryId(null);
        setEditingName("");
      }
      const result = await refresh();
      if (result.isError) {
        throw result.error;
      }
      setToast({ type: "success", message: categoryText.deleteSuccess });
      return true;
    } catch (actionError) {
      clientLogger.warn("templates.categories_delete_failed", {
        ...getCategoryActionContext(category),
        totalTemplates: category.totalTemplates,
        ...getCategoryActionErrorDetails(actionError),
      });
      const message = getActionErrorMessage(actionError, categoryText.deleteError);
      setActionError(message);
      setToast({ type: "error", message });
      return false;
    } finally {
      setBusyCategoryId(null);
    }
  }

  function requestArchiveToggle(category: AdminTemplateCategory) {
    if (!assertCanManageCategories()) {
      return;
    }

    if (isCategoryActionLocked) {
      return;
    }

    setCategoryPendingArchive(category);
  }

  function requestDeleteCategory(category: AdminTemplateCategory) {
    if (!assertCanManageCategories()) {
      return;
    }

    if (isCategoryActionLocked || category.totalTemplates > 0) {
      return;
    }

    setCategoryPendingDelete(category);
  }

  function switchArchiveFilter(nextFilter: ArchiveFilter) {
    if (isCategoryActionLocked) {
      return;
    }

    setArchiveFilter(nextFilter);
    setEditingCategoryId(null);
    setEditingName("");
    setCategoryPendingArchive(null);
    setCategoryPendingDelete(null);
  }

  function requestCategoriesRetry() {
    if (!canViewCategories || isFetching) {
      return;
    }

    void refresh().catch(() => undefined);
  }

  if (!canViewCategories || isLoading) {
    return (
      <AdminPage className={styles.catalogPage}>
        <AdminPageGrid
          columns="four"
          className={styles.loadingGrid}
          aria-busy="true"
          aria-live="polite"
        >
          {Array.from({ length: 6 }).map((_, index) => (
            <div key={index} className={styles.skeletonCard} />
          ))}
        </AdminPageGrid>
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.catalogPage}>
      <AdminPageHero
        eyebrow={categoryText.heroEyebrow}
        title={categoryText.heroTitle}
        description={categoryText.heroDescription}
        badge={canManageCategories ? categoryText.crudEnabled : categoryText.readOnly}
        actions={
          <div className={styles.catalogActions}>
            <button
              type="button"
              className={archiveFilter === "active" ? styles.tabActive : styles.tab}
              disabled={isCategoryActionLocked}
              onClick={() => switchArchiveFilter("active")}
            >
              {categoryText.activeTab}
            </button>
            <button
              type="button"
              className={archiveFilter === "archived" ? styles.tabActive : styles.tab}
              disabled={isCategoryActionLocked}
              onClick={() => switchArchiveFilter("archived")}
            >
              {categoryText.archiveTab}
            </button>
          </div>
        }
        metaItems={[
          `${categoryText.categoriesMeta}: ${stats.totalCategories}`,
          `${categoryText.templatesMeta}: ${stats.totalTemplates}`,
          `${text.premiumLabel}: ${stats.totalPremium}`,
        ]}
      />

      {error ? (
        <AdminStateCard
          tone="danger"
          className={styles.error}
          title={error}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewCategories || isFetching}
              onClick={requestCategoriesRetry}
            >
              {categoryText.retry}
            </Button>
          }
        />
      ) : null}

      <AdminPageGrid columns="four" className={styles.categoryStatsGrid}>
        <AdminKpiCard
          tone="primary"
          label={categoryText.totalCategories}
          value={stats.totalCategories}
          hint={categoryText.totalCategoriesHint}
        />
        <AdminKpiCard
          tone="success"
          label={categoryText.activeCategories}
          value={stats.activeCategories}
          hint={categoryText.activeCategoriesHint}
        />
        <AdminKpiCard
          tone="warning"
          label={categoryText.archiveLabel}
          value={stats.archivedCategories}
          hint={categoryText.archivedCategoriesHint}
        />
        <AdminKpiCard
          tone="info"
          label={categoryText.totalTemplates}
          value={stats.totalTemplates}
          hint={categoryText.totalTemplatesHint}
        />
      </AdminPageGrid>

      {canManageCategories ? (
        <AdminCard
          title={categoryText.newCategoryTitle}
          description={categoryText.newCategoryDescription}
        >
          <form
            className={styles.categoryToolbar}
            onSubmit={handleCreateCategory}
            aria-busy={isCategoryActionLocked}
          >
            <label className={styles.categoryField}>
              <span>{text.categoryLabel}</span>
              <input
                className={styles.categoryInput}
                value={newCategoryName}
                onChange={(event) => setNewCategoryName(limitCategoryNameInput(event.target.value))}
                placeholder={categoryText.categoryPlaceholder}
                maxLength={CATEGORY_NAME_MAX_LENGTH}
                disabled={isCategoryActionLocked}
              />
            </label>
            <Button
              type="submit"
              variant="primary"
              disabled={isCategoryActionLocked || !newCategoryName.trim()}
            >
              {categoryText.addCategory}
            </Button>
          </form>
        </AdminCard>
      ) : null}

      <TemplatesCategoriesTable
        locale={locale}
        canManageCategories={canManageCategories}
        visibleCategories={visibleCategories}
        description={
          archiveFilter === "archived"
            ? categoryText.archivedDescription
            : categoryText.activeDescription
        }
        editingCategoryId={editingCategoryId}
        editingName={editingName}
        isCategoryActionLocked={isCategoryActionLocked}
        categoryText={categoryText}
        categoryNameLabel={text.categoryLabel}
        videoBadgeLabel={text.templateKindVideoBadge}
        imageBadgeLabel={text.templateKindImageBadge}
        statusLabel={text.statusLabel}
        premiumLabel={text.premiumLabel}
        actionsLabel={text.actionsLabel}
        editTemplateLabel={text.editTemplate}
        archiveLabel={text.archive}
        deleteTemplateLabel={text.deleteTemplate}
        formatCategoryActionName={formatCategoryActionName}
        onEditingNameChange={(value) => setEditingName(limitCategoryNameInput(value))}
        onStartEdit={(category) => {
          setEditingCategoryId(category.categoryId);
          setEditingName(normalizeCategoryName(category.name));
        }}
        onSaveEdit={(categoryId) => void handleUpdateCategory(categoryId)}
        onCancelEdit={() => {
          setEditingCategoryId(null);
          setEditingName("");
        }}
        onArchiveToggle={requestArchiveToggle}
        onDeleteCategory={requestDeleteCategory}
        categoryNameMaxLength={CATEGORY_NAME_MAX_LENGTH}
      />

      <ConfirmationDialog
        open={categoryPendingArchive !== null}
        title={
          categoryPendingArchive?.isArchived
            ? categoryText.restoreDialogTitle
            : categoryText.archiveDialogTitle
        }
        description={
          categoryPendingArchive
            ? categoryPendingArchive.isArchived
              ? categoryText.restoreDialogDescription(
                  formatCategoryActionName(categoryPendingArchive)
                )
              : categoryText.archiveDialogDescription(
                  formatCategoryActionName(categoryPendingArchive)
                )
            : ""
        }
        confirmLabel={categoryPendingArchive?.isArchived ? categoryText.restore : text.archive}
        cancelLabel={categoryText.cancel}
        isSubmitting={Boolean(categoryPendingArchive && isCategoryActionLocked)}
        tone="primary"
        onCancel={() => {
          if (!isCategoryActionLocked) {
            setCategoryPendingArchive(null);
          }
        }}
        onConfirm={() => {
          if (!categoryPendingArchive) {
            return;
          }

          void handleArchiveToggle(categoryPendingArchive).then((succeeded) => {
            if (succeeded) {
              setCategoryPendingArchive(null);
            }
          });
        }}
      />

      <ConfirmationDialog
        open={categoryPendingDelete !== null}
        title={categoryText.deleteDialogTitle}
        description={
          categoryPendingDelete
            ? categoryText.deleteDialogDescription(formatCategoryActionName(categoryPendingDelete))
            : ""
        }
        confirmLabel={text.deleteTemplate}
        cancelLabel={categoryText.cancel}
        isSubmitting={Boolean(categoryPendingDelete && isCategoryActionLocked)}
        onCancel={() => {
          if (!isCategoryActionLocked) {
            setCategoryPendingDelete(null);
          }
        }}
        onConfirm={() => {
          if (!categoryPendingDelete) {
            return;
          }

          void handleDeleteCategory(categoryPendingDelete).then((succeeded) => {
            if (succeeded) {
              setCategoryPendingDelete(null);
            }
          });
        }}
      />

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </AdminPage>
  );
}

function getActionErrorMessage(error: unknown, fallback: string): string {
  return getAdminErrorMessage(error, fallback);
}

function normalizeCategoryName(value: string): string {
  return value.trim().slice(0, CATEGORY_NAME_MAX_LENGTH);
}

function limitCategoryNameInput(value: string): string {
  return value.slice(0, CATEGORY_NAME_MAX_LENGTH);
}
