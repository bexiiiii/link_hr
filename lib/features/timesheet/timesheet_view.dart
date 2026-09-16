import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/fmt.dart';
import '../../core/forms.dart';
import '../../core/kit.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/timesheet.dart';

extension DayMarkStyle on DayMark {
  String get label => switch (this) {
        DayMark.onTime => 'Вовремя',
        DayMark.late => 'Опоздание',
        DayMark.remote => 'Удалённо',
        DayMark.absent => 'Отсутствие',
        DayMark.leave => 'Отпуск',
        DayMark.dayOff => 'Выходной',
        DayMark.noMark => 'Нет отметки',
        DayMark.future => 'Впереди',
      };

  Tone get tone => switch (this) {
        DayMark.onTime => Tone.green,
        DayMark.remote => Tone.violet,
        DayMark.late || DayMark.dayOff => Tone.amber,
        DayMark.absent => Tone.red,
        DayMark.leave => Tone.dark,
        _ => Tone.neutral,
      };

  IconData get icon => switch (this) {
        DayMark.onTime => CupertinoIcons.clock,
        DayMark.late => CupertinoIcons.timer,
        DayMark.remote => CupertinoIcons.house,
        DayMark.absent => CupertinoIcons.xmark_circle,
        DayMark.leave => CupertinoIcons.airplane,
        DayMark.dayOff => CupertinoIcons.sun_max,
        _ => CupertinoIcons.circle,
      };

  Color get cell => switch (this) {
        DayMark.onTime => const Color(0xFFEAF7EE),
        DayMark.remote => AppColors.violetSoft,
        DayMark.late => const Color(0xFFFFEEDD),
        DayMark.absent => AppColors.redSoft,
        DayMark.leave => AppColors.chip,
        DayMark.dayOff => const Color(0xFFFFF6EC),
        _ => AppColors.surface,
      };
}

const legendMarks = [DayMark.onTime, DayMark.late, DayMark.remote, DayMark.absent, DayMark.leave, DayMark.dayOff];

/// Beepro-style month grid: square cells, day number, status icon, lateness.
class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key, required this.sheet, this.filter, this.onDayTap});

  final MonthSheet sheet;
  final DayMark? filter;
  final ValueChanged<DayRecord>? onDayTap;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final leading = sheet.month.weekday - 1;
    final rows = ((leading + sheet.days.length) / 7).ceil();
    final today = Fmt.dateOnly(DateTime.now());
    final prevMonthDays = DateTime(sheet.month.year, sheet.month.month, 0).day;
    return Column(children: [
      Row(children: [
        for (final w in _weekdays)
          Expanded(child: Text(w, textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 11))),
      ]),
      const SizedBox(height: 6),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: () {
                final i = r * 7 + c - leading;
                if (i < 0 || i >= sheet.days.length) {
                  final n = i < 0 ? prevMonthDays + i + 1 : i - sheet.days.length + 1;
                  return _Cell(number: n, faded: true);
                }
                final d = sheet.days[i];
                return _Cell(
                  number: d.date.day,
                  record: d,
                  isToday: d.date == today,
                  dimmed: filter != null && d.mark != filter,
                  onTap: onDayTap == null || d.mark == DayMark.future ? null : () => onDayTap!(d),
                );
              }(),
            ),
        ]),
    ]);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.number, this.record, this.faded = false, this.isToday = false, this.dimmed = false, this.onTap});

  final int number;
  final DayRecord? record;
  final bool faded;
  final bool isToday;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = record?.mark;
    final showIcon = m != null && m != DayMark.future && m != DayMark.noMark;
    final cell = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.28 : 1,
      child: Container(
        height: 62,
        padding: const EdgeInsets.fromLTRB(6, 7, 4, 5),
        decoration: BoxDecoration(
          color: faded ? AppColors.surface : m?.cell ?? AppColors.surface,
          border: Border.all(color: isToday ? AppColors.violet : AppColors.bg, width: isToday ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: faded ? AppColors.ink4.withValues(alpha: 0.6) : AppColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            const Spacer(),
            if (showIcon) Icon(m.icon, size: 14, color: m.tone == Tone.neutral ? AppColors.ink3 : m.tone.solid),
          ]),
          const Spacer(),
          if (m == DayMark.late)
            Text(formatLate(record!.lateMinutes).replaceAll(' мин', 'м').replaceAll(' ч', 'ч').replaceAll(' ', ''),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.amber)),
          if (m == DayMark.onTime && record!.hours >= 0.1)
            Text('${Fmt.decimal(double.parse(record!.hours.toStringAsFixed(1)))} ч',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.greenDeep)),
        ]),
      ),
    );
    return onTap == null
        ? cell
        : Pressable(onTap: onTap, scale: 0.94, semanticLabel: '$number, ${m?.label ?? ''}', child: cell);
  }
}

void showDaySheet(BuildContext context, DayRecord d, {String? workStart}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (c) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(Fmt.long(d.date), style: AppText.title)),
            StatusPill(null, label: d.mark.label, tone: d.mark.tone),
          ]),
          const SizedBox(height: 16),
          FieldRows(rows: [
            ('Приход', d.firstIn == null ? '—' : Fmt.time(d.firstIn)),
            ('Уход', d.lastOut == null ? '—' : Fmt.time(d.lastOut)),
            ('Отработано', d.hours <= 0 ? '—' : '${Fmt.decimal(double.parse(d.hours.toStringAsFixed(1)))} ч'),
            if (d.mark == DayMark.late) ('Опоздание', formatLate(d.lateMinutes)),
            if (workStart != null) ('Начало рабочего дня', workStart),
          ]),
        ]),
      ),
    ),
  );
}

