import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/media.dart';
import '../../core/checkin_photo.dart';
import '../../core/api.dart';
import '../../core/chart.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/kit.dart';
import '../../core/motion.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/checklists.dart';
import '../../data/hr.dart';
import '../../data/plans.dart';
import '../../data/score.dart';
import '../../data/tasks.dart';
import '../../data/timesheet.dart';
import '../achievements/achievements_screens.dart';
import '../checklists/checklists_screens.dart';
import '../requests/requests_screen.dart';
import '../tasks/task_sheet.dart';
import '../timesheet/timesheet_view.dart';
import 'checkin_card.dart';

Widget _scroll({
  required Future<void> Function() onRefresh,
  required List<Widget> children,
}) => PageScroll(
  onRefresh: onRefresh,
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
  children: children,
);

// Link Time ------------------------------------------------------------------

class TimePanel extends StatelessWidget {
  const TimePanel({
    super.key,
    required this.lastLog,
    required this.today,
    required this.workStart,
    required this.workEnd,
    required this.runs,
    required this.tasks,
    required this.people,
    required this.onRefresh,
  });

  final Json? lastLog;
  final DayRecord? today;
  final (int, int) workStart;
  final (int, int) workEnd;
  final List<ChecklistRun> runs;
  final List<TaskItem> tasks;
  final Map<String, PersonInfo> people;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final now = DateTime.now();
    final lastTime = Fmt.parse(lastLog?['time']);
    final lastToday =
        lastTime != null && Fmt.dateOnly(lastTime) == Fmt.dateOnly(now);
    final onShift = lastToday && lastLog?['log_type'] == 'IN';
    final finished = lastToday && lastLog?['log_type'] == 'OUT';
    final arrived = today?.firstIn;
    final me = s.userId;
    final todayTasks = (s.hasFeature('tasks') ? tasks : const <TaskItem>[])
        .where(
          (t) =>
              t.allocatedTo == me &&
              t.status == TaskStatus.inProgress &&
              t.due != null &&
              !Fmt.dateOnly(t.due!).isAfter(Fmt.dateOnly(now)),
        )
        .toList();

