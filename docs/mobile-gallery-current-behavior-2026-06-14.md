# Мобильная галерея: текущее поведение (2026-06-14)

## Что в приложении называется галереей

В мобильном приложении сейчас есть два связанных, но разных сценария:

1. Галерея результатов генераций (вкладка Creations, путь /creations).
2. Галерея фото питомца (экран профиля питомца, путь /profile/pets/:petId).

Они используют разные экраны, провайдеры и API-методы.

## 1) Галерея результатов генераций (Creations)

### Где находится логика

- Экран: [apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page.dart](apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page.dart)
- Карточки и действия: [apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page_cards.dart](apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page_cards.dart), [apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart](apps/petmagic-mobile/lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart)
- Контроллер состояния: [apps/petmagic-mobile/lib/features/templates/presentation/generation_history_controller.dart](apps/petmagic-mobile/lib/features/templates/presentation/generation_history_controller.dart)
- Локальный стор медиа: [apps/petmagic-mobile/lib/features/templates/data/generation_gallery_store.dart](apps/petmagic-mobile/lib/features/templates/data/generation_gallery_store.dart)
- Маппинг статусов/превью: [apps/petmagic-mobile/lib/features/templates/presentation/mappers/generations_gallery_mappers.dart](apps/petmagic-mobile/lib/features/templates/presentation/mappers/generations_gallery_mappers.dart)
- Роутинг вкладки: [apps/petmagic-mobile/lib/app/router/app_router.dart](apps/petmagic-mobile/lib/app/router/app_router.dart)

### Пользовательский путь

1. Пользователь открывает вкладку Creations.
2. Экран проверяет авторизацию:

- Если пользователь не авторизован, показывается ProtectedAuthGate.
- Если авторизован, загружается история генераций.

3. Отображаются фильтры: All, Active, Ready, Failed.
4. Пользователь может открыть карточку и перейти в статус генерации.
5. Для Ready-элементов доступны действия: сохранить, поделиться, скопировать ссылку, удалить, отправить в поддержку.

### Как загружаются данные

Источник данных управляется GenerationHistoryController.

Основной порядок загрузки:

1. Попытка показать кэш в памяти для выбранного фильтра.
2. Если нужно, чтение персистентного кэша генераций.
3. Запрос на сервер fetchGenerations(status, take: 50).
4. Запрос unread счетчика fetchUnreadGenerationCount().
5. Обновление UI и кэша.

Если есть локально удаленные элементы (tombstone), они исключаются из отображения.

### Фильтры и отображение

- All:
  - Active секция: элементы не в terminal-состоянии.
  - Ready секция: completed.
  - Failed секция: failed.
- Ready: грид карточек.
- Active: список карточек с прогрессом и ETA.
- Failed: список карточек с причиной и действиями.

### Realtime и автообновление

Контроллер включает два механизма актуализации:

1. Realtime (best-effort):

- Подписка на события templates_generation_status_changed.
- При событии generation upsert-ится в текущий список и кэши.
- Для completed запускается синхронизация локального медиа.

2. Автообновление таймером:

- Базовый интервал: 8 секунд.
- При ошибках интервал растет экспоненциально до 30 секунд.
- При успешной синхронизации backoff сбрасывается.

### Оффлайн-поведение и баннеры

Если запрос к серверу падает, но на экране уже есть элементы:

- Галерея не очищается.
- Включается оффлайн-баннер.
- Пользователь продолжает видеть предыдущие данные.

Когда соединение восстанавливается:

- Показывается баннер восстановления.
- Баннер автоматически скрывается через 3 секунды.

### Локальный кэш медиа (preview/result)

Для completed генераций GenerationGalleryStore:

1. Создает/обновляет запись ready-item.
2. Скачивает preview и output в локальную директорию.
3. Валидирует файлы (существуют и не пустые).
4. Проставляет локальные пути в состояние (localPreviewPath/localOutputPath).

Это позволяет:

- Быстрее отрисовывать карточки.
- Сохранить часть функциональности при плохой сети.
- Не повторять скачивание, если файл уже пригоден.

### Действия на карточках Ready

Из bottom sheet доступны действия:

1. Открыть статус генерации.
2. Сохранить в системную галерею устройства.
3. Поделиться файлом.
4. Скопировать безопасную ссылку.
5. Удалить генерацию.
6. Сообщить о проблеме (переход в поддержку).

Для save/share есть защита от параллельного запуска действия через флаг in-flight и CancelToken.

### Удаление генерации

Удаление сделано оптимистично:

1. Элемент сразу убирается из текущего списка и кэшей.
2. Локально ставится tombstone (isDeletedLocally + pendingServerDelete).
3. Пытается выполниться серверное delete.
4. Если сервер временно недоступен, pending delete остается и ретраится при следующих синках.

