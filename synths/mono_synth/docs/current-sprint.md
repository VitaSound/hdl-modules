# Sprint mono-2026-07-10-a

Агент начинает работу с этого файла. Не брать задачи вне текущего спринта без явного обновления этого файла пользователем.

- goal: создать agent-facing документацию `mono_synth`, чтобы AI работал внутри архитектуры проекта
- started: 2026-07-10
- agent_context: один агент, один фокус, один набор документационных изменений
- backlog_ref: [`../../../docs/TODO.md`](../../../docs/TODO.md)

## Задачи Текущего Спринта

| priority | id | title | status |
|----------|----|-------|--------|
| P0 | `mono-doc-001` | Agent-facing documentation suite | done |
| next | `mono-001` | Soft Hello reconnect | backlog |

Допустимые статусы: `backlog`, `ready`, `in_progress`, `blocked`, `done`, `cancelled`.

Правило для активного спринта: ровно одна задача `in_progress`. В закрытом спринте активных задач нет.

## Приоритеты

- **P0** — обязательно завершить в этом спринте.
- **P1** — можно брать только если P0 `done` или `blocked` с причиной.
- **P2** — stretch / optional; не брать без подтверждения.

В текущем спринте P1/P2 нет. Кодовые задачи, включая `mono-001`, не входят в scope.

## Completed: mono-doc-001

- status: done
- priority: P0
- owner: agent
- started: 2026-07-10
- completed: 2026-07-10
- type: documentation

### Files In Scope

- `synths/mono_synth/docs/architecture.md` — create
- `synths/mono_synth/docs/schema.md` — create
- `synths/mono_synth/docs/edge-cases.md` — create
- `synths/mono_synth/docs/links.md` — create
- `synths/mono_synth/docs/current-sprint.md` — create
- `synths/mono_synth/docs/techstack.md` — create
- `synths/mono_synth/README.md` — refactor to index + runbook
- `docs/TODO.md` — add `mono-00x` ids and sprint link
- `AGENTS.md` — add short pointer to mono_synth docs

### Files Explicitly Out Of Scope

- `synths/mono_synth/top.sv`
- `synths/mono_synth/synth_core.cpp`
- `synths/mono_synth/main.cpp`
- `vst_bridge/*`
- `hdl-modules-tester/*`
- `mono_voice/*`
- `modules.yaml`

## Ограничения

- Только документация; без RTL/C++/VST правок.
- Не запускать `make all` и не менять generated README библиотечных пакетов.
- Не трогать `modules.yaml`.
- Не коммитить и не чистить `obj_dir/` в рамках этой задачи.
- `AGENTS.md` менять минимально: только указатель на новые docs.
- Если обнаружено расхождение docs vs код, зафиксировать в docs как caveat, не править код в этом спринте.

## Ожидаемый Результат

### Done When

- [x] `synths/mono_synth/docs/architecture.md` создан
- [x] `synths/mono_synth/docs/schema.md` создан
- [x] `synths/mono_synth/docs/edge-cases.md` создан
- [x] `synths/mono_synth/docs/links.md` создан
- [x] `synths/mono_synth/docs/current-sprint.md` создан
- [x] `synths/mono_synth/docs/techstack.md` создан
- [x] `synths/mono_synth/README.md` стал index + runbook
- [x] `docs/TODO.md` содержит `mono-001` ... `mono-007` и `mono-doc-001`
- [x] `AGENTS.md` указывает на `current-sprint.md`, `architecture.md`, `schema.md`, `edge-cases.md`, `links.md`
- [x] Перекрёстные ссылки проверены
- [x] `mono-doc-001` можно перевести в `done`

## Next Sprint Candidate

| id | title | why next |
|----|-------|----------|
| `mono-001` | Soft Hello reconnect | Убрать лишний `rst` при reconnect того же `plugin_ssrc` |

Перед кодовым спринтом открыть [`architecture.md`](architecture.md), [`schema.md`](schema.md), [`edge-cases.md`](edge-cases.md) и [`links.md`](links.md).