    var i = 0;
    final rows = <Widget>[
      _PlanRow(
        state: arrived == null
            ? _Check.none
            : (today!.mark == DayMark.late ? _Check.late : _Check.done),
        title: 'Быть на работе',
        subtitle: Row(
          children: [
            Text(MonthSheet.hhmm(workStart), style: AppText.caption),
            if (arrived != null && today!.mark == DayMark.late) ...[
              const SizedBox(width: 8),
              Text(
                'Опоздание ${formatLate(today!.lateMinutes)}',
                style: AppText.caption.copyWith(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.clock,
                size: 13,
                color: AppColors.amber,
              ),
            ] else if (arrived != null) ...[
              const SizedBox(width: 8),
              Text(
                'Пришли в ${Fmt.time(arrived)}',
                style: AppText.caption.copyWith(
                  color: AppColors.greenDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        onTap: arrived == null && s.checkinAllowed
            ? () => showCheckinSheet(context, 'IN')
            : (today == null
                  ? null
                  : () => showDaySheet(
                      context,
                      today!,
                      workStart: MonthSheet.hhmm(workStart),
                    )),
      ),
      for (final r in s.hasFeature('checklists') ? runs : const <ChecklistRun>[])
        _PlanRow(
          state: r.closed ? _Check.done : _Check.none,
          title: r.meta.title,
          subtitle: Row(
            children: [
              Text(r.meta.window, style: AppText.caption),
              const SizedBox(width: 8),
              _Chip(
                r.closed
                    ? 'Выполнено'
                    : (r.doneCount > 0
                          ? '${r.doneCount}/${r.items.length}'
                          : 'Выполнить'),
                done: r.closed,
              ),
            ],
          ),
          chevron: true,
          onTap: () => pushPage(context, ChecklistRunScreen(name: r.name)),
        ),
      for (final t in todayTasks)
        _PlanRow(
          state: t.stage == TaskStage.review ? _Check.late : _Check.none,
          title: t.title,
          subtitle: Row(
            children: [
              Text(
                t.overdue
                    ? 'Просрочено с ${Fmt.dayMonth(t.due)}'
                    : 'Задача на сегодня',
                style: AppText.caption.copyWith(
                  color: t.overdue ? AppColors.red : AppColors.ink3,
                ),
              ),
              const SizedBox(width: 8),
              _Chip(t.stage.label),
            ],
          ),
          chevron: true,
          onTap: () => showTaskSheet(context, t, people),
        ),
      _PlanRow(
        state: finished ? _Check.done : _Check.none,
        title: 'Завершить рабочий день',
        subtitle: Text(
          finished ? 'Ушли в ${Fmt.time(lastTime)}' : MonthSheet.hhmm(workEnd),
          style: AppText.caption,
        ),
        onTap: onShift && s.checkinAllowed
            ? () => showCheckinSheet(context, 'OUT')
            : null,
      ),
    ];

    return _scroll(
      onRefresh: onRefresh,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.calendar, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сегодня',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                Text(Fmt.todayLine(now), style: AppText.caption),
              ],
            ),
            const Spacer(),
            Pressable(
              onTap: () => pushPage(context, const RequestsScreen()),
              semanticLabel: 'Запросы',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ink2, width: 1.2),
                ),
                child: const Text(
                  'Запросы',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divided(
          children: [for (final r in rows) Reveal(index: i++, child: r)],
        ),
        if (arrived != null) _ArrivalPhoto(key: ValueKey(lastLog?['time'])),
        if (runs.isEmpty && Session.instance.isManager && Session.instance.hasFeature('checklists'))
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Row(
              children: [
                Text(
                  'Чеклисты на сегодня не назначены.',
                  style: AppText.caption,
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  onPressed: () => pushPage(context, const ChecklistsScreen()),
                  child: const Text(
                    'Создать',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.violet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        if (s.checkinAllowed)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: finished
                ? Column(
                    key: const ValueKey('finished'),
                    children: [
                      Text(
                        'Сегодня отработано ${Fmt.decimal(double.parse((today?.hours ?? 0).toStringAsFixed(1)))} ч',
                        style: AppText.label,
                      ),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: 'Вернуться на работу',
                        kind: ButtonKind.outline,
                        onTap: () => showCheckinSheet(context, 'IN'),
                      ),
                    ],
                  )
                : onShift
                ? PrimaryButton(
                    key: const ValueKey('out'),
                    label: 'Завершить',
                    onTap: () => showCheckinSheet(context, 'OUT'),
                  )
                : PrimaryButton(
                    key: const ValueKey('in'),
                    label: 'Я на работе',
                    onTap: () => showCheckinSheet(context, 'IN'),
                  ),
          ),
      ],
    );
  }
}

enum _Check { none, done, late }

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.state,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.chevron = false,
  });

  final _Check state;
  final String title;
  final Widget subtitle;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _Check.done => AppColors.green,
      _Check.late => AppColors.amber,
      _Check.none => Colors.transparent,
    };
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutQuart,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: state == _Check.none ? AppColors.chipDot : color,
                  width: 1.5,
                ),
              ),
              child: state == _Check.none
                  ? null
                  : const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 3),
                  subtitle,
                ],
              ),
            ),
            if (chevron)
              const Icon(
                CupertinoIcons.chevron_right,
                size: 17,
                color: AppColors.ink3,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.done = false});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: done ? AppColors.greenSoft : AppColors.bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: done ? AppColors.greenDeep : AppColors.ink3,
      ),
    ),
  );
}

// Statistics -----------------------------------------------------------------

class StatsPanel extends StatefulWidget {
  const StatsPanel({
    super.key,
    required this.yearSheets,
    required this.tasks,
    required this.runs,
    required this.onRefresh,
  });

  final List<MonthSheet> yearSheets;
  final List<TaskItem> tasks;
  final List<ChecklistRun> runs;
  final Future<void> Function() onRefresh;

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  DateTime _day = Fmt.dateOnly(DateTime.now());
  final Map<String, List<DayPlan>> _cache = {};

