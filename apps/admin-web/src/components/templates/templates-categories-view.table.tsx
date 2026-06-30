"use client";

import Link from "next/link";

import { ImageIcon, VideoIcon } from "@/components/admin/admin-icons";
import {
  AdminCard,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import styles from "@/components/templates/templates-catalog.module.css";
import { Button } from "@/components/ui/button";
import type { AdminTemplateCategory } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import type { TemplatesCategoriesViewText } from "./templates-categories-view.content";

export const typeColors = {
  Video: "var(--success)",
  Image: "var(--info)",
  Archived: "var(--text-muted)",
};

type TemplatesCategoriesTableProps = {
  locale: Locale;
  canManageCategories: boolean;
  visibleCategories: AdminTemplateCategory[];
  description: string;
  editingCategoryId: string | null;
  editingName: string;
  isCategoryActionLocked: boolean;
  categoryText: TemplatesCategoriesViewText;
  categoryNameLabel: string;
  videoBadgeLabel: string;
  imageBadgeLabel: string;
  statusLabel: string;
  premiumLabel: string;
  actionsLabel: string;
  editTemplateLabel: string;
  archiveLabel: string;
  deleteTemplateLabel: string;
  formatCategoryActionName: (category: AdminTemplateCategory | null) => string;
  onEditingNameChange: (value: string) => void;
  onStartEdit: (category: AdminTemplateCategory) => void;
  onSaveEdit: (categoryId: string) => void;
  onCancelEdit: () => void;
  onArchiveToggle: (category: AdminTemplateCategory) => void;
  onDeleteCategory: (category: AdminTemplateCategory) => void;
  categoryNameMaxLength: number;
};

export function TemplatesCategoriesTable({
  locale,
  canManageCategories,
  visibleCategories,
  description,
  editingCategoryId,
  editingName,
  isCategoryActionLocked,
  categoryText,
  categoryNameLabel,
  videoBadgeLabel,
  imageBadgeLabel,
  statusLabel,
  premiumLabel,
  actionsLabel,
  editTemplateLabel,
  archiveLabel,
  deleteTemplateLabel,
  formatCategoryActionName,
  onEditingNameChange,
  onStartEdit,
  onSaveEdit,
  onCancelEdit,
  onArchiveToggle,
  onDeleteCategory,
  categoryNameMaxLength,
}: TemplatesCategoriesTableProps) {
  const text = getDictionary(locale);

  return (
    <AdminCard title={categoryText.categoriesTitle} description={description}>
      {!visibleCategories.length ? (
        <AdminStateCard tone="info" className={styles.empty} title={categoryText.empty} />
      ) : (
        <div
          className={adminTableStyles.tableWrap}
          aria-busy={isCategoryActionLocked ? "true" : undefined}
        >
          <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{categoryNameLabel}</th>
                <th>{categoryText.state}</th>
                <th>{categoryText.total}</th>
                <th>{videoBadgeLabel}</th>
                <th>{imageBadgeLabel}</th>
                <th>{statusLabel}</th>
                <th>{premiumLabel}</th>
                <th>{actionsLabel}</th>
              </tr>
            </thead>
            <tbody>
              {visibleCategories.map((category) => (
                <tr key={category.categoryId}>
                  <td data-label={categoryNameLabel}>
                    {canManageCategories && editingCategoryId === category.categoryId ? (
                      <input
                        className={styles.categoryInput}
                        value={editingName}
                        onChange={(event) => onEditingNameChange(event.target.value)}
                        maxLength={categoryNameMaxLength}
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
                  <td data-label={videoBadgeLabel}>
                    <AdminStatusBadge color={typeColors.Video}>
                      {category.videoTemplates}
                    </AdminStatusBadge>
                  </td>
                  <td data-label={imageBadgeLabel}>
                    <AdminStatusBadge color={typeColors.Image}>
                      {category.imageTemplates}
                    </AdminStatusBadge>
                  </td>
                  <td data-label={statusLabel}>
                    {category.activeTemplates} / {category.draftTemplates} /{" "}
                    {category.archivedTemplates}
                  </td>
                  <td data-label={premiumLabel}>{category.premiumTemplates}</td>
                  <td data-label={actionsLabel}>
                    <div className={`${styles.tableActions} ${styles.categoryTableActions}`}>
                      {canManageCategories && editingCategoryId === category.categoryId ? (
                        <>
                          <Button
                            type="button"
                            size="sm"
                            variant="primary"
                            disabled={isCategoryActionLocked || !editingName.trim()}
                            onClick={() => onSaveEdit(category.categoryId)}
                          >
                            {categoryText.save}
                          </Button>
                          <Button
                            type="button"
                            size="sm"
                            variant="ghost"
                            disabled={isCategoryActionLocked}
                            onClick={onCancelEdit}
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
                                onClick={() => onStartEdit(category)}
                              >
                                {editTemplateLabel}
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
                                onClick={() => onArchiveToggle(category)}
                              >
                                {category.isArchived ? categoryText.restore : archiveLabel}
                              </Button>
                              <Button
                                type="button"
                                size="sm"
                                variant="danger"
                                disabled={isCategoryActionLocked || category.totalTemplates > 0}
                                aria-label={categoryText.deleteCategoryLabel(
                                  formatCategoryActionName(category)
                                )}
                                title={categoryText.deleteCategoryLabel(
                                  formatCategoryActionName(category)
                                )}
                                onClick={() => onDeleteCategory(category)}
                              >
                                {deleteTemplateLabel}
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
  );
}
