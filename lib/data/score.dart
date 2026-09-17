import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/fmt.dart';
import '../core/people.dart';
import '../core/session.dart';
import 'checklists.dart';
import 'tasks.dart';
import 'timesheet.dart';

class ScoreRow {
  const ScoreRow(this.label, this.count, this.perItem);

  final String label;
  final int count;
  final int perItem;

  int get total => count * perItem;
}

/// A rule configured by HR in the web motivation system.
class MotivationRule {
  const MotivationRule({
    required this.trigger,
    required this.points,
    this.lateFrom = 0,
    this.lateTo = 24 * 60,
  });

  final String trigger;
  final int points;
  final int lateFrom;
  final int lateTo;

  static Future<List<MotivationRule>> load() async {
    final s = Session.instance;
    final rows = await Api.instance.list(
      'Link Motivation Rule',
      fields: [
        'scope',
        'department',
        'employee',
        'trigger',
        'points',
        'late_from',
        'late_to',
      ],
      filters: {'enabled': 1},
      limit: 500,
    );
    final candidates = rows.where((r) {
      final scope = r['scope']?.toString();
      return scope == 'Компания' ||
          (scope == 'Отдел' && r['department'] == s.department) ||
          (scope == 'Сотрудник' && r['employee'] == s.employeeId);
    }).toList();
    int rank(Json r) => switch (r['scope']?.toString()) {
      'Сотрудник' => 3,
      'Отдел' => 2,
      _ => 1,
    };
    final selected = <String, Json>{};
    for (final rule in candidates) {
      final key = rule['trigger']?.toString() ?? '';
      if (key.isEmpty ||
          (selected[key] != null && rank(selected[key]!) >= rank(rule)))
        continue;
      selected[key] = rule;
    }
    return selected.values
        .map(
          (r) => MotivationRule(
            trigger: r['trigger'].toString(),
            points: Fmt.number(r['points']).round(),
            lateFrom: Fmt.number(r['late_from']).round(),
            lateTo: Fmt.number(r['late_to']).round(),
          ),
        )
        .toList();
  }
}

/// Monthly "Баллы": 100 minus discipline penalties plus on-time task bonuses.
class Score {
  Score(this.rows);

  final List<ScoreRow> rows;

  int get value =>
      (100 + rows.fold<int>(0, (s, r) => s + r.total)).clamp(0, 100);

  static Score compute({
    required MonthSheet sheet,
    required List<TaskItem> tasks,
    required List<ChecklistRun> runs,
    required String me,
    List<MotivationRule> rules = const [],
  }) {
    int points(String trigger, int fallback) =>
        rules.where((r) => r.trigger == trigger).firstOrNull?.points ??
        fallback;
    final monthEnd = DateTime(sheet.month.year, sheet.month.month + 1, 0);
    bool inMonth(DateTime? d) =>
        d != null && d.year == sheet.month.year && d.month == sheet.month.month;
    final mine = tasks.where((t) => t.allocatedTo == me).toList();
    final today = Fmt.dateOnly(DateTime.now());
    final overdue = mine.where((t) => t.overdue && inMonth(t.due)).length;
    final onTimeDone = mine
        .where(
          (t) =>
              t.status == TaskStatus.completed &&
              inMonth(t.modified) &&
              (t.due == null ||
                  !Fmt.dateOnly(t.modified!).isAfter(Fmt.dateOnly(t.due!))),
        )
        .length;
    final failedRuns = runs
        .where(
          (r) =>
              inMonth(r.date) &&
              (r.items.any((i) => i.state == ItemState.failed) ||
                  (!r.closed && r.date!.isBefore(today))),
        )
        .length;
    return Score([
      ScoreRow('Опоздания', sheet.count(DayMark.late), points('Опоздание', -2)),
      ScoreRow('Пропуски', sheet.absent, points('Отсутствие без причины', -5)),
      ScoreRow(
        'Просроченные задачи',
        overdue,
        points('Не выполнил вовремя задачу', -3),
      ),
      ScoreRow(
        'Невыполненные чеклисты',
        failedRuns,
        points('Не выполнил чеклист', -2),
      ),
      ScoreRow(
        'Задачи в срок',
        onTimeDone.clamp(0, monthEnd.day),
        points('Выполнил задачу', 1),
      ),
    ]);
  }
}

class Achievement {
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;
  final int target;
  final int progress;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null;
  double get ratio => (progress / target).clamp(0, 1).toDouble();
}

