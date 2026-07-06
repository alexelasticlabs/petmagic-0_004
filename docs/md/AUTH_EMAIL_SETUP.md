# Полная настройка Google-входа и email для PetMagic

Ниже актуальная инструкция под текущую реализацию.

## Как сейчас работает Google-вход

1. Мобильное приложение запускает нативный Google Sign-In.
2. Google возвращает приложению identity token.
3. Приложение отправляет этот token в backend.
4. Backend проверяет token и выдает обычную PetMagic-сессию.
5. Если нативный сценарий недоступен, приложение откатывается на browser fallback flow.

Это ближе к production mobile UX, чем старый сценарий с обязательным переводом пользователя в браузер.

## Что уже сделано в проекте

- Flutter mobile уже поддерживает native Google sign-in.
- Backend уже умеет принимать Google ID token и обменивать его на PetMagic session.
- Старый browser-based Google OAuth flow оставлен как fallback.
- Deep link `petmagic://auth/external` уже настроен для fallback flow.
- SMTP worker уже умеет отправлять confirmation и password reset письма.
- Docker уже передает Google- и email-env-переменные в backend.

## Что использовать

1. Шаблон переменных окружения: [.env.example](../../.env.example)
2. Локальный файл переменных: `.env` рядом с `.env.example` в корне репозитория
3. Основная Docker-конфигурация: [docker-compose.yml](../../docker-compose.yml)
4. Mobile README: [apps/petmagic-mobile/README.md](../../apps/petmagic-mobile/README.md)

## Шаг 1. Создай локальный `.env`

В корне проекта рядом с [.env.example](../../.env.example) создай файл `.env`.

Для Windows PowerShell из корня проекта:

```powershell
Copy-Item .env.example .env
```

После этого открой `.env` и вставь реальные значения.

## Шаг 2. Заполни `.env`

Ниже только блоки, которые важны для auth, Google, Apple и email.

### 2.1 Google OAuth для backend

Добавь в `.env`:

```env
GOOGLE_CLIENT_ID=вставь_сюда_google_client_id
GOOGLE_CLIENT_SECRET=вставь_сюда_google_client_secret
GOOGLE_AUDIENCES=web_client_id,ios_client_id,android_client_id
```

Важно:

- сюда нужно вставлять `Web application` OAuth client из Google Cloud Console;
- `GOOGLE_AUDIENCES` не является секретом: указывай client IDs, которые backend принимает в `aud` Google ID token для конкретной среды;
- backend проверяет Google identity token и требует `email_verified=true`.

### 2.2 Apple Sign In для backend

Добавь в `.env`:

```env
APPLE_CLIENT_ID=com.petmagic.app
APPLE_CLIENT_SECRET=generated_apple_client_secret
APPLE_AUDIENCES=com.petmagic.app,services.id.if.used
APPLE_AUTHORIZATION_ENDPOINT=https://appleid.apple.com/auth/authorize
APPLE_TOKEN_ENDPOINT=https://appleid.apple.com/auth/token
```

Важно:

- Apple private key, Team ID и Key ID используются для генерации `APPLE_CLIENT_SECRET`; private key нельзя коммитить в Git;
- `APPLE_AUDIENCES` не является секретом: указывай Bundle ID и Services ID, которые backend принимает в `aud` Apple identity token для конкретной среды;
- скрытый Apple email и Private Relay сохраняются как обычный verified email от Apple.

### 2.3 SMTP для писем

Добавь в `.env`:

```env
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USERNAME=your-smtp-login
EMAIL_PASSWORD=your-smtp-password
EMAIL_USE_SSL=true
EMAIL_FROM_ADDRESS=no-reply@petmagic.app
EMAIL_FROM_NAME=PetMagic
```

Если используешь Mailtrap для dev:

```env
EMAIL_HOST=sandbox.smtp.mailtrap.io
EMAIL_PORT=2525
EMAIL_USERNAME=your-mailtrap-username
EMAIL_PASSWORD=your-mailtrap-password
EMAIL_USE_SSL=true
EMAIL_FROM_ADDRESS=no-reply@petmagic.app
EMAIL_FROM_NAME=PetMagic
```

### 2.4 Остальное для локального запуска

Проверь эти значения:

