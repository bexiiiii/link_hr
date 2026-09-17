import '../core/api.dart';
import '../core/fmt.dart';
import 'hr.dart';

/// How a single day reads on the digital табель.
enum DayMark { onTime, late, remote, absent, leave, dayOff, noMark, future }

class DayRecord {
  DayRecord({
    required this.date,
    required this.mark,
    this.firstIn,
    this.lastOut,
    this.lateMinutes = 0,
    this.hours = 0,
  });

  final DateTime date;
  final DayMark mark;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final int lateMinutes;
  final double hours;
}

/// One month of attendance assembled from attendance events, holidays and raw
/// check-ins.
class MonthSheet {
  MonthSheet(this.month, this.days, this.workStart);

  final DateTime month;
  final List<DayRecord> days;
  final (int, int) workStart;

  int count(DayMark m) => days.where((d) => d.mark == m).length;

  int get present =>
      count(DayMark.onTime) + count(DayMark.late) + count(DayMark.remote);
  int get absent => count(DayMark.absent);
  int get lateMinutes => days.fold(0, (s, d) => s + d.lateMinutes);
  double get hours => days.fold(0.0, (s, d) => s + d.hours);

  double get attendanceRate {
    final workdays = present + absent + count(DayMark.noMark);
    return workdays == 0 ? 0 : present / workdays;
  }

  Duration? get averageArrival {
    final arrivals = days
        .where((d) => d.firstIn != null)
        .map((d) => d.firstIn!)
        .toList();
    if (arrivals.isEmpty) return null;
    final minutes =
        arrivals.fold<int>(0, (s, t) => s + t.hour * 60 + t.minute) ~/
        arrivals.length;
    return Duration(minutes: minutes);
  }

  String get workStartLabel => hhmm(workStart);

  static String hhmm((int, int) t) =>
      '${t.$1.toString().padLeft(2, '0')}:${t.$2.toString().padLeft(2, '0')}';

  static Future<MonthSheet> load(DateTime month) async =>
      (await loadRange(month, month)).first;

  /// Loads several consecutive months with three requests in total.
  static Future<List<MonthSheet>> loadRange(
    DateTime firstMonth,
    DateTime lastMonth,
  ) async {
    final from = DateTime(firstMonth.year, firstMonth.month);
    final to = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    final results = await Future.wait<Object>([
      Hr.calendarEvents(from, to).catchError((_) => <String, String>{}),
      Hr.checkinsBetween(
        from,
        DateTime(to.year, to.month, to.day + 1),
      ).catchError((_) => <Json>[]),
      Hr.shiftAssignments().catchError((_) => <Json>[]),
    ]);
    final events = results[0] as Map<String, String>;
    final logs = results[1] as List<Json>;
    final start = workStartOf(results[2] as List<Json>);
    return [
      for (
        var m = from;
        !m.isAfter(lastMonth);
        m = DateTime(m.year, m.month + 1)
      )
        build(m, events, logs, start),
    ];
  }

  static MonthSheet build(
    DateTime month,
    Map<String, String> events,
    List<Json> logs,
    (int, int) start, {
    bool weekendsOff = true,
  }) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    final byDay = <String, List<Json>>{};
    for (final l in logs) {
      final t = Fmt.parse(l['time']);
      if (t != null) byDay.putIfAbsent(Fmt.iso(t), () => []).add(l);
    }
    for (final list in byDay.values) {
      list.sort(
        (a, b) => Fmt.parse(a['time'])!.compareTo(Fmt.parse(b['time'])!),
      );
    }

    final today = Fmt.dateOnly(DateTime.now());
    final days = <DayRecord>[];
    for (
      var d = from;
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final key = Fmt.iso(d);
      final event = events[key];
      final dayLogs = byDay[key] ?? const [];
      final ins = dayLogs
          .where((l) => l['log_type'] == 'IN')
          .map((l) => Fmt.parse(l['time'])!)
          .toList();
      final outs = dayLogs
          .where((l) => l['log_type'] == 'OUT')
          .map((l) => Fmt.parse(l['time'])!)
          .toList();
      final firstIn = ins.isEmpty ? null : ins.first;
      final lastOut = outs.isEmpty ? null : outs.last;
      final hours = _workedHours(dayLogs);
      final weekend = weekendsOff && d.weekday >= DateTime.saturday;

      DayMark mark;
      var late = 0;
      if (event == 'Work From Home') {
        mark = DayMark.remote;
      } else if (firstIn != null) {
        final due = DateTime(d.year, d.month, d.day, start.$1, start.$2);
        late = firstIn.difference(due).inMinutes;
        mark = late > 0 && !weekend ? DayMark.late : DayMark.onTime;
        if (late < 0 || weekend) late = 0;
      } else if (event == 'On Leave') {
        mark = DayMark.leave;
      } else if (event == 'Holiday' || (weekend && event == null)) {
        mark = DayMark.dayOff;
      } else if (event == 'Present' || event == 'Half Day') {
        mark = DayMark.onTime;
      } else if (event == 'Absent') {
        mark = DayMark.absent;
      } else if (d.isAfter(today)) {
        mark = DayMark.future;
      } else if (d == today) {
        mark = DayMark.noMark;
      } else {
        mark = DayMark.absent;
      }
      days.add(
        DayRecord(
          date: d,
          mark: mark,
          firstIn: firstIn,
          lastOut: lastOut,
          lateMinutes: late,
          hours: hours,
        ),
      );
    }
    return MonthSheet(from, days, start);
  }

  static (int, int) workStartOf(List<Json> shifts) =>
      _shiftTime(shifts, 'start_time', (9, 0));

  static (int, int) workEndOf(List<Json> shifts) =>
      _shiftTime(shifts, 'end_time', (18, 0));

  static (int, int) _shiftTime(
    List<Json> shifts,
    String field,
    (int, int) fallback,
  ) {
    final today = Fmt.dateOnly(DateTime.now());
    for (final s in shifts) {
      final begin = Fmt.parse(s['start_date']);
      final end = Fmt.parse(s['end_date']);
      if (begin != null && begin.isAfter(today)) continue;
      if (end != null && end.isBefore(today)) continue;
      final parts = (s[field]?.toString() ?? '').split(':');
      if (parts.length >= 2)
        return (
          int.tryParse(parts[0]) ?? fallback.$1,
          int.tryParse(parts[1]) ?? fallback.$2,
        );
    }
    return fallback;
  }

  static double _workedHours(List<Json> logs) {
    DateTime? open;
    var total = Duration.zero;
    for (final l in logs) {
      final t = Fmt.parse(l['time']);
      if (t == null) continue;
      if (l['log_type'] == 'IN') {
        open ??= t;
      } else if (open != null) {
        total += t.difference(open);
        open = null;
      }
    }
    return total.inMinutes / 60;
  }
}

String formatLate(int minutes) {
  if (minutes <= 0) return '0 мин';
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}
