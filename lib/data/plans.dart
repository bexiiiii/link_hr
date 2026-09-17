import '../core/api.dart';
import '../core/fmt.dart';
import '../core/session.dart';

/// Daily plan figures ("Заявки и обращения"), one closed ToDo per day tagged
/// link-plan and allocated to the employee who filled it.
abstract final class PlanTags {
  static const plan = 'link-plan';
}

class DayPlan {
  DayPlan({
    required this.name,
    required this.date,
    required this.value,
    required this.comment,
  });

  final String name;
  final DateTime date;
  final int value;
  final String comment;
}

abstract final class Plans {
  static const metric = 'Заявки и обращения';

  static Api get _api => Api.instance;

  static Future<List<DayPlan>> list(DateTime from, DateTime to) async {
    final rows = await _api.list(
      'ToDo',
      fields: ['name', 'description', 'date'],
      filters: [
        ['_user_tags', 'like', '%${PlanTags.plan}%'],
        ['allocated_to', '=', Session.instance.userId],
        [
          'date',
          'between',
          [Fmt.iso(from), Fmt.iso(to)],
        ],
      ],
      orderBy: 'date desc',
      limit: 1000,
    );
    return [
      for (final r in rows)
        if (Fmt.parse(r['date']) != null) _parse(r),
    ];
  }

  static DayPlan _parse(Json r) {
    final lines = stripHtml(r['description']?.toString()).split('\n');
    final m = RegExp(r'(\d+)').firstMatch(lines.first);
    return DayPlan(
      name: r['name'].toString(),
      date: Fmt.dateOnly(Fmt.parse(r['date'])!),
      value: int.tryParse(m?.group(1) ?? '') ?? 0,
      comment: lines.skip(1).join('\n').trim(),
    );
  }

  static Future<void> save(
    DateTime day,
    int value,
    String comment, {
    String? existing,
  }) async {
    final html =
        '<p>$metric: $value</p>${comment.trim().isEmpty ? '' : '<p>${escapeHtml(comment.trim())}</p>'}';
    if (existing != null) {
      await _api.setValue('ToDo', existing, {'description': html});
      return;
    }
    final doc = await _api.insert({
      'doctype': 'ToDo',
      'description': html,
      'status': 'Closed',
      'priority': 'Low',
      'date': Fmt.iso(day),
      'allocated_to': Session.instance.userId,
    });
    await _api.addTag('ToDo', doc['name'].toString(), PlanTags.plan);
  }
}
