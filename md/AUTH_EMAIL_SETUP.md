# Полная настройка Google входа и email для PetMagic

Ниже актуальная инструкция именно под текущую реализацию.

Google вход теперь работает так:

1. Мобильное приложение сначала запускает нативный Google Sign-In.
2. Google возвращает приложению identity token.
3. Приложение отправляет этот token в backend.
4. Backend проверяет token и выдает обычную PetMagic-сессию.
5. Если нативный сценарий недоступен, приложение может откатиться на browser fallback flow.

Это ближе к production mobile UX, чем старый сценарий с обязательным переводом пользователя в браузер.

## Что уже сделано в проекте

- Flutter mobile уже поддерживает native Google sign-in.
- Backend уже умеет принимать Google id token и обменивать его на PetMagic session.
- Старый browser-based Google OAuth flow оставлен как fallback.
- Deep link petmagic://auth/external уже настроен для fallback flow.
- SMTP worker уже умеет отправлять confirmation и password reset письма.
- Docker уже передает Google и email env-переменные в backend.

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

### 2.1 Google OAuth для backend

Вставь в .env:

```env
GOOGLE_CLIENT_ID=вставь_сюда_google_client_id
GOOGLE_CLIENT_SECRET=вставь_сюда_google_client_secret
```

Важно:

- сюда нужно вставлять Web application OAuth client из Google Cloud Console
- эти значения использует backend для проверки Google identity token и для browser fallback

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
BOOTSTRAP_ADMIN_PASSWORD=replace_with_local_admin_password
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

### 3.3 Создай три OAuth client-а

Для нормального mobile production-style Google sign-in нужны три клиента:

1. Web application client
2. Android client
3. iOS client

### 3.4 Web application client

Создай OAuth client типа Web application.

Именно его значения нужно положить в backend env:

```env
GOOGLE_CLIENT_ID=web_client_id
GOOGLE_CLIENT_SECRET=web_client_secret
```

Для browser fallback добавь redirect URI backend middleware:

Локально:

```text
http://localhost:5000/signin-google
```

В production:

```text
https://api.petmagic.app/signin-google
```

### 3.5 Android client

Создай OAuth client типа Android.

Используй application id из проекта:

```text
com.petmagic.app
```

Его можно увидеть в [apps/petmagic-mobile/android/app/build.gradle.kts](apps/petmagic-mobile/android/app/build.gradle.kts).

В Google Cloud Console для Android клиента нужно указать:

1. Package name: app.petmagic.petmagic_mobile
1. Package name: com.petmagic.app
2. SHA-1 fingerprint debug keystore
3. Позже отдельно SHA-1 release keystore

Чтобы получить debug SHA-1 на Windows:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

### 3.6 iOS client

Создай OAuth client типа iOS.

Используй bundle identifier из проекта:

```text
com.petmagic.app
```

Его можно увидеть в [apps/petmagic-mobile/ios/Runner.xcodeproj/project.pbxproj](apps/petmagic-mobile/ios/Runner.xcodeproj/project.pbxproj).

### 3.7 Что в итоге куда вставлять

В .env идут только значения Web application client:

```env
GOOGLE_CLIENT_ID=web_client_id
GOOGLE_CLIENT_SECRET=web_client_secret
```

Android client и iOS client в .env не вставляются. Они нужны в Google Cloud Console, чтобы нативный вход на устройстве считался валидным для ваших platform ids.

## Шаг 4. Где уже настроен mobile callback

Ничего переносить не нужно, fallback callback уже в проекте есть:

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
4. Должен открыться нативный Google chooser / account picker, а не полный внешний браузер
5. После выбора аккаунта приложение должно вернуться в авторизованный state

Fallback-сценарий:

- если нативный сценарий недоступен, приложение может открыть browser-based Google flow
- в этом случае возврат пойдет через petmagic://auth/external

Если нативный вход не работает, почти всегда проблема в одном из этих мест:

1. Для Android не создан OAuth client с package name com.petmagic.app
2. Для Android не указан SHA-1 debug или release keystore
3. Для iOS не создан OAuth client с bundle id com.petmagic.app
4. В .env backend лежит не Web application client, а какой-то другой client id
5. API_BASE_URL смотрит не на тот backend

Если fallback flow открылся в браузере, но возврата нет, проверь:

1. Redirect URI http://localhost:5000/signin-google или production URI
2. Deep link petmagic://auth/external
3. Доступность backend по тому host, который использует приложение

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
BOOTSTRAP_ADMIN_PASSWORD=replace_with_local_admin_password
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

1. GOOGLE_CLIENT_ID и GOOGLE_CLIENT_SECRET в .env должны быть от Web application client
2. Для Android нужен отдельный Google OAuth client с package name com.petmagic.app и SHA-1
3. Для iOS нужен отдельный Google OAuth client с bundle id com.petmagic.app
4. Redirect URI http://localhost:5000/signin-google нужен для browser fallback, а не для native mobile sign-in
5. Для USB Android нужен adb reverse tcp:5000 tcp:5000
6. Для Docker нужно заполнять .env в корне проекта, не внутри apps/petmagic-mobile
