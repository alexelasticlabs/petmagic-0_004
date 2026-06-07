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
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCategoriesViewProps = {
  locale: Locale;
};

type ArchiveFilter = "active" | "archived";

function formatCategoryActionName(category: AdminTemplateCategory | null): string {
  return sanitizeSensitiveText(category?.name, 96);
}

type ToastState = {
  type: "success" | "error";
  message: string;
};

const typeColors = {
  Video: "#22c55e",
  Image: "#38bdf8",
  Archived: "#94a3b8",
};

const CATEGORY_NAME_MAX_LENGTH = 64;

export function TemplatesCategoriesView({ locale }: TemplatesCategoriesViewProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const session = useAuthSession();
  const canManageCategories = session?.user.roles.includes("Admin") ?? false;
  const { categories, hasError, isFetching, isLoading, refresh } = useAdminTemplateCategories({
    enabled: Boolean(session),
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
  const isCategoryActionLocked = isSubmitting || busyCategoryId !== null;
  const isRu = locale === "ru";
  const categoryActionsAdminOnly = isRu
    ? "Управление категориями доступно только Admin."
    : "Template category management is available to Admin only.";
  const error = actionError ?? (hasError ? text.errorLoadingTemplates : null);

  useSyncToastToAdminNotifications(toast, {
    category: "templates",
    source: "template-categories",
    title: isRu ? "Категории шаблонов" : "Template categories",
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
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

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
    () => ({
      totalCategories: categories.length,
      activeCategories: categories.filter((category) => !category.isArchived).length,
      archivedCategories: categories.filter((category) => category.isArchived).length,
      totalTemplates: categories.reduce((sum, category) => sum + category.totalTemplates, 0),
      totalPremium: categories.reduce((sum, category) => sum + category.premiumTemplates, 0),
    }),
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
      setToast({ type: "success", message: isRu ? "Категория создана." : "Category created." });
    } catch (actionError) {
      const message = getActionErrorMessage(
        actionError,
        isRu ? "Не удалось создать категорию." : "Could not create category."
      );
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
      setToast({ type: "success", message: isRu ? "Категория обновлена." : "Category updated." });
    } catch (actionError) {
      const message = getActionErrorMessage(
        actionError,
        isRu ? "Не удалось обновить категорию." : "Could not update category."
      );
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
        message: category.isArchived
          ? isRu
            ? "Категория возвращена из архива."
            : "Category restored from archive."
          : isRu
            ? "Категория отправлена в архив."
            : "Category archived.",
      });
      return true;
    } catch (actionError) {
      const message = getActionErrorMessage(
        actionError,
        isRu ? "Не удалось изменить состояние категории." : "Could not change category state."
      );
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
      setToast({ type: "success", message: isRu ? "Категория удалена." : "Category deleted." });
      return true;
    } catch (actionError) {
      const message = getActionErrorMessage(
        actionError,
        isRu ? "Не удалось удалить категорию." : "Could not delete category."
      );
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

  if (!session || isLoading) {
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
        eyebrow={isRu ? "Структура каталога" : "Template taxonomy"}
        title={isRu ? "Категории шаблонов" : "Template Categories"}
        description={
          isRu
            ? "Управляйте списком категорий, архивом и переименованием. Переименование категории автоматически обновляет связанные шаблоны."
            : "Manage the category registry, archive state, and rename flows. Renaming a category updates linked templates automatically."
        }
        badge={
          canManageCategories
            ? isRu
              ? "CRUD подключен"
              : "CRUD enabled"
            : isRu
              ? "Только просмотр"
              : "Read-only"
        }
        actions={
          <div className={styles.catalogActions}>
            <button
              type="button"
              className={archiveFilter === "active" ? styles.tabActive : styles.tab}
              onClick={() => setArchiveFilter("active")}
            >
              {isRu ? "Активные" : "Active"}
            </button>
            <button
              type="button"
              className={archiveFilter === "archived" ? styles.tabActive : styles.tab}
              onClick={() => setArchiveFilter("archived")}
            >
              {isRu ? "Архив" : "Archive"}
            </button>
          </div>
        }
        metaItems={[
          `${isRu ? "Категорий" : "Categories"}: ${stats.totalCategories}`,
          `${isRu ? "Шаблонов" : "Templates"}: ${stats.totalTemplates}`,
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
              disabled={!session || isFetching}
              onClick={() => {
                if (!session) {
                  return;
                }

                void refresh().catch(() => undefined);
              }}
            >
              {isRu ? "Повторить" : "Retry"}
            </Button>
          }
        />
      ) : null}

      <AdminPageGrid columns="four" className={styles.categoryStatsGrid}>
        <AdminKpiCard
          tone="primary"
          label={isRu ? "Всего категорий" : "Total categories"}
          value={stats.totalCategories}
          hint={isRu ? "Категории в реестре" : "Categories in the registry"}
        />
        <AdminKpiCard
          tone="success"
          label={isRu ? "Активные категории" : "Active categories"}
          value={stats.activeCategories}
          hint={isRu ? "Доступны для новых шаблонов" : "Available for new templates"}
        />
        <AdminKpiCard
          tone="warning"
          label={isRu ? "Архив" : "Archive"}
          value={stats.archivedCategories}
          hint={isRu ? "Скрыты для новых шаблонов" : "Hidden from new template assignment"}
        />
        <AdminKpiCard
          tone="info"
          label={isRu ? "Всего шаблонов" : "Total templates"}
          value={stats.totalTemplates}
          hint={isRu ? "Видео и изображения вместе" : "Video and image combined"}
        />
      </AdminPageGrid>

      {canManageCategories ? (
        <AdminCard
          title={isRu ? "Новая категория" : "New category"}
          description={
            isRu
              ? "Сначала создайте категорию здесь, затем она появится в редакторах шаблонов."
              : "Create categories here first so they become available in template editors."
          }
        >
          <form className={styles.categoryToolbar} onSubmit={handleCreateCategory}>
            <label className={styles.categoryField}>
              <span>{text.categoryLabel}</span>
              <input
                className={styles.categoryInput}
                value={newCategoryName}
                onChange={(event) => setNewCategoryName(normalizeCategoryName(event.target.value))}
                placeholder={isRu ? "Например, Portrait Pets" : "For example, Portrait Pets"}
                maxLength={CATEGORY_NAME_MAX_LENGTH}
              />
            </label>
            <Button
              type="submit"
              variant="primary"
              disabled={isCategoryActionLocked || !newCategoryName.trim()}
            >
              {isRu ? "Добавить категорию" : "Add category"}
            </Button>
          </form>
        </AdminCard>
      ) : null}

      <AdminCard
        title={isRu ? "Категории" : "Categories"}
        description={
          archiveFilter === "archived"
            ? isRu
              ? "Архивные категории остаются в статистике и в связанных шаблонах, но не предлагаются для новых шаблонов."
              : "Archived categories stay in stats and linked templates, but are not suggested for new templates."
            : isRu
              ? "Переименование категории синхронно обновляет поле category у связанных шаблонов."
              : "Renaming a category synchronously updates the category field on linked templates."
        }
      >
        {!visibleCategories.length ? (
          <AdminStateCard
            tone="info"
            className={styles.empty}
            title={isRu ? "Категории не найдены." : "No categories found."}
          />
        ) : (
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.categoryLabel}</th>
                  <th>{isRu ? "Состояние" : "State"}</th>
                  <th>{isRu ? "Всего" : "Total"}</th>
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
                          onChange={(event) => setEditingName(normalizeCategoryName(event.target.value))}
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
                    <td data-label={isRu ? "Состояние" : "State"}>
                      <AdminStatusBadge
                        color={category.isArchived ? typeColors.Archived : typeColors.Video}
                      >
                        {category.isArchived
                          ? isRu
                            ? "Архив"
                            : "Archived"
                          : isRu
                            ? "Активна"
                            : "Active"}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={isRu ? "Всего" : "Total"}>{category.totalTemplates}</td>
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
                      <div className={styles.tableActions}>
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
                              {isRu ? "Сохранить" : "Save"}
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
                              {isRu ? "Отмена" : "Cancel"}
                            </Button>
                          </>
                        ) : (
                          <>
                            <Link
                              className={styles.compactLink}
                              href={`/${locale}/templates/video?category=${encodeURIComponent(category.name)}`}
                            >
                              <VideoIcon className={styles.linkIcon} />
                              <span>{text.templateKindVideoBadge}</span>
                            </Link>
                            <Link
                              className={styles.compactLink}
                              href={`/${locale}/templates/image?category=${encodeURIComponent(category.name)}`}
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
                                  onClick={() => requestArchiveToggle(category)}
                                >
                                  {category.isArchived
                                    ? isRu
                                      ? "Вернуть"
                                      : "Restore"
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
            ? isRu
              ? "Вернуть категорию?"
              : "Restore category?"
            : isRu
              ? "Архивировать категорию?"
              : "Archive category?"
        }
        description={
          categoryPendingArchive
            ? categoryPendingArchive.isArchived
              ? isRu
                ? `Вернуть категорию "${formatCategoryActionName(categoryPendingArchive)}" в активный список?`
                : `Restore category "${formatCategoryActionName(categoryPendingArchive)}" to the active list?`
              : isRu
                ? `Архивировать категорию "${formatCategoryActionName(categoryPendingArchive)}"? Она останется в связанных шаблонах, но не будет доступна для новых шаблонов.`
                : `Archive category "${formatCategoryActionName(categoryPendingArchive)}"? It will stay on linked templates but won't be available for new templates.`
            : ""
        }
        confirmLabel={
          categoryPendingArchive?.isArchived ? (isRu ? "Вернуть" : "Restore") : text.archive
        }
        cancelLabel={isRu ? "Отмена" : "Cancel"}
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
        title={isRu ? "Удалить категорию?" : "Delete category?"}
        description={
          categoryPendingDelete
            ? isRu
              ? `Удалить категорию "${formatCategoryActionName(categoryPendingDelete)}"? Категория удаляется только если в ней нет шаблонов.`
              : `Delete category "${formatCategoryActionName(categoryPendingDelete)}"? It can only be removed when no templates reference it.`
            : ""
        }
        confirmLabel={text.deleteTemplate}
        cancelLabel={isRu ? "Отмена" : "Cancel"}
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