```env
BACKEND_HOST_PORT=5001
POSTGRES_PASSWORD=replace_with_local_postgres_password
JWT_SIGNING_KEY=сгенерируй_длинный_секрет
BOOTSTRAP_ADMIN_EMAIL=admin@petmagic.app
BOOTSTRAP_ADMIN_PASSWORD=replace_with_local_admin_password
NEXT_PUBLIC_API_BASE_URL=http://localhost:${BACKEND_HOST_PORT}
```

По умолчанию `.env.example` использует `BACKEND_HOST_PORT=5001`.
Если на твоей машине `.env` уже переопределен на `5000`, используй `http://localhost:5000` во всех примерах ниже.

Если нужен новый JWT secret:

```powershell
[Convert]::ToBase64String((1..64 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))
```

## Шаг 3. Настрой Google Cloud Console

### 3.1 Создай project

1. Открой Google Cloud Console.
2. Создай новый project или выбери существующий.
3. Включи Google Identity или OAuth APIs, если Google попросит.

### 3.2 Настрой OAuth consent screen

1. Укажи `App name`: `PetMagic`.
2. Укажи support email.
3. Добавь test users, если приложение пока в тестовом режиме.

### 3.3 Создай три OAuth client-а

Для нормального production-style mobile Google sign-in нужны три клиента:

1. `Web application` client
2. `Android` client
3. `iOS` client

### 3.4 Web application client

Создай OAuth client типа `Web application`.

Именно его значения нужно положить в backend env:

```env
GOOGLE_CLIENT_ID=web_client_id
GOOGLE_CLIENT_SECRET=web_client_secret
```

Для browser fallback добавь redirect URI backend middleware.

Локально:

```text
http://localhost:<BACKEND_HOST_PORT>/signin-google
```

В production:

```text
https://api.petmagic.app/signin-google
```

### 3.5 Android client

Создай OAuth client типа `Android`.

Используй application id из проекта:

```text
com.petmagic.app
```

Его можно увидеть в [apps/petmagic-mobile/android/app/build.gradle.kts](../../apps/petmagic-mobile/android/app/build.gradle.kts).

В Google Cloud Console для Android-клиента нужно указать:

1. `Package name`: `com.petmagic.app`
2. `SHA-1` fingerprint debug keystore
3. Позже отдельно `SHA-1` release keystore

Чтобы получить debug `SHA-1` на Windows:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

### 3.6 iOS client

Создай OAuth client типа `iOS`.

Используй bundle identifier из проекта:

```text
com.petmagic.app
```

Его можно увидеть в [apps/petmagic-mobile/ios/Runner.xcodeproj/project.pbxproj](../../apps/petmagic-mobile/ios/Runner.xcodeproj/project.pbxproj).

### 3.7 Что в итоге идет в `.env`

В `.env` идут только значения `Web application` client:

```env
GOOGLE_CLIENT_ID=web_client_id
GOOGLE_CLIENT_SECRET=web_client_secret
```

`Android` client и `iOS` client в `.env` не вставляются. Они нужны в Google Cloud Console, чтобы нативный вход на устройстве считался валидным для ваших platform IDs.

## Шаг 4. Где уже настроен mobile callback

Ничего переносить не нужно, fallback callback уже есть в проекте:

- Android deep link: [apps/petmagic-mobile/android/app/src/main/AndroidManifest.xml](../../apps/petmagic-mobile/android/app/src/main/AndroidManifest.xml)
- iOS URL scheme: [apps/petmagic-mobile/ios/Runner/Info.plist](../../apps/petmagic-mobile/ios/Runner/Info.plist)

Используется callback URI:

```text
petmagic://auth/external
```

## Шаг 5. Запуск через Docker

Это самый простой способ, если хочешь, чтобы backend получил все значения из `.env` автоматически.

Из корня проекта:

```powershell
docker compose up --build
```

После запуска должно быть так:

- backend: `http://localhost:<BACKEND_HOST_PORT>`
- admin web: `http://localhost:3000`
- postgres: `localhost:5432`

## Шаг 6. Запуск mobile

Открой отдельный терминал:

```powershell
Set-Location .\apps\petmagic-mobile
flutter pub get
flutter gen-l10n
```

