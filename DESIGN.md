# Design System: Kanji Task & HRMS

## Visual Language & Theme
- **Register**: Product (iOS HRMS & Task Management)
- **Base Backdrop**: `#F8F9FC` (Ultra-light clean porcelain)
- **Surface Cards**: `#FFFFFF` with border `1px solid #EFF2F6` and subtle shadow `Offset(0, 4), blur 16, color rgba(20, 24, 33, 0.04)`.
- **Card Border Radius**: `24px` (smooth continuous squircle-like corners).

## Color Palette
- **Primary / Completed**: `#4EBE71` (Vibrant Emerald Green) — used for "Completed" pill badges, active shift indicator, completed days on calendar.
- **Secondary / On Hold**: `#7052BA` (Deep Violet) — used for "On Hold" pill badges, vacation/leave indicators on calendar.
- **Accent Dark / Active Day**: `#1E1E2D` (Deep Slate Charcoal) — used for selected calendar day, primary headers, high-emphasis text.
- **In Progress / Indigo**: `#6558F5` / `#5C60F5` — used for in-progress tasks and active subtask checks.
- **Neutral Surface / Inactive Pill**: `#E9ECF2` / `#F1F3F7` with text `#4B5563`.
- **Text Primary**: `#0F172A` (Slate 900)
- **Text Secondary**: `#64748B` (Slate 500)
- **Text Tertiary / Muted**: `#94A3B8` (Slate 400)

## Typography
- **Font Family**: `.SF Pro Display` / `.SF Pro Text`
- **Headings**:
  - H1 / Hero: 24px, w800, letter-spacing -0.5px (`Monitor Current Performance`)
  - H2 / Screen Title: 20px, w700 (`Task`, `Task Details`)
  - H3 / Card Title: 16px, w700 (`Feature Prioritization`, `Wireframe Development`)
- **Body & Labels**:
  - Body: 14px, w400-w500, line-height 1.45
  - Captions / Dates: 12px, w500, color `#94A3B8` (`11/08/2024`, `Manage your task`)
  - Status Pills: 12px, w600 (`Completed`, `In Progress`, `On Hold`)

## Key Component Patterns (Pixel-Perfect from Reference)
1. **Header Bar**:
   - Avatar circle with status dot (top-left).
   - Search circle button + Bell notification circle button with unread dot (top-right).
2. **"My Activity" Calendar Widget**:
   - Month dropdown pill (`February ▼` / `Сентябрь ▼`).
   - 7 columns for weekdays (`Su Mo Tu We Th Fr Sa` or `Пн Вт Ср Чт Пт Сб Вс`).
   - Day badge types:
     - Other-month / inactive: faint dots or striped circles.
     - Regular day: light grey/slate circle with number.
     - Completed day: solid `#4EBE71` circle with white text.
     - On Hold / Leave day: solid `#7052BA` circle with white text.
     - Active / Selected day: solid `#1E1E2D` circle with white text.
   - Legend row: `● Completed  ● In Progress  ● On Hold`.
3. **Task Cards & Filter Pills**:
   - Filter segmented chips: `(2) Completed` (green filled), `(5) In Progress` (light grey), `(8) On Hold` (light grey).
   - Task card: Title, date, overlapping circular member avatars with `+2`, status badge.
4. **Task Details Screen**:
   - Back button `<` + Title + More `...`.
   - Hero icon badge + Title + Status selection pills (`Completed`, `In Progress`, `On Hold`).
   - "Assigned for" block with avatars.
   - "To be done on" block with calendar trigger.
   - "Subtasks" checklist with interactive checkboxes.
   - "Task Description" block.
   - "Attachments" file pills (PDF, PNG, RAR) with sizes.
5. **HR & Kazakhstan Web View Integration**:
   - Quick GPS Check-In button with live coordinates.
   - KZ Labor Contracts, Personnel Orders, Leave balance (24 days), Salary Slips with KZ taxes (OPV 10%, VOSMS 2%, IPN 10%).