  String _key(DateTime d) => '${d.year}-${d.month}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final month = DateTime(_day.year, _day.month);
    final key = _key(month);
    if (_cache.containsKey(key) && !force) return;
    try {
      final list = await Plans.list(
        month,
        DateTime(month.year, month.month + 1, 0),
      );
      if (mounted) setState(() => _cache[key] = list);
    } catch (e) {
      if (mounted) {
        setState(() => _cache[key] = const []);
        showToast(context, errorText(e), error: true);
      }
    }
  }

  void _setDay(DateTime d) {
    final now = Fmt.dateOnly(DateTime.now());
    setState(() => _day = d.isAfter(now) ? now : Fmt.dateOnly(d));
    _load();
  }

  Future<void> _refresh() async {
    await Future.wait([widget.onRefresh(), _load(force: true)]);
  }

  @override
  Widget build(BuildContext context) {
    final month = DateTime(_day.year, _day.month);
    final plans = _cache[_key(month)];
    final now = Fmt.dateOnly(DateTime.now());
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.isAfter(now) ? now : last;
    final dates = [
      for (
        var d = month;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    final byDay = {
      for (final p in plans ?? const <DayPlan>[]) Fmt.iso(p.date): p,
    };
    final values = <double?>[
      for (final d in dates) (byDay[Fmt.iso(d)]?.value ?? 0).toDouble(),
    ];
    final selected = dates.indexWhere((d) => d == _day);
    final current = byDay[Fmt.iso(_day)];

    return _scroll(
      onRefresh: _refresh,
      children: [
        Pressable(
          onTap: () async {
            final d = await pickDate(
              context,
              initial: _day,
              maximum: DateTime.now(),
            );
            if (d != null) _setDay(d);
          },
          semanticLabel: 'Выбрать дату',
          child: Row(
            children: [
              const Icon(CupertinoIcons.calendar, size: 22),
              const SizedBox(width: 10),
              Text(
                '${Fmt.long(_day)} г.',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        MonthYearPicker(
          month: month,
          onChanged: (m) {
            final l = DateTime(m.year, m.month + 1, 0);
            _setDay(DateTime(m.year, m.month, _day.day.clamp(1, l.day)));
          },
        ),
        const SizedBox(height: 16),
        const Text(Plans.metric, style: AppText.cardTitle),
        const SizedBox(height: 6),
        plans == null
            ? const Skeleton(height: 250, radius: 16)
            : DayLineChart(
                key: ValueKey(month),
                dates: dates,
                values: values,
                format: (v) => '${v.round()}',
                selected: selected < 0 ? null : selected,
                onSelect: (i) => setState(() => _day = dates[i]),
              ),
        if (current != null && current.comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(current.comment, style: AppText.label),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label:
              '${current == null ? 'Добавить' : 'Изменить'} план за ${Fmt.date(_day).replaceAll('/', '.')}',
          onTap: () async {
            final ok = await showPlanSheet(context, _day, current);
            if (ok == true) _load(force: true);
          },
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'История заполнения',
          kind: ButtonKind.outline,
          onTap: () => pushPage(context, const _PlanHistoryScreen()),
        ),
      ],
    );
  }
}

Future<bool?> showPlanSheet(
  BuildContext context,
  DateTime day,
  DayPlan? existing,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _PlanSheet(day: day, existing: existing),
  );
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.day, this.existing});

  final DateTime day;
  final DayPlan? existing;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final _value = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.value}',
  );
  late final _comment = TextEditingController(
    text: widget.existing?.comment ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = int.tryParse(_value.text.trim());
    if (v == null) {
      setState(() => _error = 'Введите число');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Plans.save(
        widget.day,
        v,
        _comment.text,
        existing: widget.existing?.name,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('План за ${Fmt.long(widget.day)}', style: AppText.heading),
            const SizedBox(height: 16),
            AppTextField(
              label: Plans.metric,
              controller: _value,
              autofocus: true,
              keyboardType: TextInputType.number,
            ),
            const FormGap(),
            AppTextField(
              label: 'Комментарий',
              controller: _comment,
              maxLines: 3,
            ),
            if (_error != null) InlineError(_error!),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Сохранить', loading: _busy, onTap: _save),
          ],
        ),
      ),
    );
  }
}

class _PlanHistoryScreen extends StatefulWidget {
  const _PlanHistoryScreen();

  @override
  State<_PlanHistoryScreen> createState() => _PlanHistoryScreenState();
}