void showMonthSchedule(BuildContext context, MonthSheet sheet) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.94,
      builder: (c, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('График · ${Fmt.monthYear(sheet.month).toLowerCase()}', style: AppText.title),
          const SizedBox(height: 6),
          Text('Начало рабочего дня ${sheet.workStartLabel}', style: AppText.label.copyWith(color: AppColors.ink3)),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divided(children: [
              for (final d in sheet.days.where((d) => d.mark != DayMark.future))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 96, child: Text(Fmt.weekdayDate(d.date), style: AppText.bodyStrong.copyWith(fontSize: 13))),
                    Expanded(
                      child: Text(
                        d.firstIn == null ? d.mark.label : '${Fmt.time(d.firstIn)} – ${d.lastOut == null ? '…' : Fmt.time(d.lastOut)}',
                        style: AppText.label,
                      ),
                    ),
                    if (d.mark == DayMark.late)
                      Text('+${formatLate(d.lateMinutes)}',
                          style: AppText.caption.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600))
                    else
                      Icon(d.mark.icon, size: 18, color: d.mark.tone == Tone.neutral ? AppColors.ink4 : d.mark.tone.solid),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    ),
  );
}

/// Табель tab: year + month (or all months), type filters, stacked month grids,
/// floating "Посмотреть график".
class TimesheetGridPanel extends StatefulWidget {
  const TimesheetGridPanel({super.key, required this.yearSheets, required this.onRefresh});

  final List<MonthSheet> yearSheets;
  final Future<void> Function() onRefresh;

  @override
  State<TimesheetGridPanel> createState() => _TimesheetGridPanelState();
}

class _TimesheetGridPanelState extends State<TimesheetGridPanel> {
  final int _thisYear = DateTime.now().year;
  late int _year = _thisYear;
  int? _month;
  DayMark? _filter;
  final Map<int, List<MonthSheet>> _cache = {};
  bool _loading = false;

  List<MonthSheet> get _sheets => _year == _thisYear ? widget.yearSheets : (_cache[_year] ?? const []);

  Future<void> _setYear(int y) async {
    setState(() {
      _year = y;
      _month = null;
    });
    if (y == _thisYear || _cache.containsKey(y)) return;
    setState(() => _loading = true);
    try {
      final sheets = await MonthSheet.loadRange(DateTime(y, 1), DateTime(y, 12));
      if (mounted) setState(() => _cache[y] = sheets);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheets = _sheets.reversed.where((s) => _month == null || s.month.month == _month).toList();
    final counts = {for (final m in legendMarks) m: sheets.fold<int>(0, (s, sh) => s + sh.count(m))};
    return Stack(children: [
      CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  DropdownPill(
                    prefix: 'Год',
                    label: '$_year',
                    onTap: () async {
                      final picked = await showSelectSheet(context,
                          title: 'Год',
                          options: [for (var y = _thisYear; y >= _thisYear - 4; y--) SelectOption('$y', '$y')],
                          selected: '$_year');
                      if (picked != null) _setYear(int.parse(picked));
                    },
                  ),
                  DropdownPill(
                    prefix: 'Месяц',
                    label: _month == null ? 'Все' : Fmt.month(DateTime(_year, _month!)),
                    onTap: () async {
                      final last = _year == _thisYear ? DateTime.now().month : 12;
                      final picked = await showSelectSheet(context,
                          title: 'Месяц',
                          options: [
                            const SelectOption('0', 'Все месяцы'),
                            for (var m = last; m >= 1; m--) SelectOption('$m', Fmt.month(DateTime(_year, m))),
                          ],
                          selected: '${_month ?? 0}');
                      if (picked != null) setState(() => _month = picked == '0' ? null : int.parse(picked));
                    },
                  ),
                  if (_loading) const CupertinoActivityIndicator(),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: legendMarks.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final m = legendMarks[i];
                      return TagChip(
                        label: '${m.label} · ${counts[m]}',
                        icon: m.icon,
                        tone: m.tone,
                        selected: _filter == m,
                        onTap: () => setState(() => _filter = _filter == m ? null : m),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
          if (sheets.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: _loading ? const Skeleton(height: 360, radius: 20) : const Skeleton(height: 360, radius: 20),
              ),
            )
          else
            SliverList.builder(
              itemCount: sheets.length,
              itemBuilder: (_, i) => Reveal(
                key: ValueKey('${sheets[i].month}'),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Row(children: [
                        Text(Fmt.month(sheets[i].month), style: AppText.heading),
                        const Spacer(),
                        Text('${sheets[i].present} дн · ${formatLate(sheets[i].lateMinutes)} опозданий', style: AppText.caption),
                      ]),
                    ),
                    MonthGrid(
                      sheet: sheets[i],
                      filter: _filter,
                      onDayTap: (d) => showDaySheet(context, d, workStart: sheets[i].workStartLabel),
                    ),
                  ]),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
      if (sheets.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: PrimaryButton(
              label: 'Посмотреть график',
              kind: ButtonKind.violet,
              height: 44,
              expand: false,
              onTap: () => showMonthSchedule(context, sheets.first),
            ),
          ),
        ),
    ]);
  }
}
