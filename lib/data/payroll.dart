import '../core/api.dart';
import '../core/fmt.dart';
import '../core/people.dart';
import '../core/session.dart';
import 'timesheet.dart';

/// Monthly payroll sheet. Hours come from check-ins; salary, bonus, deduction
/// and the paid flag are kept per employee per month in a ToDo tagged link-pay
/// that references the Employee.
abstract final class PayTags {
  static const pay = 'link-pay';
}

class PayRow {
  PayRow({
    required this.person,
    required this.fixed,
    required this.bonus,
    required this.deduction,
    required this.hourly,
    required this.paid,
    required this.planHours,
    required this.factHours,
    this.recordName,
  });

  final PersonInfo person;
  double fixed;
  double bonus;
  double deduction;
  bool hourly;
  bool paid;
  final double planHours;
  final double factHours;
  String? recordName;

  double get rate => hourly ? fixed : (planHours == 0 ? 0 : fixed / planHours);
  double get payout => (hourly ? fixed * factHours : fixed) + bonus - deduction;
}

abstract final class Payroll {
  static Api get _api => Api.instance;

  static int workdays(DateTime month) {
    var n = 0;
    final last = DateTime(month.year, month.month + 1, 0).day;
    for (var d = 1; d <= last; d++) {
      if (DateTime(month.year, month.month, d).weekday <= DateTime.friday) n++;
    }
    return n;
  }

  static Future<List<PayRow>> load(DateTime month) async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    final people = (await People.all(
      refresh: true,
    )).where((p) => p.employee.isNotEmpty).toList();
    if (people.isEmpty) return [];
    final ids = people.map((p) => p.employee).toList();
    final r = await Future.wait<List<Json>>([
      _api.list(
        'Employee',
        fields: ['name', 'ctc'],
        filters: [
          ['name', 'in', ids],
        ],
        limit: 5000,
      ),
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
        limit: 50000,
      ),
      _api
          .list(
            'Salary Structure Assignment',
            fields: ['employee', 'base', 'from_date'],
            filters: [
              ['employee', 'in', ids],
              ['docstatus', '=', 1],
              ['from_date', '<=', Fmt.iso(to)],
            ],
            orderBy: 'from_date desc',
            limit: 5000,
          )
          .catchError((_) => <Json>[]),
      _api.list(
        'ToDo',
        fields: ['name', 'description', 'status', 'reference_name'],
        filters: [
          ['_user_tags', 'like', '%${PayTags.pay}%'],
          ['reference_type', '=', 'Employee'],
          ['date', '=', Fmt.iso(from)],
        ],
        limit: 5000,
      ),
    ]);
    final ctc = {
      for (final e in r[0])
        e['name'].toString(): Fmt.number(e['ctc']).toDouble(),
    };
    final structure = <String, double>{};
    for (final a in r[2]) {
      structure.putIfAbsent(
        a['employee'].toString(),
        () => Fmt.number(a['base']).toDouble(),
      );
    }
    final records = {for (final t in r[3]) t['reference_name'].toString(): t};
    final plan = workdays(from) * 8.0;
    return [
      for (final p in people)
        () {
          final sheet = MonthSheet.build(
            from,
            const {},
            r[1].where((l) => l['employee'] == p.employee).toList(),
            (9, 0),
          );
          final rec = records[p.employee];
          final values = _parse(rec?['description']?.toString());
          final base = ctc[p.employee] ?? 0;
          return PayRow(
            person: p,
            fixed:
                values['Оклад'] ??
                structure[p.employee] ??
                (base > 0 ? (base / 12).roundToDouble() : 0),
            bonus: values['Бонус'] ?? 0,
            deduction: values['Удержание'] ?? 0,
            hourly: (values['Почасовая'] ?? 0) == 1,
            paid: rec?['status'] == 'Closed',
            planHours: plan,
            factHours: double.parse(sheet.hours.toStringAsFixed(2)),
            recordName: rec?['name']?.toString(),
          );
        }(),
    ];
  }

  static Map<String, double> _parse(String? html) {
    final out = <String, double>{};
    for (final line in stripHtml(html).split('\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final v = double.tryParse(
        line.substring(i + 1).trim().replaceAll(' ', '').replaceAll(',', '.'),
      );
      if (v != null) out[line.substring(0, i).trim()] = v;
    }
    return out;
  }

  static Future<void> save(PayRow row, DateTime month) async {
    final html =
        '<p>Зарплата ${escapeHtml(row.person.name)} за ${Fmt.monthYear(month).toLowerCase()}</p>'
        '<p>Оклад: ${row.fixed}</p><p>Бонус: ${row.bonus}</p><p>Удержание: ${row.deduction}</p>'
        '<p>Почасовая: ${row.hourly ? 1 : 0}</p>';
    final status = row.paid ? 'Closed' : 'Open';
    if (row.recordName != null) {
      await _api.setValue('ToDo', row.recordName!, {
        'description': html,
        'status': status,
      });
      return;
    }
    final doc = await _api.insert({
      'doctype': 'ToDo',
      'description': html,
      'status': status,
      'priority': 'Low',
      'date': Fmt.iso(DateTime(month.year, month.month)),
      'reference_type': 'Employee',
      'reference_name': row.person.employee,
      'allocated_to': Session.instance.userId,
    });
    row.recordName = doc['name'].toString();
    await _api.addTag('ToDo', row.recordName!, PayTags.pay);
  }
}
