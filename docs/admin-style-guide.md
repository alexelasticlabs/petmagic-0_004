# PetMagic Admin Style Guide

Этот файл фиксирует текущий стиль админ-панели и порядок добавления новых разделов. Цель - сохранять единый операционный интерфейс в dark/light themes без возврата к старым глобальным стилям.

## Visual Language

- Основное действие и focus: blue tokens `--primary-bg` / `--accent` (`#1a73e8` / `#8ab4f8` в dark theme, `#2563eb` в light theme).
- Success и подтвержденное состояние: green token `--success` (`#81c995` в dark theme, `#16a34a` в light theme). Green не заменяет primary action.
- Surface-слои берутся из `--surface-0` ... `--surface-4`; не добавляйте локальные hex-цвета и декоративные внешние карточки внутри карточек.
- Typography: `Inter` через `--font-body`, `Manrope` через `--font-heading`, идентификаторы и числовые ключи через `--font-mono`. Runtime stacks содержат системные fallback fonts для offline/container среды.
- Радиусы: компактные runtime tokens `--radius-xs: 4px`, `--radius-sm: 8px`, `--radius: 10px`, `--radius-lg: 14px`.
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
- `AdminTopbar` - title, description, global command search, notifications, theme, locale switch, user badge.
- `AdminCommandPalette` - RBAC-aware быстрый переход по доступным разделам через `Ctrl/Cmd+K`.
- `AdminCard` - базовая панель с title/description/action.
- `AdminStatCard` - метрика с accent color and icon.
- `AdminStatusBadge` - status pill через CSS custom property `--status-color`.
- `AdminQueueLayout` - flat queue/workspace/inspector composition без nested cards.
- `AdminInspector` и `AdminDetailsDrawer` - единый desktop/mobile details flow с focus trap, `Escape` и focus restore.
- `AdminEntityLink` - единое отображение связанных сущностей и технического secondary label.
- `AdminActionMenu` - keyboard-accessible меню контекстных действий.
- `AdminSelectionTray` - bulk-selection summary и actions без скрытия eligibility ограничений.
- `AdminPagination` - компактная pagination с `aria-current` и localized labels.
- `AdminUrlState` - canonical URL contract для filters, sort, page, selected entity и active tab.
- `adminTableStyles` - shared table wrapper, table, mono and numeric classes.
- `TemplatesCatalogView` - overview-экран шаблонов с фильтрами, Cards/List toggle и right rail.
- `TemplatesCategoriesView` - Admin CRUD и Moderator read-only сводка категорий.
- `UsersBulkEmailDialog` - двухэтапная постановка email-рассылки в backend queue с явной проверкой аудитории.
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

## Navigation Information Architecture

Sidebar использует шесть стабильных рабочих областей без изменения route keys, RBAC или deep links:

1. `Command Center` - dashboard и оперативная сводка.
2. `Customers & Access` - пользователи и роли.
3. `Operations Desk` - генерации, feedback, support, moderation и audit.
4. `Content Studio` - templates и вложенные catalog routes.
5. `Revenue & Risk` - economy, платежные и risk workflows.
6. `Growth & Rewards` - promo codes и gamification.

Названия областей локализуются централизованно в `src/lib/admin-navigation-areas.ts`; route entries продолжают приходить из `getAdminNavItems`, поэтому RBAC-фильтрация и существующие URL остаются источником истины.

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
- `Categories` используют отдельный admin backend contract: Admin может создавать, переименовывать, архивировать, восстанавливать и удалять пустые категории; Moderator работает в read-only режиме.
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

## Sensitive Actions

- Массовые и необратимые действия не выполняются одним кликом: сначала сбор параметров, затем отдельный review/confirmation step.
- UI должен показывать реальную аудиторию, ограничения полей и backend queue/audit semantics без обещания мгновенной отправки.
- Выбор получателей учитывает backend eligibility; недоступные строки остаются видимыми, но selection control отключается с пояснением.
- Не изображайте статический период, badge или label как dropdown, если backend не поддерживает смену значения.

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