### Непрочитанные элементы

- Сверху отображается unread badge.
- При открытии карточки вызывается markRead.
- Счетчик unread уменьшается локально и синхронизируется с сервером.

## 2) Галерея фото питомца (Pet Details)

### Где находится логика

- Экран списка и деталей питомцев: [apps/petmagic-mobile/lib/features/pets/presentation/my_pets_page.dart](apps/petmagic-mobile/lib/features/pets/presentation/my_pets_page.dart)
- API-репозиторий: [apps/petmagic-mobile/lib/features/templates/data/template_generation_repository.dart](apps/petmagic-mobile/lib/features/templates/data/template_generation_repository.dart)
- Роуты: [apps/petmagic-mobile/lib/app/router/app_router.dart](apps/petmagic-mobile/lib/app/router/app_router.dart)

### Пользовательский путь

1. Переход в My Pets.
2. Выбор питомца.
3. На экране деталей показывается секция Photos (grid).
4. Пользователь может добавлять и управлять фото.

### Что можно сделать с фото питомца

1. Добавить фото из системной галереи телефона.
2. Поставить фото как avatar.
3. Пометить фото как favorite.
4. Использовать фото как вход для генерации (переход в Templates с petId/petPhotoId).
5. Удалить фото.

### Какие API вызываются

Через TemplateGenerationRepository:

- fetchPetPhotos: GET /api/pets/{petId}/photos
- uploadPetPhoto: POST /api/pets/{petId}/photos (multipart)
- setPetPhotoAsAvatar: POST /api/pets/{petId}/photos/{photoId}/set-avatar
- setPetPhotoFavorite: POST /api/pets/{petId}/photos/{photoId}/favorite
- deletePetPhoto: DELETE /api/pets/{petId}/photos/{photoId}

При загрузке фото дополнительно:

- Проверяется допустимый content type.
- Если тип не разрешен, бросается pets.photo_type_not_allowed.

### Оптимизация отображения фото

- Для галереи фото питомца нет отдельного локального оффлайн-кэша, как в Creations.
- Сетка фото питомца построена на lazy SliverGrid.
- Карточки используют только безопасный thumbnailUrl; если thumbnail отсутствует или небезопасен, показывается fallback вместо загрузки оригинального url.
- Изображения рендерятся через CachedNetworkImage с bounded memory cache width.
- Для загрузки есть skeleton/placeholder, для ошибок есть fallback.
- После upload/avatar/favorite/delete используется invalidate провайдеров для перезагрузки данных.
- Провайдеры списка питомцев, фото и генераций держат короткий keepAlive TTL, чтобы не делать лишние повторные запросы при быстрых возвратах между экранами.

## Навигация и связи между двумя галереями

1. Из Pet Details можно перейти в Templates и генерировать на базе выбранного фото.
   - Если Templates открыт с `petId` и `petPhotoId`, повторный tap по уже выбранному питомцу в shortcut-блоке сохраняет `petPhotoId`; выбор другого питомца очищает выбранное фото.
2. Результаты генерации после обработки попадают в Creations (галерею генераций).
3. Из Creations можно открыть статус генерации, сохранить/поделиться результатом или удалить его.

## Состояния интерфейса (важно для QA)

### Creations

1. Not Authenticated: ProtectedAuthGate.
2. Loading + empty: индикатор загрузки.
3. Error + empty: error state с retry.
4. Empty: empty state без карточек.
5. Data online: нормальный список/грид.
6. Data offline: список остается + оффлайн-баннер.
7. Recovered: баннер восстановления на 3 секунды.

### Pet Photos

1. Loading: linear progress в секции Photos.
2. Error: inline retry.
3. Empty: текст No photos yet.
4. Data: grid карточек с action-кнопками.

## Что важно учитывать при доработках

1. Не ломать optimistic delete + pending server delete в Creations.
2. Не убирать безопасную обработку ссылок медиа (safe URI parsing).
3. Сохранять совместимость с unread-count механизмом.
4. Любые изменения таймингов автообновления согласовывать с нагрузкой API.
5. Если добавляется оффлайн для фото питомца, лучше реализовывать через отдельный стор, не смешивая с generation_gallery_store.

## Быстрый итог

- Creations: зрелая галерея с realtime, автообновлением, оффлайн-поведением и локальной материализацией файлов.
- Pet Photos: функциональная CRUD-галерея фото питомца с lazy grid, thumbnail-first загрузкой, placeholder/fallback и корректной инвалидацией после действий, но без отдельного оффлайн-слоя.
- Пользовательский флоу: Pet Photos -> Templates -> Generation Status -> Creations.
