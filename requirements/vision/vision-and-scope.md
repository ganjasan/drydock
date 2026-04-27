---
title: "Drydock Vision and Scope"
version: "0.2.0"
created: 2026-04-24
updated: 2026-04-27
status: draft
---

# Vision and Scope Document

**Проект:** Drydock — A disciplined, AI-first development loop for Claude Code
**Версия:** 0.1.0
**Дата:** 24.04.2026
**Автор:** Artem Konuchov
**Статус:** Черновик

**История изменений:**

| Версия | Дата       | Автор          | Описание изменений                                                    |
|--------|------------|----------------|-----------------------------------------------------------------------|
| 0.1.0  | 24.04.2026 | Artem Konuchov | Первоначальная версия — выделение универсального ядра из APZ-плагина |
| 0.2.0  | 27.04.2026 | Artem Konuchov | Расширение workflow до пяти фаз (`raw → req → plan → build → ship`); полная ликвидация APZ; добавлены extension model и план четырёх OpenSpec changes (см. ADR-0004) |

---

## 1. Business Requirements (Бизнес-требования)

### 1.1 Background and Strategic Opportunity

Автор (Artem Konuchov) разрабатывает программные продукты преимущественно с помощью Claude Code. За последний год сложился устойчивый, повторяющийся рабочий процесс — от формулировки бизнес-требований по Вигерсу до релиза по OpenSpec-модели, — оформленный в внутренний плагин **APZ** (внутри группы Apilize). APZ содержит команды `/apz:req:*` (requirements), `/apz:build:*` (build-loop), `/apz:ship:*` (PR/archive/release), набор скиллов, шаблонов и sub-агентов.

Опыт показал две вещи:

1. **Методология работает** на проектах разной природы (SaaS, инфраструктура, исследования), а не только в доменах Apilize.
2. **APZ-плагин перегружен Apilize-специфичными предположениями** — названиями репозиториев, путями, ссылками на внутренние проекты GitHub, ссылками на клиентский контент. Его нельзя просто «взять и использовать» в стороннем проекте.

Появилась возможность выделить универсальное ядро методологии и инструментов в самостоятельный продукт под новым именем. Это даёт:

- Чистую opensource-артефакт, не привязанный к Apilize.
- Отдельный жизненный цикл и версионирование.
- Возможность применять в любых проектах автора, включая FASTSAAS и будущие SaaS.
- Основу для дальнейшего опенсорс-распространения среди Claude Code community.

**Почему сейчас:** экосистема Claude Code (plugins, skills, agents, MCP) стабилизировалась; параллельно разрабатывается FASTSAAS, который хочет «приходить в новый проект вместе с методологией». Универсальный плагин нужен FASTSAAS (FE-CORE-11) как зависимость, и это дополнительный драйвер.

### 1.2 Business Opportunity

Drydock — самостоятельный, универсальный Claude Code плагин и методология разработки, реализующий цикл Req → Build → Ship с акцентом на трассируемость и дисциплину.

**Для кого создаётся:**

- **Первичный пользователь:** автор — для собственных SaaS-проектов и экспериментов, требующих строгой трассируемости требований и изменений.
- **Вторичная аудитория:** solo-developer'ы и маленькие команды, использующие Claude Code как основной инструмент и желающие перейти от хаотичного «vibe coding» к повторяемому процессу.
- **Третичная аудитория:** консультанты/менторы, которые могут использовать Drydock как учебный инструмент для демонстрации инженерной дисциплины в AI-ассистированной разработке.

### 1.3 Business Objectives and Success Criteria

