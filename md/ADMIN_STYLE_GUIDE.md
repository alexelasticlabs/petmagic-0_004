# PetMagic Admin Style Guide

Этот файл фиксирует текущий стиль админ-панели и порядок добавления новых разделов. Цель - сохранять единый темный операционный интерфейс без возврата к старым глобальным стилям.

## Visual Language

- Основной фон: почти черный `#090d16` с мягким зеленым акцентом `#22c55e`.
- Surface-карточки: темные панели с border `#1a2738`, легким gradient и без декоративных внешних карточек внутри карточек.
- Typography: `Inter` для интерфейса, `Manrope` для заголовков и крупных чисел; обе гарнитуры должны уверенно работать с русским и английским языком.
- Радиусы: компактные, обычно `0.85rem` для controls и `1.05rem` для cards.
- Сетки: стабильные `grid-template-columns: minmax(0, 1fr)` и явные responsive breakpoints.
- Текст в компактных панелях должен быть коротким, сканируемым и не hero-size.

## Styling Ownership

- `src/app/globals.css` держит только reset/base, `.ui-button`, `.ui-toast`, login screen `ls-*` и login language dropdown `lld-*`.
- Authenticated admin layout живет в `src/components/admin/admin-shell.module.css`.
- Shared cards, stats, badges and tables живут в `src/components/admin/admin-primitives.module.css`.
- Feature-specific spacing, forms and action rows живут рядом с feature в CSS Module.
- Не добавляйте новые admin selectors в `globals.css`. Если стиль нужен нескольким features, вынесите его в admin primitive.

## Reusable Building Blocks

- `AdminShell` - общий locale-aware layout, auth redirect, sidebar/topbar wrapper.
- `AdminSidebar` - навигация и logout.
- `AdminTopbar` - title, description, locale switch, user badge.
- `AdminCard` - базовая панель с title/description/action.
- `AdminStatCard` - метрика с accent color and icon.
- `AdminStatusBadge` - status pill через CSS custom property `--status-color`.
- `adminTableStyles` - shared table wrapper, table, mono and numeric classes.
- `TemplatesCatalogView` - overview-экран шаблонов с фильтрами, Cards/List toggle и right rail.
- `TemplatesCategoriesView` - read-only сводка категорий на основе существующих шаблонов.
- `TemplatesManager` - editor flow для создания и редактирования image/video templates.
- `Button` - базовый reusable button через `.ui-button`; feature modules могут добавлять scoped modifier class.
- `Toast` - глобальный floating feedback.

## Adding A New Tab

1. Создайте route: `src/app/[locale]/<slug>/page.tsx`.
2. Создайте feature view: `src/components/<feature>-view.tsx`.
3. Если компонент использует hooks/browser APIs, добавьте `"use client"` только в этот feature view, не в route page.
4. Создайте CSS Module рядом с feature: `src/components/<feature>-view.module.css`.
5. Добавьте ключ в `AdminSectionKey` и item в `getAdminNavItems` внутри `src/lib/admin-navigation.ts`.
6. Добавьте title/description для route в `getAdminPageMeta`.
7. Добавьте nav label в `src/lib/i18n.ts` для `ru` и `en`.
8. Добавьте icon в `src/components/admin/admin-icons.tsx` и подключите его в `iconMap` внутри `AdminSidebar`.
9. Все данные получайте через `src/lib/api-client.ts`; Admin UI не ходит в БД напрямую.
10. Добавьте loading, empty, error и success feedback states.
11. Проверьте `npm run lint` и `npm run build`.

## Templates Route Family

- Главный grouped-раздел в sidebar: `Шаблоны`.
- Overview routes:
  - `src/app/[locale]/templates/video/page.tsx`
  - `src/app/[locale]/templates/image/page.tsx`
  - `src/app/[locale]/templates/categories/page.tsx`
- Editor routes:
  - `src/app/[locale]/templates/video/editor/page.tsx`
  - `src/app/[locale]/templates/image/editor/page.tsx`
- Старые routes `src/app/[locale]/video-templates/page.tsx` и `src/app/[locale]/image-templates/page.tsx` остаются только compatibility redirects.
- `Categories` сейчас read-only: данные агрегируются из `AdminTemplateListItem.category`. Для CRUD категорий нужен отдельный backend endpoint и отдельная архитектурная волна.
- В overview-страницах обязательно сохраняйте переключатель `Cards/List`, фильтры, loading/empty/error states и editor action через `.../editor?templateId=<id>`.

Route page skeleton:

```tsx
import { FeatureView } from "@/components/feature-view";
import { type Locale, isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type Props = { params: Promise<{ locale: string }> };

export default async function FeaturePage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <FeatureView locale={locale as Locale} />;
}
```

## Adding A Card, Table Or Form

- Начинайте с `AdminCard`; action кладите в `action`, а не в произвольный header.
- Для таблиц используйте `adminTableStyles.tableWrap` и `adminTableStyles.table`.
- Status values показывайте через `AdminStatusBadge`, не через plain text.
- Для repeated metrics используйте `AdminStatCard`.
- Формы держите в feature CSS Module: `.formGrid`, `.split`, `.actions`, scoped button modifiers.
- Error/empty/loading states должны занимать предсказуемую высоту и не ломать grid.

## CSS Rules

- Не возвращайте старые глобальные классы: `screen-bg`, `shell-*`, `nav-*`, `form-grid`, `table-wrap`, `row-actions`, `templates-*`, `ap-*`.
- Не кладите feature styles в `globals.css`.
- Не создавайте nested cards внутри cards.
- Не используйте inline styles, кроме CSS custom properties для динамического цвета badge/stat/icon.
- Не добавляйте `!important`, если проблему можно решить ownership-ом CSS Module или shared primitive.
- Mobile breakpoints должны сохранять доступность actions: кнопки не должны обрезаться или перекрывать таблицу.

## Copy And Localization

- User-facing labels идут через `src/lib/i18n.ts`.
- Route/page metadata живет в `getAdminPageMeta`.
- Навигационные labels не хардкодятся в sidebar/topbar; они приходят из `getAdminNavItems`.
- RU-интерфейс не должен смешивать английские labels, кроме product/API терминов вроде `Premium`, `Kling` или URL.

## Validation Checklist

- `npm run lint`
- `npm run build`
- Проверить desktop и mobile layouts для новой вкладки.
- Проверить unauthenticated redirect через `AdminShell`.
- Проверить loading, empty, error and success states.
- Для templates проверить `/templates/video`, `/templates/image`, `/templates/categories`, editor routes и redirects со старых `/video-templates`, `/image-templates`.
