---
name: Link HR
description: iOS HR app for companies in Kazakhstan. White surfaces, one deep green, a floating pill navigation.
colors:
  ground: "#F4F5F4"
  surface: "#FFFFFF"
  surface-alt: "#F7F8F7"
  line: "#E9EBEA"
  ink: "#141816"
  ink-2: "#4A514D"
  ink-3: "#6E7571"
  ink-4: "#BFC5C2"
  green: "#0F8A62"
  green-pressed: "#0B6F4F"
  green-soft: "#E6F4EE"
  green-glow: "#BFE6D6"
  orange: "#D9822B"
  orange-soft: "#FDF0E1"
  red: "#D94545"
  red-soft: "#FCEBEB"
  gray-pill: "#EEF0EF"
  camera: "#0C0F0E"
typography:
  family: "Onest (bundled; weights 400, 500, 600, 700)"
  display: { size: 32px, weight: 600, lineHeight: 1.1, letterSpacing: -0.6px }
  title: { size: 22px, weight: 600, lineHeight: 1.2, letterSpacing: -0.3px }
  heading: { size: 18px, weight: 600, lineHeight: 1.25 }
  card-title: { size: 16px, weight: 500, lineHeight: 1.3 }
  body: { size: 15px, weight: 400, lineHeight: 1.45 }
  label: { size: 13px, weight: 400, lineHeight: 1.35 }
  caption: { size: 12px, weight: 400, lineHeight: 1.3 }
  number: { size: 15px, weight: 500, tabular: true }
  clock: { size: 28px, weight: 600, tabular: true }
rounded:
  card: 18px
  tile: 14px
  field: 12px
  pill: 999px
spacing:
  gutter: 20px
  card-padding: 16px
  section-gap: 28px
components:
  nav-bar: "floating white pill, 16px from the bottom edge, 5 round 48px icon buttons, active = filled green circle with white icon, soft shadow"
  primary-button: "green pill, 48px tall, white 15px/500 label"
  clock-button: "round 200px green disc with a soft green halo, hand/tap icon + label, pulses while waiting"
  status-pill: "rounded tinted pill, 12px text: orange = in progress, red = on hold/overdue, gray = backlog, green = done"
  stat-tile: "white 18px card, number 22px/600 on top, 13px gray label, small line icon top-right"
---

# Link HR Design System

## 1. Overview: One Green Button

**Scene:** an office employee in Almaty opens the app at 08:55 standing at the entrance, phone in one hand, bright daylight or office light, in a hurry to get marked on time; an HR manager later scrolls the same app at a desk between meetings.

That scene decides everything: a light UI that reads in daylight, one unmistakable green action ("Отметиться"), numbers big enough to read at a glance, and everything else quiet.

**Color strategy: Restrained.** Near-white neutrals tinted a hair toward the green, one deep green accent used only for the primary action, the active tab and success states. Orange and red exist only inside status pills and warnings.

**References:**
1. *Today's Summary* HR concept (light, green): screen language, floating pill nav, round clock-in button, selfie capture frame. This is the primary reference for color, nav and icons.
2. *Disciplinary in your hand* attendance concept (dark, mint): information structure only (2×2 attendance tiles, today tasks with progress, attendance list, week strip). Its dark theme and mint color are not used.

The previous graphite/blue Beepro-like direction is retired.

## 2. Colors

| Token | Hex | Role |
|---|---|---|
| ground | #F4F5F4 | screen background behind cards |
| surface | #FFFFFF | cards, nav pill, sheets |
| ink | #141816 | titles and values |
| ink-2 | #4A514D | secondary text (≥ 7:1 on white) |
| ink-3 | #6E7571 | captions, labels (≥ 4.6:1 on white) |
| green | #0F8A62 | primary buttons, active tab, clock button, links |
| green-soft | #E6F4EE | selected chips, success pill background |
| orange / red | #D9822B / #D94545 | lateness, on-hold, overdue, errors; only in pills, banners and text |

Rules: green never decorates. A screen has at most one filled green button besides the active tab. Gray text is never placed on green; on green use white.

## 3. Typography

One family, **Onest**, bundled with the app (strong Cyrillic, calm geometric shapes). Hierarchy comes from size and weight (400 / 500 / 600), not from color. Large greeting titles ("Сводка за сегодня") use `display` split over two lines like the reference. Times and counts use tabular figures.

## 4. Layout and Elevation

- 20px side gutter, 28px between sections, section header = `heading` left + "Все" link right in green.
- Cards: white, 18px radius, no border, a very soft shadow (0 2 12 rgba(20,24,22,0.04)). Ground is visible between cards.
- The nav pill and the clock button are the only elements with a noticeable shadow.
- Content scrolls under the floating nav; lists get 110px bottom padding so the last row is reachable.

## 5. Components

- **Floating nav pill:** Дом (сводка) · Часы (посещаемость и отметка) · Список (задачи и доска) · Папка (сервисы: документы, заявки, отпуска, ЗП, анализ, чеклисты, достижения, оповещения) · Шестерёнка (профиль и настройки). Notifications open from the bell on Home.
- **Home "Сводка за сегодня":** date + greeting, bell, avatar; clock card (Приход / Уход / green "Отметиться"); 2×2 tiles (пришёл, ушёл, вовремя %, дней на работе); Статус заявок (всего / одобрено / отклонено); Задачи (cards with status pill, time, progress); Последние отметки.
- **Attendance screen:** week strip, big round green "Отметиться" / "Уйти" button with halo, live clock, office distance line ("До офиса 120 м" / "Вы должны быть рядом с офисом"), stats row (Приход, Уход, Часы, Перерыв), month selector, attendance log table, табель and statistics below.
- **Check-in flow:** tap the round button → map + geofence check (existing) → **selfie screen** (front camera only, dark full-screen preview, white corner frame, round back button, green round capture button) → the check-in is saved with the selfie attached. No gallery, no file picker.
- **Status pills:** backlog gray, in progress orange, on hold red, done green.
- **Premium lock:** same empty-state pattern, green outline button "Узнать о Premium".

## 6. Do's and Don'ts

Do:
- Keep one green primary action per screen.
- Show real numbers first (times, days, %), labels second.
- Keep every existing feature reachable within two taps from a tab.

Don't:
- No dark theme, no mint, no gradients on cards, no glass.
- No uppercase tracked eyebrows, no colored side stripes.
- No gallery or file upload in the check-in flow.
- No gray text on green.
