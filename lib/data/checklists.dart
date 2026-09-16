import '../core/api.dart';
import '../core/files.dart';
import '../core/fmt.dart';
import '../core/session.dart';

/// Daily checklists on ToDo, without schema changes:
///   template  ToDo tagged link-cl-template, allocated to the employee, items as
///             child ToDos (reference_type ToDo).
///   run       ToDo tagged link-cl-run for one day, referencing its template,
///             with its own child items: Open / Closed (done) / Cancelled (failed).
/// The time window and photo requirement are human-readable lines in the
/// description so they also read correctly in Frappe Desk.
abstract final class ChecklistTags {
  static const template = 'link-cl-template';
  static const run = 'link-cl-run';
}

enum ItemState { open, done, failed }

class ChecklistItem {
  ChecklistItem({required this.name, required this.title, required this.state});

  final String name;
  final String title;
  ItemState state;
}

class ChecklistMeta {
  const ChecklistMeta({required this.title, this.from, this.to, this.photo = false});

  final String title;
  final String? from;
  final String? to;
  final bool photo;

  String get window => from == null ? 'В течение дня' : '$from - ${to ?? ''}';

  String toHtml() => [
        '<p>${escapeHtml(title)}</p>',
        if (from != null) '<p>Время: $from-${to ?? from}</p>',
        if (photo) '<p>Фото-отчёт обязателен</p>',
      ].join();

  static ChecklistMeta parse(String? html) {
    final lines = stripHtml(html).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String? from;
    String? to;
    var photo = false;
    final rest = <String>[];
    for (final l in lines) {
      final m = RegExp(r'^Время:\s*(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})').firstMatch(l);
      if (m != null) {
        from = m.group(1);
        to = m.group(2);
      } else if (l.startsWith('Фото-отчёт')) {
        photo = true;
      } else {
        rest.add(l);
      }
    }
    return ChecklistMeta(title: rest.isEmpty ? 'Чеклист' : rest.first, from: from, to: to, photo: photo);
  }
}

class ChecklistRun {
  ChecklistRun({
    required this.name,
    required this.template,
    required this.meta,
    required this.date,
    required this.closed,
    required this.allocatedTo,
    this.items = const [],
    this.attachments = const [],
  });

  final String name;
  final String template;
  final ChecklistMeta meta;
  final DateTime? date;
  bool closed;
  final String allocatedTo;
  final List<ChecklistItem> items;
  final List<Attachment> attachments;

  bool get allMarked => items.every((i) => i.state != ItemState.open);
  int get doneCount => items.where((i) => i.state == ItemState.done).length;
}

class ChecklistTemplate {
  ChecklistTemplate({required this.name, required this.meta, required this.allocatedTo, required this.itemCount});

  final String name;
  final ChecklistMeta meta;
  final String allocatedTo;
  final int itemCount;
}

abstract final class Checklists {
  static Api get _api => Api.instance;

  static Future<List<ChecklistTemplate>> templates({bool mineOnly = false}) async {
    final rows = await _api.list('ToDo',
        fields: ['name', 'description', 'allocated_to'],
        filters: [
          ['_user_tags', 'like', '%${ChecklistTags.template}%'],
          ['status', '=', 'Open'],
          if (mineOnly) ['allocated_to', '=', Session.instance.userId],
        ],
        orderBy: 'creation asc',
        limit: 500);
    final items = await _children(rows.map((r) => r['name'].toString()).toList());
    return [
      for (final r in rows)
        ChecklistTemplate(
          name: r['name'].toString(),
          meta: ChecklistMeta.parse(r['description']?.toString()),
          allocatedTo: r['allocated_to']?.toString() ?? '',
          itemCount: (items[r['name']] ?? const []).length,
        ),
    ];
  }

  static Future<void> createTemplate({
    required ChecklistMeta meta,
    required List<String> items,
    required List<String> assignees,
  }) async {
    for (final user in assignees.isEmpty ? [Session.instance.userId] : assignees) {
      final doc = await _api.insert({
        'doctype': 'ToDo',
        'description': meta.toHtml(),
        'status': 'Open',
        'allocated_to': user,
        'assigned_by': Session.instance.userId,
      });
      final name = doc['name'].toString();
      await _api.addTag('ToDo', name, ChecklistTags.template);
      for (final item in items.where((i) => i.trim().isNotEmpty)) {
        await _insertItem(name, item.trim(), user);
      }
    }
  }

  static Future<void> archiveTemplate(String name) => _api.setValue('ToDo', name, {'status': 'Cancelled'});