| ID   | Бизнес-цель                                                                                                | Критерий успеха                                                                                                          | Срок          |
|------|------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|---------------|
| BO-1 | Извлечь универсальное ядро APZ в самостоятельный плагин Drydock                                         | Все Apilize-специфичные ссылки удалены; миграционный гайд для APZ → Drydock написан и проверен на реальном переносе  | Релиз v0.1    |
| BO-2 | Drydock работает «из коробки» в новом проекте без ручной конфигурации                                   | `git clone drydock` + установка плагина → доступны `/dd:req:*`, `/dd:build:*`, `/dd:ship:*` в любом проекте           | Релиз v0.1    |
| BO-3 | Репозиторий сам следует своей методологии (dogfooding)                                                     | Все изменения после v0.1 идут через OpenSpec-changes; все фичи имеют трассировку в ADR/Vision; 100 % требований в `requirements/` | Релиз v0.1 и далее |
| BO-4 | Drydock становится рабочей зависимостью FASTSAAS                                                        | FASTSAAS успешно использует Drydock как CORE-модуль (FE-CORE-11 в FASTSAAS VnS); команды работают в FASTSAAS-проекте | +1 мес от v0.1|
| BO-5 | Достичь органической видимости среди Claude Code community                                                 | ≥ 100 GitHub stars и ≥ 5 внешних проектов, использующих плагин                                                          | +6 мес от v0.1|
| BO-6 | Drydock покрывает полный жизненный цикл от внешнего сигнала до релиза в любом проекте автора без модификации кода плагина | Все четыре v0.2-change'а (`drydock-extension-model`, `add-raw-phase`, `config-driven-paths-and-gates`, `retire-apz`) реализованы и заархивированы; APZ-плагин удалён; Apilize-репозитории работают только через `<repo>/.drydock/` overlay; FASTSAAS использует тот же extension model | Релиз v0.2 |

> *Assumption: BO-5 предполагает публичный репозиторий под MIT. Если плагин остаётся личным — цель снимается.*

### 1.4 Customer or Market Needs

1. **«Мой Claude Code workflow разбросан».** У автора APZ-плагин, у других — набор ad-hoc промптов, у третьих — ничего. Нужен публичный эталон, на который можно опереться.
2. **«Я теряю трассируемость от требования до кода».** Без структуры сложно отследить, какое требование породило ту или иную строку в кодовой базе.
3. **«Я хочу переиспользовать методологию между проектами».** Копировать руками — больно и расходится; нужен плагин, который можно подключить.
4. **«Apilize-специфика мешает открыть инструменты наружу».** Внутренняя терминология и пути делают плагин непригодным для чужих проектов.
5. **«AI-ассистированная разработка часто превращается в хаос».** Нужна дисциплина, которая не тормозит Claude Code, а наоборот — даёт ему опору.
6. **«Сигналы из внешних источников теряются между инструментами».** Письма, встречи, заметки в Notion, заявки в Linear — без структурированного приёма они не превращаются в требования. Нужен левый край петли — фаза `raw`, обрабатывающая входящие сигналы единообразно.
7. **«Каждый проект имеет свою специфику, но не должен форкать плагин».** Apilize Protocol-conformance, public-ready-guard, Gmail-фильтры под клиентов — это всё локальная специфика, которая должна жить в репо проекта, а не в коде плагина.

### 1.5 Business Risks

| ID   | Описание риска                                                                                                                       | Вероятность | Влияние | Стратегия                                                                                                   |
|------|--------------------------------------------------------------------------------------------------------------------------------------|-------------|---------|-------------------------------------------------------------------------------------------------------------|
| BR-1 | Двойная поддержка APZ и Drydock                                                                                                      | Н (после v0.2) | В    | В v0.2 APZ полностью ликвидируется (см. ADR-0004); Apilize-специфика мигрирует в `apilize-hub/.drydock/` через extension model. После завершения change'а `retire-apz` риск снимается полностью. |
| BR-2 | Эволюция Claude Code API (plugins, skills, agents) ломает плагин                                                                     | С           | В       | Минимизировать использование нестабильных API; CI-прогон на актуальной версии раз в неделю                |
| BR-3 | OpenSpec как основа build-loop меняет формат артефактов                                                                              | С           | С       | Изолировать OpenSpec-интеграцию в отдельный модуль; держать версию в зависимостях                         |
| BR-4 | Методология воспринимается как «слишком тяжёлая» для простых задач                                                                   | С           | С       | Ввести режимы: `/dd:build:ff` (fast-forward для тривиальных задач); документировать когда не использовать |
| BR-5 | Будущая коллизия имени: кто-то регистрирует `drydock` в npm/PyPI/крупной GitHub-организации раньше нас                                | Н           | С       | На момент ADR-0001 имя свободно (проверено). Зарегистрировать npm/PyPI-пакеты `drydock` одновременно с публикацией репозитория; fallback — `drydock-cc` или `drydock-claude` |

