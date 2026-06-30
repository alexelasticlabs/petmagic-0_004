# Статус реализации PetMagic

Актуально на 16.05.2026.

## Что уже готово

### Архитектура и стек

- Проект развивается как Modular Monolith with Vertical Slices.
- Backend построен на ASP.NET Core Minimal API и .NET 10.
- Данные хранятся через EF Core 10 и PostgreSQL.
- Модули разделены на слои Api, Application, Domain, Infrastructure.

### Identity и аутентификация

- Реализован login.
- Реализован refresh token flow.
- Реализован logout.
- Настроены роли пользователей.
- Админ-панель рассчитана только на вход Admin и Moderator.
- Регистрация в admin web не предусмотрена.

### Admin Web

- Есть экран входа в админ-панель.
- Есть локализация ru/en.
- Есть страница пользователей.
- Есть управление ролями пользователей.
- Есть управление признаками Premium и Active.
- Есть client-side работа с access token и refresh token.
- Есть автоматическое обновление сессии при 401 через refresh.

### Economy module

- Реализован кошелек пользователя.
- Реализована выдача еженедельной награды.
- Реализована награда за просмотр рекламы с дневным лимитом.
- Реализовано списание внутренней валюты.
- Реализован список валютных паков.
- Реализовано создание заказа на покупку пака.
- Реализовано подтверждение покупки.
- Реализовано получение заказа по id.
- Реализана обработка Stripe webhook.
- Реализована идемпотентность webhook-событий.
- Реализовано начисление валюты после успешной покупки.

### Stripe интеграция

- Подключен Stripe SDK.
- Реализовано создание Checkout Session.
- Передаются metadata и idempotency key.
- Настроена проверка подписи webhook.
- Добавлен fallback-путь верификации и разбора payload для устойчивой обработки.

### Persistence и инфраструктура

- Добавлен EconomyDbContext.
- Настроены сущности кошелька, ledger, паков, заказов и обработанных webhook-событий.
- Добавлены миграции для покупок и webhook events.
- Добавлен seed активных currency packs.
- Модуль Economy подключен в host.
- Настроены appsettings для economy и Stripe.

## API, которое уже есть

### Auth

- POST /api/auth/login
- POST /api/auth/refresh
- POST /api/auth/logout

### Economy

- GET /api/economy/wallet
- POST /api/economy/wallet/claim-weekly
- POST /api/economy/wallet/claim-ad
- POST /api/economy/wallet/spend
- GET /api/economy/packs
- POST /api/economy/purchases/create
- POST /api/economy/purchases/{orderId}/confirm
- GET /api/economy/purchases/{orderId}
- POST /api/economy/webhooks/stripe

## Что подтверждено

- Backend успешно собирается.
- Backend тесты проходят: 16 из 16.
- Исправлен и стабилизирован EconomyService.
- Исправлена обработка Stripe webhook idempotency.

## Что стоит считать следующим этапом

- Подключить реальный мобильный клиент Flutter к готовым auth/economy endpoint.
- Пройти end-to-end проверку Stripe через настоящий webhook из Stripe CLI или sandbox.
- Добавить отдельные e2e/integration тесты для purchase flow.
- При необходимости расширить admin web дополнительной аналитикой и фильтрами.