class _PlanHistoryScreenState extends State<_PlanHistoryScreen> {
  List<DayPlan>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final items = await Plans.list(
        now.subtract(const Duration(days: 365)),
        now,
      );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: const ScreenHeader(title: 'История заполнения'),
      body: PageScroll(
        onRefresh: _load,
        children: [
          if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (_items == null)
            const SkeletonCards(count: 4, height: 60)
          else if (_items!.isEmpty)
            const EmptyState(
              icon: CupertinoIcons.chart_bar,
              title: 'Планы ещё не заполнялись',
              message: 'Нажмите «Добавить план» во вкладке «Статистика».',
            )
          else
            Divided(
              children: [
                for (final (i, p) in _items!.indexed)
                  Reveal(
                    index: i.clamp(0, 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Fmt.long(p.date),
                                  style: AppText.bodyStrong,
                                ),
                                if (p.comment.isNotEmpty)
                                  Text(
                                    p.comment,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${p.value}',
                            style: AppText.number.copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// Points ---------------------------------------------------------------------

class PointsPanel extends StatelessWidget {
  const PointsPanel({
    super.key,
    required this.score,
    required this.achievements,
    required this.month,
    required this.onRefresh,
  });

  final Score? score;
  final List<Achievement> achievements;
  final DateTime month;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final v = score?.value ?? 0;
    final color = v >= 80
        ? AppColors.green
        : (v >= 60 ? const Color(0xFFE9A23B) : AppColors.red);
    return _scroll(
      onRefresh: onRefresh,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              SizedBox(
                width: 170,
                height: 96,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: SemicircleGauge(
                        value: v / 100,
                        color: color,
                        size: 170,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: score == null
                          ? const Skeleton(height: 40, width: 70)
                          : AnimatedNumber(
                              value: v,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                                height: 1,
                                color: AppColors.ink,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'баллов из 100 за ${Fmt.month(month).toLowerCase()}',
                style: AppText.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (score != null)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Divided(
              children: [
                for (final (i, r) in score!.rows.indexed)
                  Reveal(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(r.label, style: AppText.bodyStrong),
                          ),
                          Text(
                            '${r.count} × ${r.perItem > 0 ? '+' : ''}${r.perItem}',
                            style: AppText.caption,
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 44,
                            child: Text(
                              r.total == 0
                                  ? '0'
                                  : '${r.total > 0 ? '+' : ''}${r.total}',
                              textAlign: TextAlign.right,
                              style: AppText.number.copyWith(
                                color: r.total > 0
                                    ? AppColors.greenDeep
                                    : (r.total < 0
                                          ? AppColors.red
                                          : AppColors.ink3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SectionHeader(
          'Достижения',
          actionLabel: 'Все',
          onAction: () =>
              pushPage(context, AchievementsScreen(initial: achievements)),
        ),
        SizedBox(
          height: 176,
          child: achievements.isEmpty
              ? const Skeleton(height: 176, radius: 20)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemCount: achievements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => Reveal(
                    index: i,
                    scale: true,
                    child: SizedBox(
                      width: 148,
                      child: AchievementCard(
                        achievement: achievements[i],
                        compact: true,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Text('Баллы обновляются каждый месяц.', style: AppText.caption),
      ],
    );
  }
}

/// Photo from the workplace for today's latest arrival.
class _ArrivalPhoto extends StatefulWidget {
  const _ArrivalPhoto({super.key});

  @override
  State<_ArrivalPhoto> createState() => _ArrivalPhotoState();
}

class _ArrivalPhotoState extends State<_ArrivalPhoto> {
  String? _checkin;
  String? _url;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final arrivals = await Hr.todayArrivals();
      if (arrivals.isEmpty) return;
      final names = [for (final a in arrivals) a['name'].toString()];
      final photos = await Hr.checkinPhotos(names);
      if (!mounted) return;
      setState(() {
        _checkin = names.first;
        _url = names
            .map((n) => photos[n])
            .firstWhere((u) => u != null, orElse: () => null);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _checkin == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _url != null
          ? Row(
              children: [
                CheckinThumb(url: _url!, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Фото с рабочего места', style: AppText.body),
                ),
                const Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 18,
                  color: AppColors.greenDeep,
                ),
              ],
            )
          : DashedBox(
              height: 56,
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final url = await addCheckinPhoto(context, _checkin!);
                      if (mounted)
                        setState(() {
                          _busy = false;
                          _url = url ?? _url;
                        });
                    },
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.camera,
                          size: 18,
                          color: AppColors.ink3,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Прикрепить фото с рабочего места',
                          style: AppText.body.copyWith(color: AppColors.ink3),
                        ),
                      ],
                    ),
            ),
    );
  }
}