  /// Creates today's runs for the current user's templates that have none yet.
  static Future<List<ChecklistRun>> today() async {
    final me = Session.instance.userId;
    final todayIso = Fmt.iso(DateTime.now());
    final results = await Future.wait([
      _api.list('ToDo',
          fields: ['name', 'description'],
          filters: [
            ['_user_tags', 'like', '%${ChecklistTags.template}%'],
            ['status', '=', 'Open'],
            ['allocated_to', '=', me],
          ],
          limit: 200),
      _runRows(from: DateTime.now(), to: DateTime.now(), user: me),
    ]);
    final templates = results[0];
    final existing = {for (final r in results[1]) r['reference_name'].toString()};
    final missing = templates.where((t) => !existing.contains(t['name'].toString())).toList();
    if (missing.isNotEmpty) {
      final templateItems = await _children(missing.map((t) => t['name'].toString()).toList());
      for (final t in missing) {
        final doc = await _api.insert({
          'doctype': 'ToDo',
          'description': t['description'],
          'status': 'Open',
          'date': todayIso,
          'reference_type': 'ToDo',
          'reference_name': t['name'],
          'allocated_to': me,
        });
        final name = doc['name'].toString();
        await _api.addTag('ToDo', name, ChecklistTags.run);
        for (final item in templateItems[t['name']] ?? const <Json>[]) {
          await _insertItem(name, stripHtml(item['description']?.toString()), me);
        }
      }
    }
    return runs(from: DateTime.now(), to: DateTime.now(), user: me);
  }

  static Future<List<ChecklistRun>> runs({required DateTime from, required DateTime to, String? user}) async {
    final rows = await _runRows(from: from, to: to, user: user);
    final items = await _children(rows.map((r) => r['name'].toString()).toList());
    final list = [for (final r in rows) _run(r, items[r['name']] ?? const [])];
    list.sort((a, b) => (a.meta.from ?? '99').compareTo(b.meta.from ?? '99'));
    return list;
  }

  static Future<ChecklistRun> get(String name) async {
    final results = await Future.wait<Object>([
      _api.doc('ToDo', name),
      _children([name]),
      Files.list('ToDo', name),
    ]);
    final items = (results[1] as Map<String, List<Json>>)[name] ?? const [];
    return _run(results[0] as Json, items, results[2] as List<Attachment>);
  }

  static Future<void> setItem(ChecklistItem item, ItemState state) => _api.setValue('ToDo', item.name, {
        'status': switch (state) {
          ItemState.done => 'Closed',
          ItemState.failed => 'Cancelled',
          ItemState.open => 'Open',
        },
      });

  static Future<void> complete(ChecklistRun run) => _api.setValue('ToDo', run.name, {'status': 'Closed'});

  static ChecklistRun _run(Json r, List<Json> items, [List<Attachment> files = const []]) => ChecklistRun(
        name: r['name'].toString(),
        template: r['reference_name']?.toString() ?? '',
        meta: ChecklistMeta.parse(r['description']?.toString()),
        date: Fmt.parse(r['date']),
        closed: r['status'] == 'Closed',
        allocatedTo: r['allocated_to']?.toString() ?? '',
        items: [
          for (final i in items)
            ChecklistItem(
              name: i['name'].toString(),
              title: stripHtml(i['description']?.toString()),
              state: switch (i['status']) {
                'Closed' => ItemState.done,
                'Cancelled' => ItemState.failed,
                _ => ItemState.open,
              },
            ),
        ],
        attachments: files,
      );

  static Future<List<Json>> _runRows({required DateTime from, required DateTime to, String? user}) =>
      _api.list('ToDo',
          fields: ['name', 'description', 'status', 'date', 'reference_name', 'allocated_to'],
          filters: [
            ['_user_tags', 'like', '%${ChecklistTags.run}%'],
            ['date', 'between', [Fmt.iso(from), Fmt.iso(to)]],
            if (user != null) ['allocated_to', '=', user],
          ],
          orderBy: 'date asc',
          limit: 2000);

  static Future<Map<String, List<Json>>> _children(List<String> parents) async {
    if (parents.isEmpty) return {};
    final rows = await _api.list('ToDo',
        fields: ['name', 'description', 'status', 'reference_name'],
        filters: [
          ['reference_type', '=', 'ToDo'],
          ['reference_name', 'in', parents],
        ],
        orderBy: 'creation asc',
        limit: 5000);
    final map = <String, List<Json>>{};
    for (final r in rows) {
      map.putIfAbsent(r['reference_name'].toString(), () => []).add(r);
    }
    return map;
  }

  static Future<void> _insertItem(String parent, String title, String user) => _api.insert({
        'doctype': 'ToDo',
        'description': escapeHtml(title),
        'status': 'Open',
        'reference_type': 'ToDo',
        'reference_name': parent,
        'allocated_to': user,
      });
}
