# Git workflow

`AGENTS.md` is the only repository source of agent workflow instructions.
Do not duplicate or override these rules in `docs/` or `.github/agents/`.

- Работай непосредственно в `master`.
- Не создавай, не переключай и не предлагай новые Git-ветки или worktree без явного запроса владельца репозитория.
- Перед коммитом проверяй `git status --short --branch`, разбивай независимые изменения на осмысленные коммиты и не включай сгенерированные или секретные файлы.
- Для production-задач PetMagic доступ к VPS уже настроен: сначала используй авторизованное SSH-подключение пользователя `frontrunner-dev` к текущему production host и безопасные read-only проверки. Не объявляй VPS недоступным, пока это подключение не проверено. Не раскрывай и не изменяй SSH-ключи, пароли или содержимое production env-файлов.
