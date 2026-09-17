---
name: Link HR
description: iOS HR app for companies in Kazakhstan. White surfaces, Telegram-like blue, Phosphor icons, a floating pill navigation.
colors:
  ground: "#F5F8FC"
  surface: "#FFFFFF"
  surface-alt: "#F0F5FB"
  line: "#E1E9F2"
  ink: "#122033"
  ink-2: "#43546A"
  ink-3: "#66788E"
  ink-4: "#B8C5D3"
  blue: "#3390EC"
  blue-pressed: "#2481CC"
  blue-soft: "#E8F3FD"
  blue-glow: "#CFE6FB"
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
  nav-bar: "floating white pill, 16px from the bottom edge, 5 round 48px icon buttons, active = filled blue circle with white icon, soft shadow"
  primary-button: "blue pill, 48px tall, white 15px/500 label"
  clock-button: "round 200px blue disc with a soft blue halo, hand/tap icon + label, pulses while waiting"
  status-pill: "rounded tinted pill, 12px text: orange = in progress, red = on hold/overdue, gray = backlog, blue = done"
  stat-tile: "white 18px card, number 22px/600 on top, 13px gray label, small line icon top-right"
---

# Link Design System

## 1. Direction

**Scene:** сотрудник открывает Link утром у входа в офис, быстро видит статус рабочего дня, подтверждает местоположение на карте и делает селфи. Позже он же открывает задачи, документы или баллы без разных стилей и технических деталей.

**Color strategy: restrained blue.** Интерфейс светлый и чистый. Синий — единственный акцент для главного действия, активной вкладки, ссылок и состояния выбора. Он не используется как украшение.

**References:**
1. *Today's Summary* HR concept (light): светлая палитра, плавающая нижняя панель, круглая кнопка отметки, рамка селфи и строгие иконки.
2. *Disciplinary in your hand*: только структура данных, 2×2 показатели, задачи с прогрессом и журнал посещаемости. Тёмная тема и мятный цвет не используются.

Логотип Link — синий скруглённый знак с белой иконкой цепочки. Он используется на входе и экране загрузки.

## 2. Palette

| Token | Hex | Role |
|---|---|---|
| background | #F5F8FC | основной фон экрана |
| surface | #FFFFFF | cards, nav pill, sheets |
| surface-alt | #F0F5FB | неактивные иконки и мягкие блоки |
| line | #E1E9F2 | тонкие разделители |
| ink | #122033 | заголовки, значения и основные иконки |
| ink-secondary | #43546A | вспомогательный текст |
| ink-muted | #66788E | подписи и даты |
| blue | #3390EC | главное действие, активная вкладка и ссылки |
| blue-pressed | #2481CC | нажатие и сильное состояние действия |
| blue-soft | #E8F3FD | мягкий фон выбора и успеха |
| blue-glow | #CFE6FB | ореол круглой кнопки отметки |
| amber / red | #D9822B / #D94545 | предупреждение, опоздание, ошибка, отказ |

Правила: на обычном экране не больше одного синего заполненного действия, кроме активной вкладки. На синем фоне всегда белый текст или иконка. Технические названия, URL, API и платформа не показываются пользователю.

## 3. Logo and typography

- Логотип: синий квадрат со скруглением 26% стороны и белой иконкой цепочки.
- Один шрифт, **Onest**, веса 400, 500, 600 и 700. Крупный заголовок 32px/600, заголовок экрана 22px/600, текст 15px/400, подписи 12–13px/400.
- Время, суммы, баллы и проценты используют табличные цифры.

## 4. Layout, navigation and elevation

- Боковые поля 20px, между смысловыми секциями 28px, внутри карточки 16px.
- Карточки белые, радиус 18px, без декоративной рамки и без обычной тени. Тень допустима только у плавающей нижней панели и круглой кнопки отметки.
- Нижняя панель — белая плавающая капсула в 16px от нижнего края: Главная, Посещаемость, Задачи, Сервисы, Профиль. Активная кнопка — синий круг с белой залитой Cupertino-иконкой. Неактивные — спокойные контурные Cupertino-иконки без отдельных фоновых кругов.
- Содержимое прокручивается под панелью с нижним отступом 120px.

## 5. Components

- **Главная:** приветствие, уведомления, аватар, карточка прихода/ухода, показатели за день, статусы заявок, задачи и последние отметки.
- **Посещаемость:** полоса недели, круглая синяя кнопка «Отметиться» или «Уйти», время, расстояние до офиса, показатели, журнал, табель, статистика и баллы.
- **Отметка:** нажатие → карта и GPS-проверка → селфи только фронтальной камерой → сохранение отметки вместе с селфи. Галерея и файлы отсутствуют. Если селфи невозможно сделать, отметка не сохраняется.
- **Задачи, сервисы и профиль:** все уже существующие возможности остаются доступны в том же визуальном языке.
- **Баллы:** показывают итог за период и понятные причины начисления или списания рядом со статистикой.

## 6. Do's and Don'ts

Do:

- Сохранять все уже существующие функции и навигационные пути.
- Показывать реальные данные backend, а не заменять их макетом.
- Использовать карту до селфи и селфи до записи отметки.
- Поддерживать единые размеры, отступы, иконки и синий акцент на всех экранах.

Don't:

- Не использовать тёмную тему, мятный цвет, градиенты, стекло и декоративные полосы.
- Не показывать пользователю URL, API, Frappe, сервер и прочие технические термины.
- Не давать загрузить фото отметки из галереи или файлов.
- Не создавать новый экран, если нужная функция уже есть в текущем приложении.
