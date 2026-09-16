---
name: Link
description: Native iOS HR app for Kazakhstan companies. Kanji visual language, Beepro screen structure.
colors:
  ground: "#F5F6F8"
  surface: "#FFFFFF"
  surface-alt: "#F7F8FA"
  line: "#E8EAEE"
  ink: "#1B1D23"
  ink-2: "#4F535D"
  ink-3: "#737884"
  ink-4: "#C3C6CD"
  graphite: "#3D4047"
  accent: "#2F6FED"
  accent-soft: "#EAF1FE"
  green: "#34B35A"
  green-deep: "#1F8A45"
  green-soft: "#E8F6EC"
  orange: "#E8832A"
  orange-soft: "#FFF2E5"
  warn: "#F2C94C"
  warn-soft: "#FFF8E1"
  plum: "#7B5CD6"
  red: "#E5484D"
  red-soft: "#FDECEC"
  chip: "#EDEEF1"
typography:
  display:
    fontFamily: "SF Pro Display, system-ui"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1.15
    letterSpacing: "-0.6px"
  title:
    fontFamily: "SF Pro Display, system-ui"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  heading:
    fontFamily: "SF Pro Text, system-ui"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.25
  card-title:
    fontFamily: "SF Pro Text, system-ui"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "SF Pro Text, system-ui"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "SF Pro Text, system-ui"
    fontSize: "12.5px"
    fontWeight: 500
    lineHeight: 1.35
  caption:
    fontFamily: "SF Pro Text, system-ui"
    fontSize: "11.5px"
    fontWeight: 500
    lineHeight: 1.3
rounded:
  pill: "7px"
  field: "12px"
  tile: "16px"
  card: "20px"
  sheet: "28px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "22px"
components:
  button-primary:
    backgroundColor: "{colors.graphite}"
    textColor: "{colors.surface}"
    rounded: "10px"
    height: "48px"
  button-success:
    backgroundColor: "{colors.green-deep}"
    textColor: "{colors.surface}"
    rounded: "10px"
    height: "48px"
  button-outline:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "10px"
    height: "48px"
  icon-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "999px"
    size: "40px"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.card}"
    padding: "16px"
  field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    height: "46px"
  status-pill-done:
    backgroundColor: "{colors.green-deep}"
    textColor: "{colors.surface}"
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
  status-pill-progress:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
  status-pill-hold:
    backgroundColor: "{colors.graphite}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
  nav-item-active:
    backgroundColor: "{colors.ground}"
    textColor: "{colors.graphite}"
    rounded: "{rounded.tile}"
    size: "52px x 38px"
---

## 1. Overview: Quiet Porcelain, Busy Day

Link is the phone an employee checks between tasks: at the entrance to mark arrival, in a corridor to take a task, at the end of the day to close it. Screens are compact and dense, like Beepro, and read calm, like the Kanji task-management shot: porcelain ground, white cards, three status voices.

Two references are fixed and govern every new screen:

- **Style: Kanji Task Management (Dribbble).** White rounded cards on light grey, round white icon buttons, count chips `(2) Completed`, day circles in green / violet / black, overlapping avatars with `2+`, subtask checkboxes, violet file discs.
- **Structure: Beepro.** Header with avatar, `отдел | должность` and a points bar; KPI strip `Присутствие | Отсутствие | Опоздание`; underline tabs `Link Time · Статистика · Табель · Баллы`; board of person bubbles in four quadrants; bottom-sheet task card; voice task form; checklist with ✓ / ✗; documents with PDF preview and signing; announcement form; discipline analysis; achievement pop-ups.

Navigation is five icons without labels: Главная · Доска · Сервисы · Оповещения · Профиль (avatar).

Roles decide what exists, never what it looks like:

| Surface | Employee | Manager (HR Manager, HR User, System Manager) |
|---|---|---|
| Главная, Доска, чек-ин, запросы | yes | yes |
| Create tasks, assign executors and reviewer | yes | yes |
| Checklists | today and history | plus templates and "+" |
| Оповещения | read and acknowledge | plus "+" to send |
| Документы | own documents, sign | all documents, create, send for signature |
| Анализ | hidden | visible in Сервисы |

## 2. Colors: Graphite, Blue, Traffic Light

Changed from the first Kanji violet palette to the Beepro-like one the team approved on screenshots. White screens, graphite actions, one blue accent, traffic-light statuses.

