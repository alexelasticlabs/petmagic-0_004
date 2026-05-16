"use client";

import { AdminCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import styles from "@/components/templates/templates-catalog.module.css";
import { fetchAdminTemplates, getSession, type AdminTemplateListItem } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useEffectEvent, useState } from "react";

type TemplatesCategoriesViewProps = {
  locale: Locale;
};

const typeColors = {
  Video: "#22c55e",
  Image: "#38bdf8",
};

export function TemplatesCategoriesView({ locale }: TemplatesCategoriesViewProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const [templates, setTemplates] = useState<AdminTemplateListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const isRu = locale === "ru";

  async function loadTemplates() {
    setIsLoading(true);
    setError(null);

    try {
      const session = getSession();
      if (!session) {
        router.replace(`/${locale}`);
        return;
      }

      setTemplates(await fetchAdminTemplates());
    } catch {
      setError(text.errorLoadingTemplates);
    } finally {
      setIsLoading(false);
    }
  }

  const loadTemplatesOnMount = useEffectEvent(loadTemplates);

  useEffect(() => {
    queueMicrotask(() => {
      void loadTemplatesOnMount();
    });
  }, []);

  const categories = getCategoryRows(templates);
  const totalActive = templates.filter((template) => template.status === "Active").length;
  const totalPremium = templates.filter((template) => template.isPremium).length;

  if (isLoading) {
    return (
      <section className={styles.loadingGrid} aria-busy="true" aria-live="polite">
        {Array.from({ length: 6 }).map((_, index) => <div key={index} className={styles.skeletonCard} />)}
      </section>
    );
  }

  return (
    <section className={styles.catalogPage}>
      <div className={styles.catalogHero}>
        <div className={styles.heroIcon} aria-hidden="true">#</div>
        <div className={styles.heroCopy}>
          <h1>{isRu ? "Категории шаблонов" : "Template Categories"}</h1>
          <p>{isRu ? "Read-only сводка по категориям на основе существующих image и video шаблонов." : "Read-only category overview based on existing image and video templates."}</p>
        </div>
      </div>

      {error ? <p className={styles.error}>{error}</p> : null}

      <div className={styles.categoryStatsGrid}>
        <AdminCard title={isRu ? "Всего категорий" : "Total categories"} description={isRu ? "Уникальные значения category" : "Unique category values"}>
          <p className={styles.bigMetric}>{categories.length}</p>
        </AdminCard>
        <AdminCard title={isRu ? "Всего шаблонов" : "Total templates"} description={isRu ? "Video и image вместе" : "Video and image combined"}>
          <p className={styles.bigMetric}>{templates.length}</p>
        </AdminCard>
        <AdminCard title={isRu ? "Активных" : "Active"} description={isRu ? "Готовы к каталогу" : "Ready for catalog"}>
          <p className={styles.bigMetric}>{totalActive}</p>
        </AdminCard>
        <AdminCard title="Premium" description={isRu ? "Монетизируемые шаблоны" : "Monetized templates"}>
          <p className={styles.bigMetric}>{totalPremium}</p>
        </AdminCard>
      </div>

      <AdminCard title={isRu ? "Категории" : "Categories"} description={isRu ? "Для CRUD категорий нужен отдельный backend endpoint; сейчас экран использует существующее поле category." : "Category CRUD needs a dedicated backend endpoint; this screen uses the existing category field."}>
        {!categories.length ? (
          <div className={styles.empty}>{isRu ? "Категории не найдены." : "No categories found."}</div>
        ) : (
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.categoryLabel}</th>
                  <th>{isRu ? "Всего" : "Total"}</th>
                  <th>Video</th>
                  <th>Image</th>
                  <th>{text.statusLabel}</th>
                  <th>Premium</th>
                  <th>{text.actionsLabel}</th>
                </tr>
              </thead>
              <tbody>
                {categories.map((category) => (
                  <tr key={category.name}>
                    <td data-label={text.categoryLabel}>
                      <div className={styles.titleCell}>
                        <strong>{category.name}</strong>
                        <span>{category.tags.slice(0, 4).map((tag) => `#${tag}`).join(" ") || "-"}</span>
                      </div>
                    </td>
                    <td data-label={isRu ? "Всего" : "Total"}>{category.total}</td>
                    <td data-label="Video"><AdminStatusBadge color={typeColors.Video}>{category.video}</AdminStatusBadge></td>
                    <td data-label="Image"><AdminStatusBadge color={typeColors.Image}>{category.image}</AdminStatusBadge></td>
                    <td data-label={text.statusLabel}>{category.active} / {category.draft} / {category.archived}</td>
                    <td data-label="Premium">{category.premium}</td>
                    <td data-label={text.actionsLabel}>
                      <div className={styles.tableActions}>
                        <Link className={styles.compactLink} href={`/${locale}/templates/video?category=${encodeURIComponent(category.name)}`}>Video</Link>
                        <Link className={styles.compactLink} href={`/${locale}/templates/image?category=${encodeURIComponent(category.name)}`}>Image</Link>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </AdminCard>
    </section>
  );
}

function getCategoryRows(templates: AdminTemplateListItem[]) {
  const rows = new Map<string, {
    name: string;
    total: number;
    video: number;
    image: number;
    active: number;
    draft: number;
    archived: number;
    premium: number;
    tags: string[];
  }>();

  for (const template of templates) {
    const row = rows.get(template.category) ?? {
      name: template.category,
      total: 0,
      video: 0,
      image: 0,
      active: 0,
      draft: 0,
      archived: 0,
      premium: 0,
      tags: [],
    };

    row.total += 1;
    row.video += template.templateType === "Video" ? 1 : 0;
    row.image += template.templateType === "Image" ? 1 : 0;
    row.active += template.status === "Active" ? 1 : 0;
    row.draft += template.status === "Draft" ? 1 : 0;
    row.archived += template.status === "Archived" ? 1 : 0;
    row.premium += template.isPremium ? 1 : 0;
    row.tags = Array.from(new Set([...row.tags, ...template.tags])).sort();
    rows.set(template.category, row);
  }

  return Array.from(rows.values()).sort((firstRow, secondRow) => secondRow.total - firstRow.total);
}
