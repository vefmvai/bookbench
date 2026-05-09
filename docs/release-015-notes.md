# BookBench 0.1.5 — заметки по релизу

**Дата:** 2026-05-09
**Тип:** patch / hot-fix UX
**Кодовое имя:** «Общая уборка»

## Что сделано

1. **Eval-кейсы убраны из публичного автодополнения.** Папки `commands/analyze-session.eval/` (3 кейса), `commands/evolve.eval/` (4 privacy-теста) и `skills/voice-builder/voice-builder.eval/` (4 кейса) перенесены через `git mv` в `tests/eval-cases/<commands|skills>/<name>/`. После переноса автодополнение `/bookbench:*` показывает только реальные команды. Папки `agent-templates/<role>.eval/` оставлены (Claude Code не сканирует их как команды).
2. **35 описаний переведены с английского на русский.** 15 ключевых команд (`start`, `write-section`, `plan-book`, `plan-section`, `discuss-section`, `status`, `next`, `help`, `voice-build`, `voice-extract`, `voice-list`, `audit-section`, `audit-book`, `re-edit-section`, `import`), 11 SKILL.md (10 переведённых + `popular-science` уже был на русском), 9 агентов. Все длины ≤1024 символа, описания в третьем лице, единый глоссарий (драфт, профиль голоса, факт-чекинг, воркфлоу, реестр и т.д.).
3. **Двойные копии агентов синхронизированы.** `cp agent-templates/<role>.md templates/claude-config/agents/<role>.md` для всех 10 агентов; `diff -q` пуст для каждого. Соблюдено решение A-14.1-01.
4. **Внутренние ссылки обновлены.** Пять файлов с упоминаниями старых путей `*.eval/` поправлены: `commands/evolve.md`, `skills/voice-builder/SKILL.md`, `skills/voice-builder/quality-gate.md`, `docs/dev-mode.md`, `docs/contributing.md`.
5. **`slash_prefix` продублирован в `.claude-plugin/plugin.json`.** Поле было только в нашем кастомном `manifest.json`; теперь дополнительно лежит в стандартном `.claude-plugin/plugin.json`, который Claude Code читает официально. Эффект на автодополнение проверится автором после `/plugin update bookbench`.
6. **Версии обновлены до 0.1.5** в `manifest.json` (включая `bookbench.version`), `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (`metadata.version`).
7. **CHANGELOG.md** дополнен секцией `[0.1.5] — 2026-05-09` с тремя подсекциями (Changed, Fixed, Known issues) и обновлёнными ссылками на теги.

## Что осталось

- **35 редких команд с английскими описаниями** — `archive`, `register`, `forget`, `evolve`, `tune*`, `workflow-*`, `research-*`, `voice-save-as`, `voice-import`, `extract-learnings`, `ship`, `resolve`, `resume`, `run`, `settings`, `update`, `debug`, `doctor`, `config`, `guidelines`, `contribute-genre`, `list`, `analyze-session`, `write-section:*`. Запланированы на 0.1.6 или 0.2.

## Известные проблемы

- **Эффект `slash_prefix: "book"` пока не подтверждён эмпирически.** Если Claude Code 2.1.x игнорирует поле и формирует префикс из `name`, останется `/bookbench:*`. В этом случае фикс остаётся как «известный хвост» до 0.2 — насиловать конфиг не будем.
- **Privacy-grep** по запретным терминам (ДОТУ, нейросети, мозг, e-mail автора и т.д.) — пуст, опен-сорс гигиена соблюдена.

## Финальные проверки

| Проверка | Результат |
| --- | --- |
| `find commands -name "*.eval*" -o -name "case-*"` | 0 результатов |
| `find skills -name "*.eval*"` | 0 результатов |
| `find tests/eval-cases -type f -name "*.md" \| wc -l` | 11 |
| Кириллица в `description:` для 36 файлов | 100% OK |
| Длина каждого описания ≤1024 char | 100% OK (max 792) |
| `diff -q agent-templates/<role>.md templates/claude-config/agents/<role>.md` | пусто для всех 10 |
| Privacy-grep по запретным терминам | 0 |