---

## 2. Vision of the Solution (Видение решения)

### 2.1 Vision Statement

**FOR** автора и других solo-developer'ов, работающих с Claude Code как основным инструментом
**WHO** хотят превратить «vibe coding» в дисциплинированный, повторяемый процесс с полной трассируемостью от внешнего сигнала до релиза
**THE** Drydock **IS A** универсальный Claude Code плагин и методология
**THAT** даёт готовый пятифазный цикл «Сигнал → Требование → План → Проект изменения → Код → Тесты → PR → Релиз» с командами `/dd:raw:*`, `/dd:req:*`, `/dd:plan:*`, `/dd:build:*`, `/dd:ship:*`, библиотекой скиллов/шаблонов/sub-агентов и тремя точками расширения внутри потребляющего репо (`<repo>/.drydock/config.yaml`, `<repo>/.drydock/hooks/`, `<repo>/.claude/commands/`)
**UNLIKE** ad-hoc промптов, внутренних плагинов, привязанных к конкретной компании (как APZ к Apilize), или тяжёлых корпоративных ALM-инструментов (Jira / Azure DevOps)
**OUR PRODUCT** лёгкий, opensource, domain-agnostic, интегрирован с Wiegers и OpenSpec, и применяется к своей же разработке (dogfooding).

### 2.2 Major Features

