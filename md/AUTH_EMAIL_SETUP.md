# Полная настройка Google входа и email для PetMagic

Ниже инструкция без пропусков: что создать, куда вставить значения и как запускать проект так, чтобы Google login и письма на сброс пароля реально работали.

## Что уже сделано в проекте

- Мобильное приложение уже умеет открывать backend OAuth flow и принимать возврат в deep link petmagic://auth/external.
- Android и iOS уже настроены на этот deep link.
- Backend уже умеет:
  - запускать Google external auth
  - завершать вход через mobile callback
  - отправлять письма подтверждения и сброса пароля через SMTP worker
- Docker-конфиг уже умеет передавать нужные переменные окружения в backend контейнер.

Тебе осталось только заполнить реальные значения и запустить сервис.

## Файлы, которые нужно использовать

1. Шаблон переменных окружения: [.env.example](.env.example)
2. Рабочий локальный файл переменных: создай рядом файл .env в корне репозитория
3. Основная docker-конфигурация: [docker-compose.yml](docker-compose.yml)
4. Mobile README: [apps/petmagic-mobile/README.md](apps/petmagic-mobile/README.md)

## Шаг 1. Создай локальный .env файл

В корне проекта рядом с [.env.example](.env.example) создай файл .env.

На Windows PowerShell из корня проекта:

```powershell
Copy-Item .env.example .env
```

После этого открой .env и вставь реальные значения.

## Шаг 2. Что именно заполнить в .env

Ниже блоки, которые важны именно для auth, Google и email.

### 2.1 Google OAuth

Вставь в .env:

```env
GOOGLE_CLIENT_ID=вставь_сюда_google_client_id
GOOGLE_CLIENT_SECRET=вставь_сюда_google_client_secret
```

### 2.2 SMTP для писем

Вставь в .env:

```env
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USERNAME=your-smtp-login
EMAIL_PASSWORD=your-smtp-password
EMAIL_USE_SSL=true
EMAIL_FROM_ADDRESS=no-reply@petmagic.app
EMAIL_FROM_NAME=PetMagic
```

Если используешь Mailtrap для dev, пример будет таким:

```env
EMAIL_HOST=sandbox.smtp.mailtrap.io
EMAIL_PORT=2525
EMAIL_USERNAME=your-mailtrap-username
EMAIL_PASSWORD=your-mailtrap-password
EMAIL_USE_SSL=true
EMAIL_FROM_ADDRESS=no-reply@petmagic.app
EMAIL_FROM_NAME=PetMagic
```

### 2.3 Остальное, что обычно уже нужно для локального запуска

Проверь эти значения:

```env
POSTGRES_PASSWORD=PetMagic_DevPassword123
JWT_SIGNING_KEY=сгенерируй_длинный_секрет
BOOTSTRAP_ADMIN_EMAIL=admin@petmagic.app
BOOTSTRAP_ADMIN_PASSWORD=DemoPassword123!
NEXT_PUBLIC_API_BASE_URL=http://localhost:5000
```

Если нужен новый JWT secret, можно сгенерировать так:

```powershell
[Convert]::ToBase64String((1..64 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))
```

## Шаг 3. Что создать в Google Cloud Console

### 3.1 Создай project

1. Открой Google Cloud Console.
2. Создай новый project или выбери существующий.
3. Включи Google Identity или OAuth APIs, если Google попросит.

### 3.2 Настрой OAuth consent screen

1. Укажи App name: PetMagic
2. Укажи support email
3. Добавь test users, если приложение пока в тестовом режиме

### 3.3 Создай OAuth client

Тип клиента:

- Web application

### 3.4 Самое важное: Authorized redirect URI

В Google нужно добавить redirect URI backend middleware, а не mobile deep link.

Для локального запуска используй:

```text
http://localhost:5000/signin-google
```

Для production потом будет так:

```text
https://api.petmagic.app/signin-google
```

Не вставляй в Google вот это:

```text
petmagic://auth/external
```

Это mobile callback, он используется уже после обработки ответа backend-ом.

### 3.5 Куда вставить выданные Google значения

После создания OAuth client Google покажет:

- Client ID
- Client Secret

Скопируй их в .env:

