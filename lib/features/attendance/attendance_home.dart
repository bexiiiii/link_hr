import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/forms.dart';
import '../../core/kit.dart';
import '../../core/motion.dart';
import '../../core/premium.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/checklists.dart';
import '../../data/hr.dart';
import '../../data/score.dart';
import '../../data/tasks.dart';
import '../../data/timesheet.dart';
import '../home/checkin_card.dart';
import '../home/home_panels.dart';
import '../home/summary_widgets.dart';
import '../requests/requests_screen.dart';
import '../timesheet/timesheet_view.dart';
import 'checkin_history_screen.dart';

/// "Часы" tab: the big green check-in button, today's numbers and the attendance log.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _session = Session.instance;
  late Timer _clock;
  DateTime _now = DateTime.now();
  bool _loading = true;
  Object? _error;

  List<MonthSheet> _sheets = [];
  List<Json> _todayLogs = [];
  List<Json> _shifts = [];
  List<MotivationRule> _motivationRules = [];
  ShiftLocation? _office;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _load();
    _session.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    _clock.cancel();
    _session.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final start = Fmt.dateOnly(now);
    try {
      final r = await Future.wait<Object?>([
        MonthSheet.loadRange(
          DateTime(now.year, 1),
          DateTime(now.year, now.month),
        ),
        Hr.checkinsBetween(
          start,
          start.add(const Duration(days: 1)),
        ).then<Object?>((v) => v).catchError((_) => <Json>[]),
        Hr.shiftAssignments()
            .then<Object?>((v) => v)
            .catchError((_) => <Json>[]),
        Hr.shiftLocation().then<Object?>((v) => v).catchError((_) => null),
        MotivationRule.load()
            .then<Object?>((v) => v)
            .catchError((_) => <MotivationRule>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _sheets = r[0] as List<MonthSheet>;
        _todayLogs = r[1] as List<Json>;
        _shifts = r[2] as List<Json>;
        _office = r[3] as ShiftLocation?;
        _motivationRules = r[4] as List<MotivationRule>;
        _loading = false;
        _error = null;
        _now = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  MonthSheet? get _selectedSheet => _sheets
      .where(
        (m) => m.month.year == _month.year && m.month.month == _month.month,
      )
      .firstOrNull;

  /// Minutes spent away between an OUT and the next IN today.
  int get _breakMinutes {
    var total = 0;
    DateTime? out;
    for (final l in _todayLogs) {
      final t = Fmt.parse(l['time']);
      if (t == null) continue;
      if (l['log_type'] == 'OUT') {
        out = t;
      } else if (out != null) {
        total += t.difference(out).inMinutes;
        out = null;
      }
    }
    return total;
  }

  String _duration(int minutes) {
    if (minutes <= 0) return '– –';
    final h = minutes ~/ 60, m = minutes % 60;
    return h == 0 ? '$m мин' : (m == 0 ? '$h ч' : '$hч ${m}м');
  }

  Future<void> _openPanel(
    String title,
    Widget Function(
      List<MonthSheet> sheets,
      List<TaskItem> tasks,
      List<ChecklistRun> runs,
    )
    build,
  ) {
    return pushPage(
      context,
      _PanelPage(title: title, sheets: _sheets, builder: build),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = Fmt.dateOnly(_now);
    final current = _sheets.lastOrNull;
    final todayRecord = current?.days.where((d) => d.date == today).firstOrNull;
    final last = _todayLogs.lastOrNull;
    final onShift = last?['log_type'] == 'IN';
    final finished = last?['log_type'] == 'OUT';
    final workStart = MonthSheet.workStartOf(_shifts);
    final workEnd = MonthSheet.workEndOf(_shifts);
    final workedMinutes = ((todayRecord?.hours ?? 0) * 60).round();

    final hint = !_session.checkinAllowed
        ? 'Отметки из приложения отключены в вашей компании'
        : _office != null && _session.geolocationTracking
        ? 'Вы должны быть рядом с офисом «${_office!.name}»'
        : 'Отметка сохраняется с геолокацией и селфи';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: _error != null && _sheets.isEmpty
            ? PageScroll(
                onRefresh: _load,
                children: [ErrorState(error: _error!, onRetry: _load)],
              )
            : PageScroll(
                onRefresh: _load,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Посещаемость', style: AppText.title),
                      ),
                      CircleButton(
                        icon: CupertinoIcons.list_bullet,
                        label: 'История отметок',
                        size: 48,
                        iconSize: 20,
                        onTap: () =>
                            pushPage(context, const CheckinHistoryScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _WeekStrip(today: today, sheet: current),
                  const SizedBox(height: 28),
                  Center(
                    child: _ClockButton(
                      label: !_session.checkinAllowed
                          ? 'Недоступно'
                          : onShift
                          ? 'Уйти'
                          : finished
                          ? 'Снова на работу'
                          : 'Отметиться',
                      out: onShift,
                      waiting: !onShift && !finished && _session.checkinAllowed,
                      onTap: !_session.checkinAllowed || _loading
                          ? null
                          : () => showCheckinSheet(
                              context,
                              onShift ? 'OUT' : 'IN',
                            ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      Fmt.time(_now),
                      style: AppText.clock.copyWith(fontSize: 34),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: AppText.label.copyWith(color: AppColors.ink3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Смена ${MonthSheet.hhmm(workStart)} – ${MonthSheet.hhmm(workEnd)}',
                      style: AppText.caption,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        _TodayStat(
                          label: 'Приход',
                          value: todayRecord?.firstIn == null
                              ? '– –'
                              : Fmt.time(todayRecord!.firstIn),
                        ),
                        _TodayStat(
                          label: 'Уход',
                          value: finished
                              ? Fmt.time(Fmt.parse(last?['time']))
                              : '– –',
                        ),
                        _TodayStat(
                          label: 'Часы',
                          value: _duration(workedMinutes),
                        ),
                        _TodayStat(
                          label: 'Перерыв',
                          value: _duration(_breakMinutes),
                        ),
                      ],
                    ),
                  ),
                  if ((todayRecord?.lateMinutes ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.clock,
                          size: 16,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Опоздание сегодня: ${formatLate(todayRecord!.lateMinutes)}',
                          style: AppText.label.copyWith(color: AppColors.amber),
                        ),
                      ],
                    ),
                  ],
                  SummarySection(title: 'Журнал отметок'),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current == null
                              ? ''
                              : '${_selectedSheet?.present ?? 0} ${Fmt.plural(_selectedSheet?.present ?? 0, 'день', 'дня', 'дней')} на работе',
                          style: AppText.label,
                        ),
                      ),
                      DropdownPill(
                        label: Fmt.monthYear(_month),
                        onTap: () async {
                          final picked = await showSelectSheet(
                            context,
                            title: 'Месяц',
                            options: [
                              for (final m in _sheets.reversed)
                                SelectOption(
                                  Fmt.iso(m.month),
                                  Fmt.monthYear(m.month),
                                ),
                            ],
                            selected: Fmt.iso(_month),
                          );
                          if (picked != null)
                            setState(() => _month = DateTime.parse(picked));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Skeleton(height: 260, radius: AppRadius.card)
                  else
                    _LogTable(sheet: _selectedSheet, today: today),
                  SummarySection(title: 'Отчёты'),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    child: Divided(
                      children: [
                        NavRow(
                          icon: CupertinoIcons.calendar,
                          title: 'Табель',
                          subtitle: 'Календарь посещаемости по месяцам',
                          onTap: () => _openPanel(
                            'Табель',
                            (sheets, _, _) => TimesheetGridPanel(
                              yearSheets: sheets,
                              onRefresh: () async {},
                            ),
                          ),
                        ),
                        NavRow(
                          icon: CupertinoIcons.chart_bar,
                          title: 'Статистика',
                          subtitle: 'Дисциплина и план за день',
                          onTap: () => _openPanel(
                            'Статистика',
                            (sheets, tasks, runs) => StatsPanel(
                              yearSheets: sheets,
                              tasks: tasks,
                              runs: runs,
                              onRefresh: () async {},
                            ),
                          ),
                        ),
                        NavRow(
                          icon: CupertinoIcons.star,
                          title: 'Баллы',
                          subtitle: _session.hasFeature('points')
                              ? 'Рейтинг и достижения'
                              : 'Доступно в Premium',
                          onTap: () => _session.hasFeature('points')
                              ? _openPanel('Баллы', (sheets, tasks, runs) {
                                  final me = _session.userId;
                                  return PointsPanel(
                                    score: Score.compute(
                                      sheet: sheets.last,
                                      tasks: tasks,
                                      runs: runs,
                                      me: me,
                                      rules: _motivationRules,
                                    ),
                                    achievements: Achievements.compute(
                                      sheets: sheets,
                                      tasks: tasks,
                                      runs: runs,
                                      me: me,
                                    ),
                                    month: sheets.last.month,
                                    onRefresh: () async {},
                                  );
                                })
                              : pushPage(
                                  context,
                                  const PremiumGate(
                                    feature: 'points',
                                    title: 'Баллы',
                                    child: SizedBox(),
                                  ),
                                ),
                        ),
                        NavRow(
                          icon: CupertinoIcons.tray_arrow_up,
                          title: 'Корректировки и смены',
                          subtitle: 'Забыли отметиться, другая смена',
                          onTap: () =>
                              pushPage(context, const RequestsScreen()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  const _TodayStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, style: AppText.caption),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: AppText.number.copyWith(
              fontSize: 16,
              color: value == '– –' ? AppColors.ink4 : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round green button with a soft halo that breathes while the day has not started.
class _ClockButton extends StatefulWidget {
  const _ClockButton({
    required this.label,
    required this.onTap,
    required this.waiting,
    required this.out,
  });

  final String label;
  final VoidCallback? onTap;
  final bool waiting;
  final bool out;

  @override
  State<_ClockButton> createState() => _ClockButtonState();
}

class _ClockButtonState extends State<_ClockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ClockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.waiting && !reduceMotion(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    const size = 188.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Pressable(
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onTap!();
              }
            : null,
        scale: 0.95,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Container(
              width: size + 44,
              height: size + 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (enabled ? AppColors.greenGlow : AppColors.chip)
                    .withValues(alpha: 0.45 + 0.35 * t),
              ),
              child: Container(
                width: size + 12 + 8 * t,
                height: size + 12 + 8 * t,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (enabled ? AppColors.greenGlow : AppColors.chip)
                      .withValues(alpha: 0.9),
                ),
                child: child,
              ),
            );
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? (widget.out ? AppColors.greenDeep : AppColors.green)
                  : AppColors.ink4,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.out
                      ? CupertinoIcons.hand_raised
                      : CupertinoIcons.hand_point_right,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: AppText.bodyStrong.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mon–Sun of the current week; the day is green when there is a mark, today is a filled circle.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today, required this.sheet});

  final DateTime today;
  final MonthSheet? sheet;

  static const _names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: () {
                final d = monday.add(Duration(days: i));
                final record = sheet?.days
                    .where((x) => x.date == d)
                    .firstOrNull;
                final isToday = d == today;
                final marked = record?.firstIn != null;
                return Column(
                  children: [
                    Text(
                      _names[i],
                      style: AppText.caption.copyWith(
                        color: isToday ? AppColors.green : AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? AppColors.green : Colors.transparent,
                      ),
                      child: Text(
                        '${d.day}',
                        style: AppText.number.copyWith(
                          color: isToday
                              ? Colors.white
                              : (d.isAfter(today)
                                    ? AppColors.ink4
                                    : AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !marked
                            ? Colors.transparent
                            : record!.mark == DayMark.late
                            ? AppColors.amber
                            : AppColors.green,
                      ),
                    ),
                  ],
                );
              }(),
            ),
        ],
      ),
    );
  }
}

class _LogTable extends StatelessWidget {
  const _LogTable({required this.sheet, required this.today});

  final MonthSheet? sheet;
  final DateTime today;

  String _hours(double h) {
    if (h <= 0) return '–';
    final minutes = (h * 60).round();
    final hh = minutes ~/ 60, mm = minutes % 60;
    return mm == 0 ? '$hhч' : '$hhч ${mm}м';
  }

  @override
  Widget build(BuildContext context) {
    final rows = (sheet?.days ?? const <DayRecord>[])
        .where(
          (d) =>
              !d.date.isAfter(today) &&
              (d.firstIn != null ||
                  d.mark == DayMark.absent ||
                  d.mark == DayMark.leave),
        )
        .toList()
        .reversed
        .toList();
    const headerStyle = TextStyle(
      fontFamily: kFont,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: AppShadow.card,
        ),
        child: Column(
          children: [
            Container(
              color: AppColors.ink2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('Дата', style: headerStyle)),
                  Expanded(flex: 3, child: Text('Приход', style: headerStyle)),
                  Expanded(flex: 3, child: Text('Уход', style: headerStyle)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Часы',
                      textAlign: TextAlign.right,
                      style: headerStyle,
                    ),
                  ),
                ],
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'В этом месяце отметок нет',
                  style: AppText.body.copyWith(color: AppColors.ink3),
                ),
              )
            else
              for (final (i, d) in rows.take(math.min(rows.length, 31)).indexed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          _dayLabel(d.date),
                          style: AppText.label.copyWith(color: AppColors.ink),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          d.firstIn == null
                              ? _markLabel(d.mark)
                              : Fmt.time(d.firstIn),
                          style: AppText.number.copyWith(
                            fontSize: 14,
                            color: d.mark == DayMark.late
                                ? AppColors.amber
                                : d.firstIn == null
                                ? AppColors.ink3
                                : AppColors.ink,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          d.lastOut == null ? '–' : Fmt.time(d.lastOut),
                          style: AppText.number.copyWith(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _hours(d.hours),
                          textAlign: TextAlign.right,
                          style: AppText.number.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  String _dayLabel(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${Fmt.dayMonth(d).split(' ').skip(1).join(' ')}';

  String _markLabel(DayMark m) => switch (m) {
    DayMark.absent => 'Прогул',
    DayMark.leave => 'Отпуск',
    _ => '–',
  };
}

/// Hosts a reporting panel (табель, статистика, баллы) with the data it needs.
class _PanelPage extends StatefulWidget {
  const _PanelPage({
    required this.title,
    required this.sheets,
    required this.builder,
  });

  final String title;
  final List<MonthSheet> sheets;
  final Widget Function(
    List<MonthSheet> sheets,
    List<TaskItem> tasks,
    List<ChecklistRun> runs,
  )
  builder;

  @override
  State<_PanelPage> createState() => _PanelPageState();
}

class _PanelPageState extends State<_PanelPage> {
  List<TaskItem>? _tasks;
  List<ChecklistRun>? _runs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final r = await Future.wait<Object>([
      Tasks.list().catchError((_) => <TaskItem>[]),
      Checklists.runs(
        from: DateTime(now.year, 1, 1),
        to: now,
        user: Session.instance.userId,
      ).catchError((_) => <ChecklistRun>[]),
    ]);
    if (mounted) {
      setState(() {
        _tasks = r[0] as List<TaskItem>;
        _runs = r[1] as List<ChecklistRun>;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: ScreenHeader(title: widget.title),
      body: _tasks == null || widget.sheets.isEmpty
          ? PageScroll(children: const [SkeletonCards(count: 3, height: 120)])
          : widget.builder(widget.sheets, _tasks!, _runs!),
    );
  }
}