- **Graphite** `graphite`: primary buttons, bell, active tab underline, FAB, active navigation icon.
- **Blue** `accent`: links, "Далее", switches, totals, "Посмотреть график", today in the табель.
- **Green** `green` / `green-deep`: on time, done, paid, "Выполнено" quadrant border.
- **Orange** `orange`: lateness ("Опоздание 1 ч 2 мин" with a clock), weekends in the табель.
- **Yellow** `warn`: warning banners ("Чеклист нельзя завершить без фото-отчёта").
- **Plum** `plum`: achievements only (pink card, medal, progress).
- **Red** `red`: absence, overdue, errors, destructive actions, score badge in Анализ.
- Points bar is the only gradient: yellow to green.

## 3. Typography: One Family, Small Steps

SF Pro only, weight contrast over size contrast. The scale is deliberately compact (users complained that 17px body felt oversized):

display 26 · title 20 · heading 17 · card-title 15 · body 14 · label 12.5 · caption 11.5. Numbers and times use tabular figures. Sentence case everywhere; uppercase only on the achievement card label.

## 4. Elevation

Flat. Depth comes from white-on-grey, not shadows. Exceptions: the board FAB and the recording bar carry one soft shadow (`0 8px 18px rgba(0,0,0,.2)`), bottom sheets use the system scrim. Motion lives here too: lists `Reveal` with a 14px rise and 45ms stagger, bubbles and medals scale from 0.82, charts draw left to right, numbers count up, tabs cross-fade; 140-420ms, ease-out-quart, no bounce, all skipped under Reduce Motion.

## 5. Components

- **Screen header:** plain arrow on the left, title 17/500 centred; root tabs use a left title 24.
- **Form labels:** uppercase 11.5px, tracking 0.3, grey, above every field (Beepro form grammar, used only in forms).
- **Подсчёт ЗП (managers):** month link, search, department pill, blue total, table СОТРУДНИК / Фикс оклад / Часы факт, paid chip; employee page with type, оклад, бонус, удержание, ставка, часы план/факт.
- **Check-in sheet:** map on top, «Проверяем ваше местоположение», three pulsing dots, graphite «Я на работе».
- **Header (Home):** avatar 54, name `card-title`, role `caption`, points bar 14px yellow-to-green with the score, charcoal bell 34.
- **KPI strip:** white card, three columns split by hairlines, label `caption`, value 18/500.
- **Underline tabs:** 13px, active ink with a 28px charcoal underline.
- **Plan row (Link Time):** 22px check circle (green done, violet late), title `body-strong`, meta `caption`, small grey chip "Выполнить".
- **Board quadrant:** white cell with hairline border, title centred; "Выполнено" gets a green border and archive icon. Bubble: 46 avatar, 20px badge (play = voice, bubble = text, check = done), stage ring green / violet / red overdue.
- **Task sheet:** title, stage chip, reviewer row, voice player (play ring + waveform + `00:00:08`), text box, author / executor rows, due date, one primary action per stage.
- **Task form:** voice field, text, dashed "Файл или фото", dashed "Добавить подзадачу", deadline tiles Сегодня / Неделя / Бэклог / Другое (charcoal when selected), Исполнители and Проверяющий cards opening the people sheet (Отмена · title · Далее, search, frequent first).
- **Табель grid:** square cells, day number top-left, status icon top-right, lateness bottom-left; floating violet "Посмотреть график".
- **Documents row:** blue doc icon, title, subtitle, `Тип: …`, soft status tag with icon (Подпишите, Ожидается, Черновик, Готово, Закрыт).
- **Buttons:** 48px, radius 16; icon buttons 40px circles; fields 46px, radius 12.

## 6. Do's and Don'ts

- **Do** keep screens compact: 16px page padding, 12px row rhythm, 48px buttons.
- **Do** hide what a role cannot do instead of disabling it.
- **Do** write labels as a person would say them: "Взять в работу", "Ознакомлен", "Подписать документ".
- **Don't** show technical data: e-mails as subtitles, document IDs, task codes, coordinates, field names, doctype names.
- **Don't** add explanatory captions about how the system works; the screen should make it obvious.
- **Don't** nest cards, use side-stripe borders, gradient text or glass.
- **Don't** raise type above the scale; if something feels unimportant, make it lighter, not smaller than 11.5.
