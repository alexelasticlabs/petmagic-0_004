"use client";

import { ImageIcon, VideoIcon } from "@/components/admin/admin-icons";
import { AdminCard, AdminKpiCard, AdminPage, AdminPageGrid, AdminPageHero, AdminStateCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import styles from "@/components/templates/templates-catalog.module.css";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import {
    changeTemplateCategoryArchiveState,
    createTemplateCategory,
    deleteTemplateCategory,
    fetchAdminTemplateCategories,
    updateTemplateCategory,
    type AdminTemplateCategory,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

type TemplatesCategoriesViewProps = {
  locale: Locale;
};

type ArchiveFilter = "active" | "archived";

type ToastState = {
  type: "success" | "error";
  message: string;
};

const typeColors = {
  Video: "#22c55e",
  Image: "#38bdf8",
  Archived: "#94a3b8",
};

export function TemplatesCategoriesView({ locale }: TemplatesCategoriesViewProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const [categories, setCategories] = useState<AdminTemplateCategory[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const [archiveFilter, setArchiveFilter] = useState<ArchiveFilter>("active");
  const [newCategoryName, setNewCategoryName] = useState("");
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [editingName, setEditingName] = useState("");
  const [busyCategoryId, setBusyCategoryId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isRu = locale === "ru";

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const loadCategories = useCallback(async (showLoading = true) => {
    if (showLoading) {
      setIsLoading(true);
    }

    setError(null);

    try {
      if (!ensureAdminSession(locale, router)) {
        return;
      }

      const response = await fetchAdminTemplateCategories(true);
      setCategories(response);
    } catch {
      const message = text.errorLoadingTemplates;
      setError(message);
      setToast({ type: "error", message });
    } finally {
      if (showLoading) {
        setIsLoading(false);
      }
    }
  }, [locale, router, text.errorLoadingTemplates]);

  useEffect(() => {
    let isCancelled = false;

    async function initialize() {
      try {
        await loadCategories(true);
      } catch {
        if (!isCancelled) {
          setError(text.errorLoadingTemplates);
        }
      }
    }

    void initialize();

    return () => {
      isCancelled = true;
    };
  }, [loadCategories, text.errorLoadingTemplates]);

  const visibleCategories = useMemo(
    () => categories.filter((category) => archiveFilter === "archived" ? category.isArchived : !category.isArchived),
    [archiveFilter, categories],
  );

  const stats = useMemo(() => ({
    totalCategories: categories.length,
    activeCategories: categories.filter((category) => !category.isArchived).length,
    archivedCategories: categories.filter((category) => category.isArchived).length,
    totalTemplates: categories.reduce((sum, category) => sum + category.totalTemplates, 0),
    totalPremium: categories.reduce((sum, category) => sum + category.premiumTemplates, 0),
  }), [categories]);

  async function handleCreateCategory(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const name = newCategoryName.trim();
    if (!name) {
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      await createTemplateCategory({ name });
      setNewCategoryName("");
      await loadCategories(false);
      setToast({ type: "success", message: isRu ? "Категория создана." : "Category created." });
    } catch (actionError) {
      const message = getActionErrorMessage(actionError, isRu ? "Не удалось создать категорию." : "Could not create category.");
      setError(message);
      setToast({ type: "error", message });
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleUpdateCategory(categoryId: string) {
    const name = editingName.trim();
    if (!name) {
      return;
    }

    setBusyCategoryId(categoryId);
    setError(null);

    try {
      await updateTemplateCategory(categoryId, { name });
      setEditingCategoryId(null);
      setEditingName("");
      await loadCategories(false);
      setToast({ type: "success", message: isRu ? "Категория обновлена." : "Category updated." });
    } catch (actionError) {
      const message = getActionErrorMessage(actionError, isRu ? "Не удалось обновить категорию." : "Could not update category.");
      setError(message);
      setToast({ type: "error", message });
    } finally {
      setBusyCategoryId(null);
    }
  }

  async function handleArchiveToggle(category: AdminTemplateCategory) {
    setBusyCategoryId(category.categoryId);
    setError(null);

    try {
      await changeTemplateCategoryArchiveState(category.categoryId, !category.isArchived);
      if (editingCategoryId === category.categoryId) {
        setEditingCategoryId(null);
        setEditingName("");
      }
      await loadCategories(false);
      setToast({
        type: "success",
        message: category.isArchived
          ? (isRu ? "Категория возвращена из архива." : "Category restored from archive.")
          : (isRu ? "Категория отправлена в архив." : "Category archived."),
      });
    } catch (actionError) {
      const message = getActionErrorMessage(actionError, isRu ? "Не удалось изменить состояние категории." : "Could not change category state.");
      setError(message);
      setToast({ type: "error", message });
    } finally {
      setBusyCategoryId(null);
    }
  }

  async function handleDeleteCategory(category: AdminTemplateCategory) {
    const confirmed = window.confirm(
      isRu
        ? `Удалить категорию "${category.name}"? Категория удаляется только если в ней нет шаблонов.`
        : `Delete category "${category.name}"? It can only be removed when no templates reference it.`
    );

    if (!confirmed) {
      return;
    }

    setBusyCategoryId(category.categoryId);
    setError(null);

    try {
      await deleteTemplateCategory(category.categoryId);
      if (editingCategoryId === category.categoryId) {
        setEditingCategoryId(null);
        setEditingName("");
      }
      await loadCategories(false);
      setToast({ type: "success", message: isRu ? "Категория удалена." : "Category deleted." });
    } catch (actionError) {
      const message = getActionErrorMessage(actionError, isRu ? "Не удалось удалить категорию." : "Could not delete category.");
      setError(message);
      setToast({ type: "error", message });
    } finally {
      setBusyCategoryId(null);
    }
  }

  if (isLoading) {
    return (
      <AdminPage className={styles.catalogPage}>
      <AdminPageGrid columns="four" className={styles.loadingGrid} aria-busy="true" aria-live="polite">
        {Array.from({ length: 6 }).map((_, index) => <div key={index} className={styles.skeletonCard} />)}
      </AdminPageGrid>
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.catalogPage}>
      <AdminPageHero
        eyebrow={isRu ? "Структура каталога" : "Template taxonomy"}
        title={isRu ? "Категории шаблонов" : "Template Categories"}
        description={isRu ? "Управляйте списком категорий, архивом и переименованием. Переименование категории автоматически обновляет связанные шаблоны." : "Manage the category registry, archive state, and rename flows. Renaming a category updates linked templates automatically."}
        badge={isRu ? "CRUD подключен" : "CRUD enabled"}
        actions={(
          <div className={styles.catalogActions}>
            <button type="button" className={archiveFilter === "active" ? styles.tabActive : styles.tab} onClick={() => setArchiveFilter("active")}>
              {isRu ? "Активные" : "Active"}
            </button>
            <button type="button" className={archiveFilter === "archived" ? styles.tabActive : styles.tab} onClick={() => setArchiveFilter("archived")}>
              {isRu ? "Архив" : "Archive"}
            </button>
          </div>
        )}
        metaItems={[
          `${isRu ? "Категорий" : "Categories"}: ${stats.totalCategories}`,
          `${isRu ? "Шаблонов" : "Templates"}: ${stats.totalTemplates}`,
          `${text.premiumLabel}: ${stats.totalPremium}`,
        ]}
      />

      {error ? <AdminStateCard tone="danger" className={styles.error} title={error} /> : null}

      <AdminPageGrid columns="four" className={styles.categoryStatsGrid}>
        <AdminKpiCard tone="primary" label={isRu ? "Всего категорий" : "Total categories"} value={stats.totalCategories} hint={isRu ? "Категории в реестре" : "Categories in the registry"} />
        <AdminKpiCard tone="success" label={isRu ? "Активные категории" : "Active categories"} value={stats.activeCategories} hint={isRu ? "Доступны для новых шаблонов" : "Available for new templates"} />
        <AdminKpiCard tone="warning" label={isRu ? "Архив" : "Archive"} value={stats.archivedCategories} hint={isRu ? "Скрыты для новых шаблонов" : "Hidden from new template assignment"} />
        <AdminKpiCard tone="info" label={isRu ? "Всего шаблонов" : "Total templates"} value={stats.totalTemplates} hint={isRu ? "Видео и изображения вместе" : "Video and image combined"} />
      </AdminPageGrid>

      <AdminCard title={isRu ? "Новая категория" : "New category"} description={isRu ? "Сначала создайте категорию здесь, затем она появится в редакторах шаблонов." : "Create categories here first so they become available in template editors."}>
        <form className={styles.categoryToolbar} onSubmit={handleCreateCategory}>
          <label className={styles.categoryField}>
            <span>{text.categoryLabel}</span>
            <input
              className={styles.categoryInput}
              value={newCategoryName}
              onChange={(event) => setNewCategoryName(event.target.value)}
              placeholder={isRu ? "Например, Portrait Pets" : "For example, Portrait Pets"}
              maxLength={64}
            />
          </label>
          <Button type="submit" variant="primary" disabled={isSubmitting || !newCategoryName.trim()}>
            {isRu ? "Добавить категорию" : "Add category"}
          </Button>
        </form>
      </AdminCard>

      <AdminCard title={isRu ? "Категории" : "Categories"} description={archiveFilter === "archived" ? (isRu ? "Архивные категории остаются в статистике и в связанных шаблонах, но не предлагаются для новых шаблонов." : "Archived categories stay in stats and linked templates, but are not suggested for new templates.") : (isRu ? "Переименование категории синхронно обновляет поле category у связанных шаблонов." : "Renaming a category synchronously updates the category field on linked templates.")}>
        {!visibleCategories.length ? (
          <AdminStateCard tone="info" className={styles.empty} title={isRu ? "Категории не найдены." : "No categories found."} />
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
                      {editingCategoryId === category.categoryId ? (
                        <input
                          className={styles.categoryInput}
                          value={editingName}
                          onChange={(event) => setEditingName(event.target.value)}
                          maxLength={64}
                          disabled={busyCategoryId === category.categoryId}
                        />
                      ) : (
                        <div className={styles.titleCell}>
                          <strong>{category.name}</strong>
                          <span>{category.tags.slice(0, 4).map((tag) => `#${tag}`).join(" ") || "-"}</span>
                        </div>
                      )}
                    </td>
                    <td data-label={isRu ? "Состояние" : "State"}>
                      <AdminStatusBadge color={category.isArchived ? typeColors.Archived : typeColors.Video}>
                        {category.isArchived ? (isRu ? "Архив" : "Archived") : (isRu ? "Активна" : "Active")}
                      </AdminStatusBadge>
                    </td>
                    <td data-label={isRu ? "Всего" : "Total"}>{category.totalTemplates}</td>
                    <td data-label={text.templateKindVideoBadge}><AdminStatusBadge color={typeColors.Video}>{category.videoTemplates}</AdminStatusBadge></td>
                    <td data-label={text.templateKindImageBadge}><AdminStatusBadge color={typeColors.Image}>{category.imageTemplates}</AdminStatusBadge></td>
                    <td data-label={text.statusLabel}>{category.activeTemplates} / {category.draftTemplates} / {category.archivedTemplates}</td>
                    <td data-label={text.premiumLabel}>{category.premiumTemplates}</td>
                    <td data-label={text.actionsLabel}>
                      <div className={styles.tableActions}>
                        {editingCategoryId === category.categoryId ? (
                          <>
                            <Button type="button" size="sm" variant="primary" disabled={busyCategoryId === category.categoryId || !editingName.trim()} onClick={() => void handleUpdateCategory(category.categoryId)}>
                              {isRu ? "Сохранить" : "Save"}
                            </Button>
                            <Button type="button" size="sm" variant="ghost" disabled={busyCategoryId === category.categoryId} onClick={() => {
                              setEditingCategoryId(null);
                              setEditingName("");
                            }}>
                              {isRu ? "Отмена" : "Cancel"}
                            </Button>
                          </>
                        ) : (
                          <>
                            <Link className={styles.compactLink} href={`/${locale}/templates/video?category=${encodeURIComponent(category.name)}`}>
                              <VideoIcon className={styles.linkIcon} />
                              <span>{text.templateKindVideoBadge}</span>
                            </Link>
                            <Link className={styles.compactLink} href={`/${locale}/templates/image?category=${encodeURIComponent(category.name)}`}>
                              <ImageIcon className={styles.linkIcon} />
                              <span>{text.templateKindImageBadge}</span>
                            </Link>
                            <Button type="button" size="sm" variant="ghost" disabled={busyCategoryId === category.categoryId} onClick={() => {
                              setEditingCategoryId(category.categoryId);
                              setEditingName(category.name);
                            }}>
                              {text.editTemplate}
                            </Button>
                            <Button type="button" size="sm" variant="secondary" disabled={busyCategoryId === category.categoryId} onClick={() => void handleArchiveToggle(category)}>
                              {category.isArchived ? (isRu ? "Вернуть" : "Restore") : text.archive}
                            </Button>
                            <Button type="button" size="sm" variant="danger" disabled={busyCategoryId === category.categoryId || category.totalTemplates > 0} onClick={() => void handleDeleteCategory(category)}>
                              {text.deleteTemplate}
                            </Button>
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

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </AdminPage>
  );
}

function getActionErrorMessage(error: unknown, fallback: string): string {
  if (error && typeof error === "object" && "validationErrors" in error) {
    const validationErrors = (error as { validationErrors?: string[] }).validationErrors ?? [];
    if (validationErrors.length > 0) {
      return validationErrors.join(" ");
    }
  }

  if (error instanceof Error && error.message && !/^API request failed with status \d+$/i.test(error.message)) {
    return error.message;
  }

  return fallback;
}
