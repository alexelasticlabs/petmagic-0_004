# Git workflow

`AGENTS.md` is the only repository source of agent workflow instructions.
Do not duplicate or override these rules in `docs/` or `.github/agents/`.

- Работай непосредственно в `master`.
- Не создавай, не переключай и не предлагай новые Git-ветки или worktree без явного запроса владельца репозитория.
- Перед коммитом проверяй `git status --short --branch`, разбивай независимые изменения на осмысленные коммиты и не включай сгенерированные или секретные файлы.
