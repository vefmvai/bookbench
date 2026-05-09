# BookBench 0.2.0 — release notes

> Major релиз. Структурный рефакторинг репозитория под канонічную структуру Claude Code marketplace. Без содержательных правок в командах, скиллах или агентах.

## Что сделано

**Перенос плагина в подпапку.** Весь исполняемый код плагина (`commands/`, `skills/`, `agent-templates/`, `lib/`, `templates/`) и его манифесты (`.claude-plugin/plugin.json`, `manifest.json`, `defaults.yaml`, `blocks-catalog.md`) переехали из корня репозитория в `plugins/bookbench/`. В корне репо остались только проектные файлы: `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, внешняя документация (`docs/`), инфраструктура тестов (`tests/`) и сам маркетплейс-манифест (`.claude-plugin/marketplace.json`).

**`marketplace.json` переключён на `git-subdir`.** Источник плагина теперь:

```json
"source": {
  "source": "git-subdir",
  "url": "https://github.com/vefmvai/bookbench.git",
  "path": "plugins/bookbench",
  "ref": "main",
  "sha": "0418a7e6b05ae753618ef5ca1b82c6f94c8310f2"
}
```

Это каноническая для Claude Code marketplace схема, при которой Claude Code 2.1.x корректно отрабатывает sparse-checkout и выкачивает именно подпапку плагина целиком.

**Версии в `plugin.json`, `manifest.json` и `marketplace.json` подняты до 0.2.0.**

**Обновлены тестовые скрипты:** `tests/audit-public-cleanliness.sh` (дефолтный target → `plugins/bookbench/`) и `tests/voice-commands-privacy.test.sh` (путь к каталогу команд → `../plugins/bookbench/commands`). Оба теста проходят: 18/18 PASS у privacy-теста, 0 нарушений у audit-public-cleanliness.

**Обновлена документация:** примеры команд установки в `README.md` и `docs/quickstart.md` переписаны под `/plugin marketplace add vefmvai/bookbench` + `/plugin install bookbench@bookbench`. В `docs/installation.md` раздел «Режим 3. Marketplace» переписан с «отложено в 0.2+» на «с 0.2.0 — рекомендованный путь». В `docs/architecture.md` добавлено уточнение о подпапочной структуре. В `docs/contributing.md`, `docs/faq.md`, `docs/dev-mode.md` пути к файлам плагина обновлены на `plugins/bookbench/...`.

## Sha коммитов

- **Структурный коммит:** `0418a7e6b05ae753618ef5ca1b82c6f94c8310f2` — 244 файла переезжают через `git mv`, плюс 13 модификаций manifesto/docs/tests.
- **Sha-pin коммит:** `48d2de693023f2ddbb6add3d8474d23631cbf732` — единственная правка в `marketplace.json`: фиксация `source.sha` на sha структурного коммита.
- **Тег:** `v0.2.0` указывает на sha-pin коммит.

## URL Release

`https://github.com/vefmvai/bookbench/releases/tag/v0.2.0`

## Цифры

- **Число перенесённых файлов плагина:** 233 (вся `plugins/bookbench/` поддерево).
- **Число поправленных относительных путей в коде плагина:** 0. Внутренняя структура `plugins/bookbench/` идентична бывшему корню репо (`commands/` рядом с `skills/`, `templates/hooks/` рядом с `skills/`), поэтому внутри-плагинные относительные пути остались валидными. Пути в `tests/`, наоборот, потребовали правки: 2 файла (`audit-public-cleanliness.sh`, `voice-commands-privacy.test.sh`).
- **Опен-сорс гигиена:** финальный grep по запрещённым токенам в `plugins/bookbench/` — 0 совпадений.

## Что осталось известными хвостами

- **35 редких команд всё ещё с английскими описаниями** (наследие 0.1.5). Перевод запланирован на 0.2.1 — отдельный точечный патч, не блокирует 0.2.0.
- **Префикс `/book:` против `/bookbench:`** — `slash_prefix: "book"` указан и в `manifest.json`, и в `.claude-plugin/plugin.json`, но фактическое поведение Claude Code 2.1.x при `git-subdir`-источнике эмпирически проверяется только после `/plugin install`. Если префикс снова окажется `/bookbench:`, это не баг релиза, а ограничение Claude Code, и фикс уйдёт в апстрим Anthropic, а не в наш плагин.

## Один главный совет автору перед `/plugin update`

**Сделай чистую переустановку, а не `update`.** Между 0.1.x и 0.2.0 поменялся не код плагина, а **источник** в `marketplace.json` (`url` → `git-subdir` с `path: "plugins/bookbench"`) и физическое расположение файлов в кэше. `/plugin update bookbench` может попытаться обновиться внутри старой структуры кэша и оставить «битые» хвосты. Чистый сценарий:

```
/plugin uninstall bookbench@bookbench
/plugin marketplace remove bookbench
/plugin marketplace add vefmvai/bookbench
/plugin install bookbench@bookbench
/reload-plugins
```

После этого `/book:doctor` должен показать `BookBench 0.2.0`, а в `~/.claude/plugins/cache/bookbench/.../<sha>/` должны быть видны `commands/`, `skills/`, `agent-templates/`, `lib/`, `templates/` — то, чего не хватало в кэшах 0.1.x из-за sparse-checkout.