abstract final class Achievements {
  static const _seenKey = 'link.achievements.seen';

  static List<Achievement> compute({
    required List<MonthSheet> sheets,
    required List<TaskItem> tasks,
    required List<ChecklistRun> runs,
    required String me,
  }) {
    final days =
        sheets
            .expand((s) => s.days)
            .where((d) => d.mark != DayMark.future)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Longest run of on-time workdays; weekends, holidays and leave don't break it.
    var streak = 0, best = 0;
    DateTime? streakAt;
    var early = 0;
    DateTime? earlyAt;
    DateTime? firstCheckin;
    for (final d in days) {
      if (d.firstIn != null) firstCheckin ??= d.date;
      switch (d.mark) {
        case DayMark.onTime || DayMark.remote:
          streak++;
          if (streak > best) best = streak;
          if (streak == 15) streakAt ??= d.date;
        case DayMark.late || DayMark.absent:
          streak = 0;
        default:
          break;
      }
      if (d.firstIn != null && d.lateMinutes == 0) {
        final due = DateTime(
          d.date.year,
          d.date.month,
          d.date.day,
          sheets.first.workStart.$1,
          sheets.first.workStart.$2,
        );
        if (due.difference(d.firstIn!).inMinutes >= 15) {
          early++;
          if (early == 10) earlyAt = d.date;
        }
      }
    }

    final done =
        tasks
            .where(
              (t) => t.allocatedTo == me && t.status == TaskStatus.completed,
            )
            .toList()
          ..sort(
            (a, b) => (a.modified ?? DateTime(2000)).compareTo(
              b.modified ?? DateTime(2000),
            ),
          );
    final closedRuns = runs.where((r) => r.closed).toList()
      ..sort(
        (a, b) =>
            (a.date ?? DateTime(2000)).compareTo(b.date ?? DateTime(2000)),
      );

    DateTime? cleanMonthAt;
    var cleanMonths = 0;
    final now = DateTime.now();
    for (final s in sheets) {
      final finished = DateTime(
        s.month.year,
        s.month.month + 1,
        0,
      ).isBefore(Fmt.dateOnly(now));
      if (finished &&
          s.present > 0 &&
          s.absent == 0 &&
          s.count(DayMark.late) == 0) {
        cleanMonths++;
        cleanMonthAt ??= DateTime(s.month.year, s.month.month + 1, 0);
      }
    }

    return [
      Achievement(
        id: 'first_step',
        title: 'Первый шаг',
        description: 'Отметили приход в Link впервые.',
        target: 1,
        progress: firstCheckin == null ? 0 : 1,
        unlockedAt: firstCheckin,
      ),
      Achievement(
        id: 'time_manager',
        title: 'Тайм-менеджер',
        description: 'Пришли на работу вовремя 15 рабочих дней подряд.',
        target: 15,
        progress: best,
        unlockedAt: streakAt,
      ),
      Achievement(
        id: 'early_bird',
        title: 'Ранняя пташка',
        description: 'Пришли хотя бы на 15 минут раньше начала дня 10 раз.',
        target: 10,
        progress: early,
        unlockedAt: earlyAt,
      ),
      Achievement(
        id: 'task_closer',
        title: 'Закрыватель задач',
        description: 'Выполнили 10 задач на доске.',
        target: 10,
        progress: done.length,
        unlockedAt: done.length >= 10 ? done[9].modified : null,
      ),
      Achievement(
        id: 'checklist_master',
        title: 'Мастер чеклистов',
        description: 'Завершили 20 чеклистов.',
        target: 20,
        progress: closedRuns.length,
        unlockedAt: closedRuns.length >= 20 ? closedRuns[19].date : null,
      ),
      Achievement(
        id: 'clean_month',
        title: 'Безупречный месяц',
        description: 'Целый месяц без опозданий и пропусков.',
        target: 1,
        progress: cleanMonths.clamp(0, 1),
        unlockedAt: cleanMonthAt,
      ),
    ];
  }

  static Future<Set<String>> seen() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_seenKey) ?? const []).toSet();
  }

  static Future<void> markSeen(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final all = {...(prefs.getStringList(_seenKey) ?? const []), ...ids};
    await prefs.setStringList(_seenKey, all.toList());
  }
}

class DisciplineEntry {
  DisciplineEntry({
    required this.person,
    required this.sheet,
    required this.failedTasks,
    required this.failedChecklists,
  });

  final PersonInfo person;
  final MonthSheet sheet;
  final int failedTasks;
  final int failedChecklists;

