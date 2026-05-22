# PetMagic Admin Web

Next.js админ-панель для управления пользователями, ролями, Premium-статусом и шаблонами каталога PetMagic.

## Stack

- Next.js 16 App Router
- React 19.2
- TypeScript
- CSS Modules для admin-интерфейса
- Глобальные стили только для reset, `ui-*`, toast и login screen

## Scripts

```bash
npm install
npm run dev
npm run lint
npm run typecheck
npm run test
npm run build
```

По умолчанию dev server открывается на `http://localhost:3000`.

## Structure

- `src/app/[locale]` - локализованные routes и общий `AdminShell` layout.
- `src/components/admin` - shell, sidebar, topbar, icons и reusable admin primitives.
- `src/components/templates` - catalog, categories и editor-компоненты для image/video templates.
- `src/lib/api-client.ts` - единственный frontend API-клиент к backend.
- `src/lib/admin-navigation.ts` - nav items, active matching, locale path switching и page meta.
- `src/lib/i18n.ts` - RU/EN словари интерфейса.

## UI Rules

См. [../../md/ADMIN_STYLE_GUIDE.md](../../md/ADMIN_STYLE_GUIDE.md) перед добавлением новых вкладок, таблиц, карточек, форм или глобальных стилей.

## Validation

Перед завершением frontend-изменений запускайте:

```bash
npm run lint
npm run typecheck
npm run test
npm run build
```
