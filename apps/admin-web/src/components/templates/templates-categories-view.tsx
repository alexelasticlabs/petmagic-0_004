"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { ImageIcon, VideoIcon } from "@/components/admin/admin-icons";
import { useSyncToastToAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminCard,
  AdminKpiCard,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/templates/templates-catalog.module.css";
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

const typeColors = {
  Video: "var(--success)",
  Image: "var(--info)",
  Archived: "var(--text-muted)",
};

const CATEGORY_NAME_MAX_LENGTH = 64;

export function TemplatesCategoriesView({ locale }: TemplatesCategoriesViewProps) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewCategories =
    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
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
  const [categoryPendingDelete, setCategoryPendingDelete] =
    useState<AdminTemplateCategory | null>(null);
  const isCategoryActionLocked = isSubmitting || busyCategoryId !== null || isFetching;
  const isRu = locale === "ru";
  const categoryText = useMemo(
    () => ({
      actionsAdminOnly: isRu
        ? "Управление категориями доступно только Admin."
        : "Template category management is available to Admin only.",
      notificationTitle: isRu ? "Категории шаблонов" : "Template categories",
      createSuccess: isRu ? "Категория создана." : "Category created.",
      createError: isRu ? "Не удалось создать категорию." : "Could not create category.",
      updateSuccess: isRu ? "Категория обновлена." : "Category updated.",
      updateError: isRu ? "Не удалось обновить категорию." : "Could not update category.",
      archiveSuccess: isRu ? "Категория отправлена в архив." : "Category archived.",
      restoreSuccess: isRu ? "Категория возвращена из архива." : "Category restored from archive.",
      archiveError: isRu
        ? "Не удалось изменить состояние категории."
        : "Could not change category state.",
      deleteSuccess: isRu ? "Категория удалена." : "Category deleted.",
      deleteError: isRu ? "Не удалось удалить категорию." : "Could not delete category.",
      heroEyebrow: isRu ? "Структура каталога" : "Template taxonomy",
      heroTitle: isRu ? "Категории шаблонов" : "Template Categories",
      heroDescription: isRu
        ? "Управляйте списком категорий, архивом и переименованием. Переименование категории автоматически обновляет связанные шаблоны."
        : "Manage the category registry, archive state, and rename flows. Renaming a category updates linked templates automatically.",
      crudEnabled: isRu ? "CRUD подключен" : "CRUD enabled",
      readOnly: isRu ? "Только просмотр" : "Read-only",
      activeTab: isRu ? "Активные" : "Active",
      archiveTab: isRu ? "Архив" : "Archive",
      categoriesMeta: isRu ? "Категорий" : "Categories",
      templatesMeta: isRu ? "Шаблонов" : "Templates",
      retry: isRu ? "Повторить" : "Retry",
      totalCategories: isRu ? "Всего категорий" : "Total categories",
      totalCategoriesHint: isRu ? "Категории в реестре" : "Categories in the registry",
      activeCategories: isRu ? "Активные категории" : "Active categories",
      activeCategoriesHint: isRu ? "Доступны для новых шаблонов" : "Available for new templates",
      archiveLabel: isRu ? "Архив" : "Archive",
      archivedCategoriesHint: isRu
        ? "Скрыты для новых шаблонов"
        : "Hidden from new template assignment",
      totalTemplates: isRu ? "Всего шаблонов" : "Total templates",
      totalTemplatesHint: isRu ? "Видео и изображения вместе" : "Video and image combined",
      newCategoryTitle: isRu ? "Новая категория" : "New category",
      newCategoryDescription: isRu
        ? "Сначала создайте категорию здесь, затем она появится в редакторах шаблонов."
        : "Create categories here first so they become available in template editors.",
      categoryPlaceholder: isRu ? "Например, Portrait Pets" : "For example, Portrait Pets",
      addCategory: isRu ? "Добавить категорию" : "Add category",
      categoriesTitle: isRu ? "Категории" : "Categories",
      archivedDescription: isRu
        ? "Архивные категории остаются в статистике и в связанных шаблонах, но не предлагаются для новых шаблонов."
        : "Archived categories stay in stats and linked templates, but are not suggested for new templates.",
      activeDescription: isRu
        ? "Переименование категории синхронно обновляет поле category у связанных шаблонов."
        : "Renaming a category synchronously updates the category field on linked templates.",
      empty: isRu ? "Категории не найдены." : "No categories found.",
      state: isRu ? "Состояние" : "State",
      total: isRu ? "Всего" : "Total",
      archivedStatus: isRu ? "Архив" : "Archived",
      activeStatus: isRu ? "Активна" : "Active",
      save: isRu ? "Сохранить" : "Save",
      cancel: isRu ? "Отмена" : "Cancel",
      restore: isRu ? "Вернуть" : "Restore",
      restoreDialogTitle: isRu ? "Вернуть категорию?" : "Restore category?",
      archiveDialogTitle: isRu ? "Архивировать категорию?" : "Archive category?",
      deleteDialogTitle: isRu ? "Удалить категорию?" : "Delete category?",
      restoreDialogDescription: (name: string) =>
        isRu
          ? `Вернуть категорию "${name}" в активный список?`
          : `Restore category "${name}" to the active list?`,
      archiveDialogDescription: (name: string) =>
        isRu
          ? `Архивировать категорию "${name}"? Она останется в связанных шаблонах, но не будет доступна для новых шаблонов.`
          : `Archive category "${name}"? It will stay on linked templates but won't be available for new templates.`,
      deleteDialogDescription: (name: string) =>
        isRu
          ? `Удалить категорию "${name}"? Категория удаляется только если в ней нет шаблонов.`
          : `Delete category "${name}"? It can only be removed when no templates reference it.`,
      videoCategoryLabel: (name: string) =>
        isRu ? `Открыть видео-шаблоны категории ${name}` : `Open video templates in ${name}`,
      imageCategoryLabel: (name: string) =>
        isRu ? `Открыть image-шаблоны категории ${name}` : `Open image templates in ${name}`,
      editCategoryLabel: (name: string) =>
        isRu ? `Переименовать категорию ${name}` : `Rename category ${name}`,
      archiveCategoryLabel: (name: string) =>
        isRu ? `Архивировать категорию ${name}` : `Archive category ${name}`,
      restoreCategoryLabel: (name: string) =>
        isRu ? `Вернуть категорию ${name}` : `Restore category ${name}`,
      deleteCategoryLabel: (name: string) =>
        isRu ? `Удалить категорию ${name}` : `Delete category ${name}`,
    }),
    [isRu]
  );
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
    const shouldResetEditing =
      editingCategoryId !== null && !categoryIds.has(editingCategoryId);

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

      <AdminCard
        title={categoryText.categoriesTitle}
        description={
          archiveFilter === "archived"
            ? categoryText.archivedDescription
            : categoryText.activeDescription
        }
      >
        {!visibleCategories.length ? (
          <AdminStateCard
            tone="info"
            className={styles.empty}
            title={categoryText.empty}
          />
        ) : (
          <div className={adminTableStyles.tableWrap} aria-busy={isFetching ? "true" : undefined}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.categoryLabel}</th>
                  <th>{categoryText.state}</th>
                  <th>{categoryText.total}</th>
                  <th>{text.templateKindVideoBadge}</th>
                  <th>{text.templateKindImageBadge}</th>
                  <th>{text.statusLabel}</th>
                  <th>{text.premiumLabel}</th>
                  <th>{text.actionsLabel}</th>
                </tr>
              </thead>
              <tbody>
                {visibleCategories.map((category) => (
                  <tr key={category.categoryId}>
                    <td data-label={text.categoryLabel}>
                      {canManageCategories && editingCategoryId === category.categoryId ? (
                        <input
                          className={styles.categoryInput}
                          value={editingName}
                          onChange={(event) => setEditingName(limitCategoryNameInput(event.target.value))}
                          maxLength={CATEGORY_NAME_MAX_LENGTH}
                          disabled={isCategoryActionLocked}
                        />
                      ) : (
                        <div className={styles.titleCell}>
                          <strong>{sanitizeSensitiveText(category.name, 96)}</strong>
                          <span>
                            {category.tags
                              .slice(0, 4)
                              .map((tag) => `#${sanitizeSensitiveText(tag, 40)}`)
                              .join(" ") || "-"}
                          </span>
                        </div>
                      )}
                    </td>
                    <td data-label={categoryText.state}>
                      <AdminStatusBadge
                        color={category.isArchived ? typeColors.Archived : typeColors.Video}
                      >
                        {category.isArchived
                          ? categoryText.archivedStatus
                          : categoryText.activeStatus}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={categoryText.total}>{category.totalTemplates}</td>
                    <td data-label={text.templateKindVideoBadge}>
                      <AdminStatusBadge color={typeColors.Video}>
                        {category.videoTemplates}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={text.templateKindImageBadge}>
                      <AdminStatusBadge color={typeColors.Image}>
                        {category.imageTemplates}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={text.statusLabel}>
                      {category.activeTemplates} / {category.draftTemplates} /{" "}
                      {category.archivedTemplates}
                    </td>
                    <td data-label={text.premiumLabel}>{category.premiumTemplates}</td>
                    <td data-label={text.actionsLabel}>
                      <div className={`${styles.tableActions} ${styles.categoryTableActions}`}>
                        {canManageCategories && editingCategoryId === category.categoryId ? (
                          <>
                            <Button
                              type="button"
                              size="sm"
                              variant="primary"
                              disabled={
                                isCategoryActionLocked || !editingName.trim()
                              }
                              onClick={() => void handleUpdateCategory(category.categoryId)}
                            >
                              {categoryText.save}
                            </Button>
                            <Button
                              type="button"
                              size="sm"
                              variant="ghost"
                              disabled={isCategoryActionLocked}
                              onClick={() => {
                                setEditingCategoryId(null);
                                setEditingName("");
                              }}
                            >
                              {categoryText.cancel}
                            </Button>
                          </>
                        ) : (
                          <>
                            <Link
                              className={`${styles.compactLink}${
                                isCategoryActionLocked ? ` ${styles.compactLinkDisabled}` : ""
                              }`}
                              href={`/${locale}/templates/video?category=${encodeURIComponent(category.name)}`}
                              aria-disabled={isCategoryActionLocked}
                              aria-label={categoryText.videoCategoryLabel(
                                formatCategoryActionName(category)
                              )}
                              title={categoryText.videoCategoryLabel(
                                formatCategoryActionName(category)
                              )}
                              tabIndex={isCategoryActionLocked ? -1 : undefined}
                              onClick={(event) => {
                                if (isCategoryActionLocked) {
                                  event.preventDefault();
                                }
                              }}
                            >
                              <VideoIcon className={styles.linkIcon} />
                              <span>{text.templateKindVideoBadge}</span>
                            </Link>
                            <Link
                              className={`${styles.compactLink}${
                                isCategoryActionLocked ? ` ${styles.compactLinkDisabled}` : ""
                              }`}
                              href={`/${locale}/templates/image?category=${encodeURIComponent(category.name)}`}
                              aria-disabled={isCategoryActionLocked}
                              aria-label={categoryText.imageCategoryLabel(
                                formatCategoryActionName(category)
                              )}
                              title={categoryText.imageCategoryLabel(
                                formatCategoryActionName(category)
                              )}
                              tabIndex={isCategoryActionLocked ? -1 : undefined}
                              onClick={(event) => {
                                if (isCategoryActionLocked) {
                                  event.preventDefault();
                                }
                              }}
                            >
                              <ImageIcon className={styles.linkIcon} />
                              <span>{text.templateKindImageBadge}</span>
                            </Link>
                            {canManageCategories ? (
                              <>
                                <Button
                                  type="button"
                                  size="sm"
                                  variant="ghost"
                                  disabled={isCategoryActionLocked}
                                  aria-label={categoryText.editCategoryLabel(
                                    formatCategoryActionName(category)
                                  )}
                                  title={categoryText.editCategoryLabel(
                                    formatCategoryActionName(category)
                                  )}
                                  onClick={() => {
                                    setEditingCategoryId(category.categoryId);
                                    setEditingName(normalizeCategoryName(category.name));
                                  }}
                                >
                                  {text.editTemplate}
                                </Button>
                                <Button
                                  type="button"
                                  size="sm"
                                  variant="secondary"
                                  disabled={isCategoryActionLocked}
                                  aria-label={
                                    category.isArchived
                                      ? categoryText.restoreCategoryLabel(
                                          formatCategoryActionName(category)
                                        )
                                      : categoryText.archiveCategoryLabel(
                                          formatCategoryActionName(category)
                                        )
                                  }
                                  title={
                                    category.isArchived
                                      ? categoryText.restoreCategoryLabel(
                                          formatCategoryActionName(category)
                                        )
                                      : categoryText.archiveCategoryLabel(
                                          formatCategoryActionName(category)
                                        )
                                  }
                                  onClick={() => requestArchiveToggle(category)}
                                >
                                  {category.isArchived
                                    ? categoryText.restore
                                    : text.archive}
                                </Button>
                                <Button
                                  type="button"
                                  size="sm"
                                  variant="danger"
                                  disabled={
                                    isCategoryActionLocked ||
                                    category.totalTemplates > 0
                                  }
                                  aria-label={categoryText.deleteCategoryLabel(
                                    formatCategoryActionName(category)
                                  )}
                                  title={categoryText.deleteCategoryLabel(
                                    formatCategoryActionName(category)
                                  )}
                                  onClick={() => requestDeleteCategory(category)}
                                >
                                  {text.deleteTemplate}
                                </Button>
                              </>
                            ) : null}
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </AdminCard>

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
        confirmLabel={
          categoryPendingArchive?.isArchived ? categoryText.restore : text.archive
        }
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
