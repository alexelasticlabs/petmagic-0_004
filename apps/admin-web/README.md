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

## Configuration

При запуске через корневой Docker Compose источник переменных — root `.env`,
созданный из `../../.env.example`; не создавайте второй admin `.env`.

При самостоятельном запуске этого приложения используйте только один шаблон по
назначению: `.env.development.example`, `.env.staging.example` или
`.env.production.example`. Production runtime configuration is owned by the
VPS runbook and its root-only environment file; see
[`../../deploy/vps/README.md`](../../deploy/vps/README.md). Real secrets never
belong in an admin-web environment template committed to Git.

## Structure

- `src/app/[locale]` - локализованные routes и общий `AdminShell` layout.
- `src/components/admin` - shell, sidebar, topbar, icons и reusable admin primitives.
- `src/components/templates` - catalog, categories и editor-компоненты для image/video templates.
- `src/lib/api-client*.ts` - доменные HTTP API-клиенты и типы для backend; прямой DB-доступ запрещён guard-тестом.
- `src/lib/admin-navigation.ts` - nav items, active matching, locale path switching и page meta.
- `src/lib/i18n.ts` - RU/EN словари интерфейса.

## UI Rules

См. [../../docs/admin-style-guide.md](../../docs/admin-style-guide.md) перед добавлением новых вкладок, таблиц, карточек, форм или глобальных стилей.
Правила локализации и light/dark theme зафиксированы в
[../../docs/localization-and-theme.md](../../docs/localization-and-theme.md).
Новый пользовательский текст добавляйте через typed dictionaries в
`src/lib/i18n.*.ts`, а цвета - через существующие CSS tokens/theme helpers.

## Validation

Перед завершением frontend-изменений запускайте:

```bash
npm run lint
npm run typecheck
npm run test
npm run build
```