| ID      | Название фичи                      | Описание                                                                                                                  | Связанные BO |
|---------|------------------------------------|---------------------------------------------------------------------------------------------------------------------------|--------------|
| FE-1    | Command suite `/dd:req:*`          | Команды для requirements: vision, stakeholder, use-case, adr, review                                                      | BO-1, BO-2   |
| FE-2    | Command suite `/dd:build:*`        | Команды build-loop: start, explore, design, code, test                                                                    | BO-1, BO-2   |
| FE-3    | Command suite `/dd:ship:*`         | Команды ship: pr, archive, release                                                                                        | BO-1, BO-2   |
| FE-4    | Command suite `/dd:plan:*`         | Команды планирования: add, triage, promote (backlog → change)                                                             | BO-2         |
| FE-5    | Skill library                      | Вигерс-скиллы (vision-and-scope, use-case, stakeholder-profile, requirements-review, requirements-elicitation)           | BO-1         |
| FE-6    | Template library                   | Шаблоны документов: V&S, ADR, use-case, stakeholder profile, OpenSpec delta                                               | BO-1, BO-2   |
| FE-7    | Sub-agents                         | Специализированные агенты: code-reviewer, explorer, traces-linter, release-coordinator, raw-classifier                   | BO-2         |
| FE-8    | OpenSpec integration               | Встроенная поддержка OpenSpec changes/specs; команды `/dd:build:design` и `/dd:ship:archive` работают с `openspec/`      | BO-1, BO-2   |
| FE-9    | GitHub Projects integration (opt)  | Опциональная интеграция с GitHub Projects для backlog и трекинга — через `gh` CLI, universal (не Apilize Project #2)     | BO-2         |
| FE-10   | Dogfood requirements                | Собственные `requirements/` и `openspec/` этого репозитория                                                               | BO-3         |
| FE-11   | Migration guide APZ → Drydock   | `docs/migration-from-apz.md`: команды, пути, что менять при переходе                                                      | BO-1         |
| FE-12   | Installation & bootstrap            | `README`, `CLAUDE.md` и `.claude/` установочный скрипт, позволяющий подключить плагин в любой проект одной командой     | BO-2, BO-4   |
| FE-13   | Command suite `/dd:raw:*`          | Универсальный приём внешних сигналов: `capture`, `process`, `ingest-{gmail,calendar,drive,notion,linear,github}`, `transcribe`. Конвенция каталога `raw/_incoming/`, `raw/meetings/`, `raw/feedback/`, `raw/ideas/`, `raw/competitors/`. Источники и фильтры — через config | BO-1, BO-2, BO-4 |
| FE-14   | Extension model                    | Три точки расширения в потребляющем репо: декларативный `<repo>/.drydock/config.yaml`, императивные `<repo>/.drydock/hooks/`, и project-local `<repo>/.claude/commands/`. Документировано в `docs/extension-model.md` | BO-1, BO-2, BO-4 |
| FE-15   | Configurable release pipeline      | `release.gates` (список slash-команд, обязательных перед релизом), `area_to_repo` для multi-repo routing, multi-repo coordination через `release.repos` — всё declarative из config | BO-2, BO-4   |

### 2.3 Assumptions and Dependencies

**Допущения:**

- **AS-1:** Claude Code остаётся основным потребителем плагина; другие AI-coding-агенты (Cursor, Windsurf) — вне scope v0.1.
- **AS-2:** OpenSpec остаётся основой build-loop как наиболее подходящий формат для AI-ассистированных изменений.
- **AS-3:** Модель распространения — opensource MIT. *TBD: подтвердить.*
- **AS-4:** Пользователи имеют установленный `gh` CLI (для команд `/dd:plan:*` и `/dd:ship:pr`).

**Зависимости:**

- **DE-1:** Claude Code (актуальная версия) — plugin runtime, skills, agents.
- **DE-2:** OpenSpec CLI/формат.
- **DE-3:** `gh` CLI — для GitHub-интеграции.
- **DE-4:** Git.

---

## 3. Scope and Limitations (Границы и ограничения)

### 3.1 Scope of Initial Release (v0.1)

В v0.1 входит:

- **FE-1…FE-4** — полный набор команд `/dd:req:*`, `/dd:build:*`, `/dd:ship:*`, `/dd:plan:*` в объёме текущего APZ.
- **FE-5, FE-6, FE-7** — портированные скиллы, шаблоны, sub-агенты — без Apilize-специфики.
- **FE-8** — OpenSpec-интеграция.
- **FE-10** — собственные requirements/openspec Drydock.
- **FE-11** — migration guide.
- **FE-12** — README, CLAUDE.md, установка.

**FE-9 (GitHub Projects opt)** — в v0.1 включена только как «проверено, что не ломается без Apilize Project #2»; полноценная универсальная Projects-интеграция перенесена в v0.3 (v0.2 фокусируется на pentaphase workflow и extension model — см. Section 3.2).

**Ожидаемая дата релиза:** *TBD.*

### 3.2 Scope of Subsequent Releases

**v0.2 — Пятифазный workflow и проектные расширения** (зафиксировано в [ADR-0004](../adr/0004-universal-workflow-and-project-extensions.md), ожидается +1–2 мес):

Реализуется через четыре OpenSpec-change'а в указанном порядке:

1. **`drydock-extension-model`** — схема `<repo>/.drydock/config.yaml`, lifecycle hook-точки (`pre-pr`, `pre-release`, `post-capture`, …), контракт command-references из config (FE-14, FE-15); `docs/extension-model.md`.
2. **`add-raw-phase`** — поднять `/apz:raw:*` в `/dd:raw:*` (FE-13); перенос `raw-classifier` agent в drydock; обобщение Apilize-дефолтов в config-ключи.
3. **`config-driven-paths-and-gates`** — `release.gates`, `area_to_repo`, multi-repo coordination через config (FE-15); удаление оставшихся хардкодов путей в командах.
4. **`retire-apz`** *(в репо `apilize-hub`, не в drydock)* — удаление `apilize-hub/plugins/apz/`; создание `apilize-hub/.drydock/` overlay (config + hooks); перевод `conformance`/`parity` в `<repo>/.claude/commands/` соответствующих репо; полное переписывание `migration-from-apz.md` без секции «Stays in APZ».

Универсальная GitHub Projects integration (FE-9 full) переносится в v0.3.

**v0.3:**

- Универсальная GitHub Projects integration (FE-9 full) — поля Status / Priority / Phase / Area, project-board snapshot в `/dd:status` и `/dd:next`.
- Альтернативные back-end'ы для trackers: Linear, Notion (опционально, через adapter).
- Visual status dashboard (static HTML/Markdown-генерация из требований).
- Расширенные `/dd:build:*` сценарии (parallel-changes, semi-automated change merges).

**v1.0 (ожидается +6 мес):**

- Стабильный API плагина.
- Полная документация, примеры.
- Первые внешние контрибьюторы.

### 3.3 Limitations and Exclusions

Следующее **НЕ входит** в scope Drydock:

1. **Apilize-специфика и любая другая проектная специфика в коде плагина** — ссылки на apilize-hub, клиентские проекты, внутренние структуры, конкретные test-runner'ы (conformance/parity), guard-скрипты. Это всё переезжает в `<repo>/.drydock/` и `<repo>/.claude/commands/` потребляющих репо через extension model (FE-14). После v0.2 в коде самого плагина не должно остаться ни одного упоминания Apilize или клиентских доменов.
2. **Домен-специфичный контент** — финансовое моделирование, SaaS-бизнес-логика, конкретные вертикали.
3. **Собственный trackers-бэкенд** — Drydock не заменяет Linear, Jira, GitHub Projects; он их использует.
4. **IDE-интеграции помимо Claude Code** — Cursor, Windsurf, continue.dev — вне scope v0.x.
5. **Автоматическая генерация кода** без involvement пользователя — Drydock ассистирует, не автогенерирует фичи «сам по себе».
6. **Обучающий курс/книга** — методология задокументирована в `docs/`, но полноценного курса нет.
7. **Локализация команд** — названия команд и CLI-интерфейс только en; контент документов — по усмотрению автора.

---

## 4. Business Context (Бизнес-контекст)

### 4.1 Stakeholder Profiles

| Стейкхолдер                | Роль в проекте                   | Основные интересы                                                                                          | Уровень влияния |
|----------------------------|----------------------------------|------------------------------------------------------------------------------------------------------------|-----------------|
| Artem Konuchov             | Owner, первичный пользователь    | Универсальный, переиспользуемый workflow; dogfooding; чистое отделение от APZ                             | Высокий         |
| FASTSAAS как консумер       | Внутренний потребитель           | Drydock как CORE-модуль FASTSAAS; стабильность команд                                                  | Высокий         |
| Solo-developer (похожий)   | Вторичный пользователь           | Готовый workflow для Claude Code без необходимости разбираться в Apilize-специфике                        | Средний         |
| Claude Code / AI-агент     | Исполнитель команд плагина       | Предсказуемые конвенции; явные шаблоны; минимум неоднозначностей                                          | Средний         |
| OSS-сообщество             | Контрибьюторы / критики          | Качество кода, документация, лицензия                                                                     | Низкий — Средний|
| Anthropic / Claude Code team | Авторы платформы                  | Соответствие best practices Claude Code plugins; feedback как реального пользователя                      | Низкий          |

### 4.2 Project Priorities

| Измерение    | Ограничить | Оптимизировать | Принять |
|--------------|:----------:|:--------------:|:-------:|
| Schedule     |            |                |   ✓    |
| Features     |     ✓      |                |         |
| Quality      |            |       ✓        |         |
| Cost         |            |                |   ✓    |
| Staff        |     ✓      |                |         |

**Пояснение:**

- **Features — ограничить:** v0.1 = паритет с APZ минус Apilize-специфика; никаких новых фич.
- **Quality — оптимизировать:** плагин — визитная карточка методологии.
- **Staff — ограничить:** команда = 1 человек (+ AI-агенты).
- **Schedule / Cost — принять.**

### 4.3 Deployment Considerations

**Целевая среда:**

Drydock — Claude Code plugin. Установка: `claude plugin install <repo-url>` (или эквивалент актуальной версии Claude Code). После установки команды `/dd:*` доступны глобально.

**Миграция данных:**

Для существующих Apilize-проектов, использующих APZ — см. `docs/migration-from-apz.md` (соответствие команд, пути артефактов).

**Обучение и переход:**

- `README.md` — что это и с чего начать.
- `docs/methodology.md` — философия Req → Build → Ship.
- `docs/workflow.md` — подробный пошаговый workflow.
- `docs/skills-catalog.md` — что делает каждый скилл.
- `docs/migration-from-apz.md` — для пользователей внутреннего APZ.

---

## 5. Appendix (Приложения)

### 5.1 Глоссарий

| Термин               | Определение                                                                                                                            |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Drydock              | Claude Code plugin и методология разработки `Raw → Req → Plan → Build → Ship` (пятифазный workflow с v0.2).                            |
| APZ                  | Внутренний Apilize-Claude Code плагин, исторический предок Drydock. После v0.2 (см. ADR-0004) **полностью ликвидируется** — Apilize-специфика переезжает в `apilize-hub/.drydock/` и `<repo>/.claude/commands/`. |
| Raw → Req → Plan → Build → Ship | Пять фаз универсального workflow drydock с v0.2: приём внешних сигналов → требования → планирование → implementation loop → релиз. До v0.2 укороченная форма «Req → Build → Ship» использовалась для трёх правых фаз. |
| Pentaphase workflow  | Синоним «Raw → Req → Plan → Build → Ship». Используется в ADR-0004 и далее.                                                            |
| Extension model      | Три точки расширения drydock внутри потребляющего репо: декларативный `<repo>/.drydock/config.yaml`, императивные `<repo>/.drydock/hooks/`, и project-local `<repo>/.claude/commands/`. Зафиксировано в ADR-0004. |
| OpenSpec             | Формат/инструмент для описания изменений кодовой базы как артефактов (changes, deltas, specs).                                         |
| ADR                  | Architectural Decision Record — формат решения с контекстом, вариантами и последствиями.                                               |
| Dogfooding           | Использование собственного продукта для собственной разработки. Drydock разрабатывается с использованием Drydock.                |
| Vibe Coding          | Режим разработки, в котором значительную часть кодовой базы пишет/правит AI-агент; требует структурированной кодовой базы.             |

### 5.2 Связанные документы

| Документ                                             | Расположение                                                              |
|------------------------------------------------------|---------------------------------------------------------------------------|
| ADR-0001: Name (Drydock)                             | `requirements/adr/0001-name-drydock.md`                                |
| ADR-0002: Dogfooding as a principle                  | `requirements/adr/0002-dogfooding-as-principle.md`                        |
| ADR-0003: Raw/conformance/parity stay in APZ (superseded) | `requirements/adr/0003-raw-conformance-parity-stay-in-apz.md`        |
| ADR-0004: Universal workflow and project-local extensions | `requirements/adr/0004-universal-workflow-and-project-extensions.md` |
| Methodology overview                                 | `docs/methodology.md`                                                     |
| Workflow (Raw → Req → Plan → Build → Ship)           | `docs/workflow.md`                                                        |
| Skills catalog                                       | `docs/skills-catalog.md`                                                  |
| Extension model                                      | `docs/extension-model.md` *(планируется к v0.2)*                          |
| Migration guide APZ → Drydock                        | `docs/migration-from-apz.md` *(будет переписан в рамках `retire-apz`)*    |
| FASTSAAS Vision and Scope (консумер)                 | `../fastsaas/requirements/vision/vision-and-scope.md`                     |

---

*Документ подготовлен в соответствии с методологией: Wiegers, K., Beatty, J. «Software Requirements, 3rd Edition». Microsoft Press, 2013.*