### 6.1 Android-эмулятор

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:<BACKEND_HOST_PORT>
```

### 6.2 Android-устройство по USB

Сначала из корня проекта:

```powershell
adb reverse tcp:<BACKEND_HOST_PORT> tcp:<BACKEND_HOST_PORT>
```

Потом запуск:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:<BACKEND_HOST_PORT>
```

### 6.3 iOS simulator

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:<BACKEND_HOST_PORT>
```

## Шаг 7. Как проверить, что Google-вход работает

1. Запусти backend на `http://localhost:<BACKEND_HOST_PORT>` для Docker Compose или на `http://localhost:5001` для `dotnet run`.
2. Запусти mobile с правильным `API_BASE_URL`.
3. На экране входа нажми `Continue with Google`.
4. Должен открыться нативный Google chooser или account picker, а не полный внешний браузер.
5. После выбора аккаунта приложение должно вернуться в авторизованный state.

Fallback-сценарий:

- если нативный сценарий недоступен, приложение может открыть browser-based Google flow;
- в этом случае возврат пойдет через `petmagic://auth/external`.

Если нативный вход не работает, почти всегда проблема в одном из этих мест:

1. Для Android не создан OAuth client с package name `com.petmagic.app`.
2. Для Android не указан `SHA-1` debug или release keystore.
3. Для iOS не создан OAuth client с bundle ID `com.petmagic.app`.
4. В `.env` backend лежит не `Web application` client, а какой-то другой client ID.
5. `API_BASE_URL` смотрит не на тот backend.

Если fallback flow открылся в браузере, но возврата нет, проверь:

1. Redirect URI `http://localhost:<BACKEND_HOST_PORT>/signin-google` для Docker Compose или `http://localhost:5001/signin-google` для `dotnet run`.
2. Deep link `petmagic://auth/external`.
3. Доступность backend по тому host, который использует приложение.

## Шаг 8. Как проверить, что email работает

Проверь reset flow:

1. Открой экран входа в mobile.
2. Нажми `Forgot password?`.
3. Введи email.
4. Отправь код.
5. Проверь, пришло ли письмо.

Если письма нет, проверь по порядку:

1. Правильно ли заполнены `EMAIL_HOST`, `EMAIL_USERNAME`, `EMAIL_PASSWORD`.
2. Совпадает ли `EMAIL_PORT` с настройкой SMTP-провайдера.
3. Разрешает ли провайдер отправку с `EMAIL_FROM_ADDRESS`.
4. Нет ли ошибки в логах backend-контейнера.

## Шаг 9. Если запускаешь backend не через Docker, а через `dotnet run`

Важно:

- `.env` автоматически удобен для Docker Compose;
- обычный `dotnet run` сам по себе `.env` не подхватывает.

Если хочешь запускать backend локально через `dotnet run`, сначала в текущем PowerShell выставь переменные вручную.

Пример:

```powershell
$env:BACKEND_HOST_PORT="5001"
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

Если запускаешь backend через `dotnet run`, локальный launch profile слушает:

```text
http://localhost:5001
```

## Готовый минимальный пример `.env`

```env
BACKEND_HOST_PORT=5001
POSTGRES_PASSWORD=replace_with_local_postgres_password
JWT_SIGNING_KEY=replace_with_long_random_secret
BOOTSTRAP_ADMIN_EMAIL=admin@petmagic.app
BOOTSTRAP_ADMIN_PASSWORD=replace_with_local_admin_password
NEXT_PUBLIC_API_BASE_URL=http://localhost:${BACKEND_HOST_PORT}

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

1. `GOOGLE_CLIENT_ID` и `GOOGLE_CLIENT_SECRET` в `.env` должны быть от `Web application` client.
2. Для Android нужен отдельный Google OAuth client с package name `com.petmagic.app` и `SHA-1`.
3. Для iOS нужен отдельный Google OAuth client с bundle ID `com.petmagic.app`.
4. Redirect URI `http://localhost:<BACKEND_HOST_PORT>/signin-google` нужен для browser fallback, а не для native mobile sign-in.
5. Для USB Android нужен `adb reverse tcp:<BACKEND_HOST_PORT> tcp:<BACKEND_HOST_PORT>`.
6. Для Docker нужно заполнять `.env` в корне проекта, не внутри `apps/petmagic-mobile`.
