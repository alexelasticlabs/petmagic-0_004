# Mobile Background Freeze/Crash Playbook

## 1) Быстрый smoke-check

1. Откройте экран чата поддержки.
2. Подождите 10-20 секунд, чтобы поднялось realtime-подключение.
3. Сверните приложение (Home), подождите 30-60 секунд.
4. Вернитесь в приложение.
5. Проверьте:
- экран не завис;
- нет принудительного закрытия;
- чат обновляется после возврата;
- отправка сообщения работает.

Повторить цикл 5-10 раз подряд.

## 2) Стресс-сценарии

### Сценарий A: слабая сеть
1. На устройстве включить/выключить Wi-Fi в фоне 2-3 раза.
2. Между переключениями сворачивать/разворачивать приложение.
3. Проверить восстановление UI и отправки сообщений.

### Сценарий B: долгий фон
1. Открыть чат.
2. Свернуть приложение на 3-5 минут.
3. Вернуться и отправить сообщение с вложением.
4. Проверить отсутствие фриза/краша.

### Сценарий C: галерея генераций
1. Открыть экран creations.
2. Свернуть приложение на 30-60 секунд.
3. Вернуться, обновить pull-to-refresh.
4. Проверить, что список активных/готовых/ошибочных генераций отображается стабильно.

## 3) Сбор Android-логов (если поймали краш)

Команды запускать из корня репозитория.

1. Очистка старого буфера:
   adb logcat -c

2. Запуск записи с фильтром:
   adb logcat Flutter:D DartVM:D AndroidRuntime:E ActivityManager:I *:S > crash-background.log

3. Воспроизвести проблему (свернуть/развернуть приложение).

4. Остановить запись Ctrl+C.

5. Ключевые строки для поиска в логе:
- FATAL EXCEPTION
- ANR
- lost connection to device
- SocketException
- HttpException
- Bad state: Future already completed
- setState() called after dispose()

## 4) Что приложить в баг-репорт

- Устройство и Android/iOS версия.
- Частота воспроизведения (например, 3 из 10).
- Последовательность действий перед крашем.
- Файл crash-background.log.
- Скриншот последнего экрана перед падением.

## 5) Команда быстрой проверки после правок

Из apps/petmagic-mobile:

flutter analyze lib/core/realtime/realtime_client.dart lib/features/support/presentation/support_chat_page.dart lib/features/templates/presentation/templates_controller.dart lib/features/templates/presentation/templates_page.dart lib/features/templates/presentation/generation_history_controller.dart lib/features/templates/presentation/generations_gallery_page.dart