```env
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

## Шаг 4. Где уже настроен mobile callback

Ничего переносить не нужно, это уже в проекте есть:

- Android deep link: [apps/petmagic-mobile/android/app/src/main/AndroidManifest.xml](apps/petmagic-mobile/android/app/src/main/AndroidManifest.xml)
- iOS URL scheme: [apps/petmagic-mobile/ios/Runner/Info.plist](apps/petmagic-mobile/ios/Runner/Info.plist)

Используется callback URI:

```text
petmagic://auth/external
```

## Шаг 5. Как запустить через Docker

Это самый простой способ, если хочешь, чтобы backend получил все значения из .env автоматически.

Из корня проекта:

```powershell
docker compose up --build
```

После запуска должно быть так:

- backend: http://localhost:5000
- admin web: http://localhost:3000
- postgres: localhost:5432

## Шаг 6. Как запустить mobile

Открой отдельный терминал:

```powershell
Set-Location .\apps\petmagic-mobile
flutter pub get
flutter gen-l10n
```

### 6.1 Android эмулятор

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

### 6.2 Android устройство по USB

Сначала из корня проекта:

```powershell
adb reverse tcp:5000 tcp:5000
```

Потом запуск:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

### 6.3 iOS simulator

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:5000
```

## Шаг 7. Как проверить, что Google вход работает

1. Запусти backend на http://localhost:5000
2. Запусти mobile с правильным API_BASE_URL
3. На экране входа нажми Continue with Google
4. Должен открыться browser flow Google
5. После успешного входа должен сработать возврат в приложение через petmagic://auth/external
6. В приложении должен открыться уже авторизованный state

Если браузер открылся, но возврата в приложение нет, почти всегда проблема в одном из трех мест:

1. Неверный API_BASE_URL
2. Неверный Google redirect URI
3. Backend доступен не по тому host, который указан в Google Console

## Шаг 8. Как проверить, что email работает

Проверь reset flow:

1. Открой экран входа в mobile
2. Нажми Forgot password?
3. Введи email
4. Отправь код
5. Проверь, пришло ли письмо

Если письма нет, проверь по порядку:

1. Правильно ли заполнены EMAIL_HOST, EMAIL_USERNAME, EMAIL_PASSWORD
2. Совпадает ли EMAIL_PORT с настройкой SMTP-провайдера
3. Разрешает ли провайдер отправку с EMAIL_FROM_ADDRESS
4. Нет ли ошибки в логах backend контейнера

## Шаг 9. Если запускаешь backend не через Docker, а через dotnet run

Тут важно понимать разницу:

- .env автоматически удобен для Docker Compose
- обычный dotnet run сам по себе .env не подхватывает

Если хочешь запускать backend локально через dotnet run, сначала в текущем PowerShell нужно выставить переменные вручную.

Пример:

```powershell
$env:GOOGLE_CLIENT_ID="your-google-client-id"
$env:GOOGLE_CLIENT_SECRET="your-google-client-secret"
$env:EMAIL_HOST="sandbox.smtp.mailtrap.io"
$env:EMAIL_PORT="2525"
$env:EMAIL_USERNAME="your-mailtrap-username"
$env:EMAIL_PASSWORD="your-mailtrap-password"
$env:EMAIL_USE_SSL="true"
$env:EMAIL_FROM_ADDRESS="no-reply@petmagic.app"
$env:EMAIL_FROM_NAME="PetMagic"
```

Потом запуск backend:

```powershell
Set-Location .\src\Host\PetMagic.Host.Api
dotnet run
```

Теперь локальный backend тоже будет доступен на:

```text
http://localhost:5000
```

## Готовый минимальный пример .env

```env
POSTGRES_PASSWORD=PetMagic_DevPassword123
JWT_SIGNING_KEY=replace_with_long_random_secret
BOOTSTRAP_ADMIN_EMAIL=admin@petmagic.app
BOOTSTRAP_ADMIN_PASSWORD=DemoPassword123!
NEXT_PUBLIC_API_BASE_URL=http://localhost:5000

GOOGLE_CLIENT_ID=replace_with_google_client_id
GOOGLE_CLIENT_SECRET=replace_with_google_client_secret

EMAIL_HOST=sandbox.smtp.mailtrap.io
EMAIL_PORT=2525
EMAIL_USERNAME=replace_with_mailtrap_username
EMAIL_PASSWORD=replace_with_mailtrap_password
EMAIL_USE_SSL=true
EMAIL_FROM_ADDRESS=no-reply@petmagic.app
EMAIL_FROM_NAME=PetMagic
```

## Что нельзя забыть

1. В Google Console указывать http://localhost:5000/signin-google, а не petmagic://auth/external
2. Если mobile ходит на 127.0.0.1:5000, backend реально должен быть доступен именно там для твоего устройства
3. Для USB Android нужен adb reverse tcp:5000 tcp:5000
4. Для Docker нужно заполнить .env в корне проекта, не внутри apps/petmagic-mobile