  int get lateDays => sheet.count(DayMark.late);
  int get absences => sheet.absent;
  int get taskFailures => failedTasks + failedChecklists;

  static int degree(int n) => switch (n) {
    0 => 0,
    1 => 1,
    2 => 2,
    <= 4 => 3,
    _ => 4,
  };

  int get lateDegree => degree(lateDays);
  int get taskDegree => degree(taskFailures);
  int get absenceDegree => degree(absences);
  int get worst =>
      [lateDegree, taskDegree, absenceDegree].reduce((a, b) => a > b ? a : b);
  int get score =>
      (100 - lateDays * 2 - absences * 5 - taskFailures * 3).clamp(0, 100);

  List<String> get findings => [
    if (lateDays > 0)
      'Опоздал ${lateDays == 1 ? 'один раз' : '$lateDays ${Fmt.plural(lateDays, 'раз', 'раза', 'раз')}'}, всего ${formatLate(sheet.lateMinutes)}.',
    if (taskFailures > 0)
      'Не выполнено в срок: $failedTasks ${Fmt.plural(failedTasks, 'задача', 'задачи', 'задач')}, $failedChecklists ${Fmt.plural(failedChecklists, 'чеклист', 'чеклиста', 'чеклистов')}.',
    if (absences > 0)
      'Отсутствовал без отметки $absences ${Fmt.plural(absences, 'день', 'дня', 'дней')}.',
    if (worst >= 3)
      'Рекомендуется провести беседу и зафиксировать предупреждение.'
    else if (worst == 2)
      'Стоит обсудить причины на ближайшей встрече.'
    else if (worst == 0)
      'Нарушений за месяц нет.',
  ];
}

abstract final class Discipline {
  static Api get _api => Api.instance;

  static Future<List<DisciplineEntry>> load(DateTime month) async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    final people = (await People.all(
      refresh: true,
    )).where((p) => p.employee.isNotEmpty).toList();
    if (people.isEmpty) return [];
    final ids = people.map((p) => p.employee).toList();
    final users = people.map((p) => p.userId).toList();
    final today = Fmt.dateOnly(DateTime.now());
    final results = await Future.wait<List<Json>>([
      _api.list(
        'Employee Checkin',
        fields: ['employee', 'log_type', 'time'],
        filters: [
          ['employee', 'in', ids],
          [
            'time',
            'between',
            [Fmt.iso(from), Fmt.iso(DateTime(to.year, to.month, to.day + 1))],
          ],
        ],
        limit: 20000,
      ),
      _api
          .list(
            'Attendance',
            fields: ['employee', 'attendance_date', 'status'],
            filters: [
              ['employee', 'in', ids],
              ['docstatus', '=', 1],
              [
                'attendance_date',
                'between',
                [Fmt.iso(from), Fmt.iso(to)],
              ],
            ],
            limit: 20000,
          )
          .catchError((_) => <Json>[]),
      _api
          .list(
            'ToDo',
            fields: [
              'allocated_to',
              '_user_tags',
              'date',
              'status',
              'reference_type',
            ],
            filters: [
              ['allocated_to', 'in', users],
              ['status', '=', 'Open'],
              [
                'date',
                'between',
                [
                  Fmt.iso(from),
                  Fmt.iso(today.subtract(const Duration(days: 1))),
                ],
              ],
            ],
            limit: 20000,
          )
          .catchError((_) => <Json>[]),
    ]);
    return [
      for (final p in people)
        () {
          final logs = results[0]
              .where((l) => l['employee'] == p.employee)
              .toList();
          final events = {
            for (final a in results[1].where(
              (a) => a['employee'] == p.employee,
            ))
              a['attendance_date'].toString(): a['status'].toString(),
          };
          final open = results[2]
              .where((t) => t['allocated_to'] == p.userId)
              .toList();
          final tags = open.map((t) => t['_user_tags']?.toString() ?? '');
          return DisciplineEntry(
            person: p,
            sheet: MonthSheet.build(from, events, logs, (9, 0)),
            failedTasks: open
                .where(
                  (t) =>
                      t['reference_type'] != 'ToDo' &&
                      !TaskTags.service.any(
                        (s) => (t['_user_tags'] ?? '').toString().contains(s),
                      ),
                )
                .length,
            failedChecklists: tags
                .where((t) => t.contains(ChecklistTags.run))
                .length,
          );
        }(),
    ]..sort((a, b) => a.score.compareTo(b.score));
  }
}
