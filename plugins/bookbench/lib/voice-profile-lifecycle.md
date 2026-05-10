# Voice profile lifecycle

> **Назначение.** Описывает 4 состояния файла `.book/context/voice-profile.md` и контракт, по которому субагенты с ним работают. Гарантирует, что черновой / неподтверждённый профиль голоса автора не попадёт в производственный контур (пишущий агент не использует его до явного подтверждения).
>
> **Этап создания.** 24 (релиз 0.3.2 — patch после live-теста «Спираль»). Фиксирует решение **D-35**.
>
> **Триггер создания.** Класс ошибки #4 (критический) первого живого запуска `/bookbench:start` 2026-05-10: коуч-агент извлёк подробный voice-profile из черновика автора без явного согласия и пометил его как «B1-confirmed». Структурный фикс — отделение состояний «есть материал» от «есть подтверждённый профиль».

---

## Четыре состояния

| Состояние | Файл на диске | Frontmatter `status:` | Кто читает | Когда возникает |
|---|---|---|---|---|
| **none** | (нет файла) | — | — | До первой работы со стилем; либо после выбора метки B3 на `/bookbench:start` |
| **draft** | `.book/context/voice-profile.md.draft` | `status: draft` | НИКТО (субагенты ИГНОРИРУЮТ) | Коуч-агент сохранил готовый файл автора (из присланного `voice-profile.md` или эквивалента) ИЛИ автор начал ручной набросок |
| **confirmed** | `.book/context/voice-profile.md` | `status: confirmed`, `approved_by: author`, `approved_at: <ISO 8601>` | Все субагенты, которым нужен голос (writer, editor, marketer) | После прохождения `/bookbench:voice-build` или `/bookbench:voice-build --from-staged` с явным подтверждением автора |
| **calibrating** | `.book/context/voice-profile.md` | `status: calibrating` | НИКТО | Writer на первой секции обнаружил расхождение, инициировал ревизию; прежняя версия сохранена как `voice-profile.confirmed.<timestamp>.md` |

---

## Контракт чтения для субагентов

**MUST для всех 9 субагентов, которые читают `voice-profile.md`** (минимум `book-writer`, `book-editor`; также `book-marketer` через ту же логику):

Перед чтением `voice-profile.md`:
1. Read `.book/context/voice-profile.md` (если существует).
2. Извлечь поле `status:` из frontmatter.
3. **Если `status` равен `draft` или `calibrating` — НЕ читать тело файла, обращаться с профилем как с состоянием `none` (TOV-08 gate в writer срабатывает).**
4. **Если `status` равен `confirmed` — использовать тело файла.**
5. **Если файла нет, или есть только `voice-profile.md.draft` — обращаться как с `none`.**

Эта проверка дублируется в MUST-блоке тел `book-writer.md` и `book-editor.md` (этап 24, T4).

---

## Frontmatter-схема

### State `draft`

```yaml
---
status: draft
created_by: book-coordinator-coach   # /bookbench:start или ручное создание автором
created_at: 2026-05-10T09:00:00Z
source_kind: imported_voice_profile_file | imported_brief_section | author_handwritten
source_pointer: optional path to original document
note: "Этот файл — черновик. Субагенты его не читают. Запусти /bookbench:voice-build для подтверждения."
---
```

### State `confirmed`

```yaml
---
status: confirmed
approved_by: author
approved_at: 2026-05-10T10:00:00Z
created_by: voice-builder
schema_version: 1
---
```

### State `calibrating`

```yaml
---
status: calibrating
calibrating_since: 2026-05-10T11:00:00Z
calibrating_reason: "writer detected mismatch on section 1: <details>"
previous_confirmed_snapshot: voice-profile.confirmed.2026-05-10T10-00-00Z.md
---
```

---

## Переходы состояний

```
none ──/bookbench:voice-build──▶ confirmed
none ──coach saves draft──▶ draft
draft ──/bookbench:voice-build──▶ confirmed
confirmed ──writer detects mismatch──▶ calibrating
calibrating ──author confirms re-build──▶ confirmed
```

Откат `confirmed → none` возможен только через явное удаление файла автором.

---

## Что коуч-агент `/bookbench:start` НЕ делает

- **NEVER** записывает `voice-profile.md` без суффикса `.draft` (только если файл уже подтверждён автором — тогда команда `/bookbench:voice-build` сработает в режиме ratify-existing).
- **NEVER** извлекает 6 параметров voice-profile из черновика книги или брифа автора и сохраняет их в `voice-profile.md` со `status: confirmed`.
- **NEVER** записывает `voice-samples.md` напрямую в `.book/agent-guidelines/writer/`. Только в `.book/inputs/staged-voice-samples/`. Перенос — после явного подтверждения автора.
- **NEVER** помечает метку пути как `B1-confirmed` только потому, что в импортированных файлах есть тексты в стиле автора. Для этого требуется явное подтверждение, что эти тексты — целевой голос (а не черновик, который автор как раз хочет переделать).

---

## Что делает `/bookbench:voice-build`

При вызове без параметров:
- Если есть `voice-profile.md.draft` — предлагает «ratify-existing»: автор просматривает черновик, согласует / правит, файл переименовывается в `voice-profile.md` со `status: confirmed`.
- Если черновика нет — обычный диалог 6 параметров.

При вызове с `--from-staged` (этап 24, T4):
- Проверяет наличие `.book/inputs/staged-voice-samples/<slug>.md`.
- Использует тексты из staging как стартовый материал, но через нормальный диалог с автором (не безмолвная экстракция).
- Финал — `voice-profile.md` со `status: confirmed`.

---

## Связь с другими документами

- `templates/agent-guidelines/writer/voice-samples.md` — заполняется только из `confirmed` статуса; на `/bookbench:start` сюда **не** записывается.
- `agent-templates/book-writer.md` — содержит TOV-08 gate; обновлён в этапе 24 чтением `status:` перед использованием профиля.
- `agent-templates/book-editor.md` — обновлён аналогично в этапе 24.
- `commands/voice-build.md` — реализует переходы `draft → confirmed` (через ratify-existing) и `none → confirmed`. Этап 24 добавляет `--from-staged`.
- `commands/start.md` — Step 6a и Step 4 § 5 коуч-промпта работают по правилам этого документа.

---

*Создан: 2026-05-10 (этап 24, T4).*
*Связан с: D-35 (voice-profile lifecycle), TOV-08 (writer gate, усилен через lifecycle).*
