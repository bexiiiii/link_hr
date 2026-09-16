import '../core/api.dart';
import '../core/files.dart';
import '../core/fmt.dart';
import '../core/media.dart';
import '../core/session.dart';
import 'hr.dart';

/// Tasks live on Frappe's ToDo doctype (the Employee role can read, create and
/// update it). Mapping:
///   owner        -> author
///   allocated_to -> executor
///   assigned_by  -> reviewer ("Проверяющий")
///   status       -> Open / Closed (done) / Cancelled (archived)
///   _user_tags   -> link-work (taken into work), link-review (sent for review),
///                   link-voice (has a voice description)
/// Subtasks are ToDos whose reference points at the parent ToDo. Checklists,
/// notices and signature requests are ToDos too and carry their own tags.
enum TaskStatus {
  inProgress('Open', 'В работе'),
  completed('Closed', 'Выполнено'),
  onHold('Cancelled', 'Отложено');

  const TaskStatus(this.remote, this.label);

  final String remote;
  final String label;

  static TaskStatus fromRemote(String? s) => switch (s) {
        'Closed' => TaskStatus.completed,
        'Cancelled' => TaskStatus.onHold,
        _ => TaskStatus.inProgress,
      };
}

enum TaskStage {
  todo('К выполнению'),
  inWork('В работе'),
  review('На проверке'),
  done('Выполнено'),
  archived('В архиве');

  const TaskStage(this.label);

  final String label;
}

abstract final class TaskTags {
  static const work = 'link-work';
  static const review = 'link-review';
  static const voice = 'link-voice';

  /// Prefix shared by every non-task ToDo the app creates.
  static const service = ['link-cl-', 'link-notice', 'link-sign', 'link-plan', 'link-pay'];
}

const taskPriorities = ['Low', 'Medium', 'High'];

class Subtask {
  Subtask({required this.name, required this.title, required this.done});

  final String name;
  final String title;
  bool done;
}

class TaskItem {
  TaskItem({
    required this.name,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.due,
    required this.created,
    required this.modified,
    required this.allocatedTo,
    required this.assignedBy,
    required this.owner,
    required this.tags,
    this.subtasks = const [],
    this.subtaskTotal = 0,
    this.subtaskDone = 0,
  });

  final String name;
  final String title;
  final String description;
  TaskStatus status;
  final String priority;
  final DateTime? due;
  final DateTime? created;
  final DateTime? modified;
  final String allocatedTo;
  final String assignedBy;
  final String owner;
  final Set<String> tags;
  final List<Subtask> subtasks;
  final int subtaskTotal;
  final int subtaskDone;

  String get reviewer => assignedBy == allocatedTo ? '' : assignedBy;
  bool get hasVoice => tags.contains(TaskTags.voice);

  TaskStage get stage => switch (status) {
        TaskStatus.completed => TaskStage.done,
        TaskStatus.onHold => TaskStage.archived,
        _ when tags.contains(TaskTags.review) => TaskStage.review,
        _ when tags.contains(TaskTags.work) => TaskStage.inWork,
        _ => TaskStage.todo,
      };

  bool get overdue =>
      status == TaskStatus.inProgress && due != null && Fmt.dateOnly(due!).isBefore(Fmt.dateOnly(DateTime.now()));

  List<String> get people => {
        if (allocatedTo.isNotEmpty) allocatedTo,
        if (reviewer.isNotEmpty) reviewer,
      }.toList();

  static (String, String) splitDescription(String? html) {
    final text = stripHtml(html);
    if (text.isEmpty) return ('Без названия', '');
    final newline = text.indexOf('\n');
    if (newline > 0) return (text.substring(0, newline).trim(), text.substring(newline + 1).trim());
    return (text, '');
  }

  static String composeDescription(String title, String description) {
    final body = description.trim();
    return body.isEmpty
        ? '<p>${escapeHtml(title.trim())}</p>'
        : '<p>${escapeHtml(title.trim())}</p><p>${escapeHtml(body).replaceAll('\n', '<br>')}</p>';
  }

  static Set<String> parseTags(Object? raw) =>
      (raw?.toString() ?? '').split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();

  factory TaskItem.fromJson(Json j, {List<Subtask> subtasks = const [], int total = 0, int done = 0}) {
    final (title, description) = splitDescription(j['description']?.toString());
    return TaskItem(
      name: j['name'].toString(),
      title: title,
      description: description,
      status: TaskStatus.fromRemote(j['status']?.toString()),
      priority: j['priority']?.toString() ?? 'Medium',
      due: Fmt.parse(j['date']),
      created: Fmt.parse(j['creation']),
      modified: Fmt.parse(j['modified']),
      allocatedTo: j['allocated_to']?.toString() ?? '',
      assignedBy: j['assigned_by']?.toString() ?? '',
      owner: j['owner']?.toString() ?? '',
      tags: parseTags(j['_user_tags']),
      subtasks: subtasks,
      subtaskTotal: subtasks.isNotEmpty ? subtasks.length : total,
      subtaskDone: subtasks.isNotEmpty ? subtasks.where((s) => s.done).length : done,
    );
  }
}

abstract final class Tasks {
  static Api get _api => Api.instance;

  static const _fields = [
    'name',
    'description',
    'status',
    'priority',
    'date',
    'allocated_to',
    'assigned_by',
    'owner',
    '_user_tags',
    'creation',
    'modified',
  ];

  static List<List<Object>> get _taskFilters => [
        ['reference_type', '!=', 'ToDo'],
        for (final t in TaskTags.service) ['_user_tags', 'not like', '%$t%'],
      ];

  static Future<List<TaskItem>> list() async {
    final results = await Future.wait([
      _api.list('ToDo', fields: _fields, filters: _taskFilters, orderBy: 'modified desc', limit: 500),
      _api.list('ToDo',
          fields: ['name', 'status', 'reference_name'],
          filters: [
            ['reference_type', '=', 'ToDo'],
            ['status', '!=', 'Cancelled'],
          ],
          limit: 3000),
    ]);
    final counts = <String, (int, int)>{};
    for (final s in results[1]) {
      final parent = s['reference_name']?.toString() ?? '';
      final (total, done) = counts[parent] ?? (0, 0);
      counts[parent] = (total + 1, done + (s['status'] == 'Closed' ? 1 : 0));
    }
    return results[0].map((j) {
      final (total, done) = counts[j['name']] ?? (0, 0);
      return TaskItem.fromJson(j, total: total, done: done);
    }).toList();
  }

  static Future<TaskItem> get(String name) async {
    final results = await Future.wait([
      _api.doc('ToDo', name),
      _api.list('ToDo',
          fields: ['name', 'description', 'status'],
          filters: [
            ['reference_type', '=', 'ToDo'],
            ['reference_name', '=', name],
            ['status', '!=', 'Cancelled'],
          ],
          orderBy: 'creation asc',
          limit: 500),
    ]);
    final subtasks = (results[1] as List<Json>)
        .map((s) => Subtask(
              name: s['name'].toString(),
              title: stripHtml(s['description']?.toString()),
              done: s['status'] == 'Closed',
            ))
        .toList();
    return TaskItem.fromJson(results[0] as Json, subtasks: subtasks);
  }

  /// Creates one task per executor, uploading the voice note and files to each.
  static Future<List<String>> create({
    required String text,
    required DateTime? due,
    required List<String> executors,
    String reviewer = '',
    VoiceClip? voice,
    List<PendingFile> files = const [],
    List<String> subtasks = const [],
    String priority = 'Medium',
  }) async {
    final me = Session.instance.userId;
    final lines = text.trim().split('\n');
    final title = lines.first.trim().isEmpty ? (voice != null ? 'Голосовая задача' : 'Новая задача') : lines.first.trim();
    final body = lines.skip(1).join('\n');
    final voiceFile = await voice?.toPending();
    final targets = executors.isEmpty ? [me] : executors;
    final names = <String>[];
    for (final executor in targets) {
      final doc = await _api.insert({
        'doctype': 'ToDo',
        'description': TaskItem.composeDescription(title, body),
        'status': 'Open',
        'priority': priority,
        'date': due == null ? null : Fmt.iso(due),
        'allocated_to': executor,
        'assigned_by': reviewer.isEmpty ? me : reviewer,
      });
      final name = doc['name'].toString();
      names.add(name);
      if (voiceFile != null) {
        await voiceFile.upload('ToDo', name);
        await _api.addTag('ToDo', name, TaskTags.voice);
      }
      for (final f in files) {
        await f.upload('ToDo', name);
      }
      for (final s in subtasks.where((s) => s.trim().isNotEmpty)) {
        await addSubtask(name, s.trim(), allocatedTo: executor);
      }
    }
    return names;
  }

  static Future<void> update(
    String name, {
    required String title,
    required String description,
    required DateTime? due,
    required String priority,
    required String allocatedTo,
    String? reviewer,
  }) =>
      _api.setValue('ToDo', name, {
        'description': TaskItem.composeDescription(title, description),
        'date': due == null ? null : Fmt.iso(due),
        'priority': priority,
        if (allocatedTo.isNotEmpty) 'allocated_to': allocatedTo,
        if (reviewer != null) 'assigned_by': reviewer.isEmpty ? Session.instance.userId : reviewer,
      });

  static Future<void> setStatus(String name, TaskStatus status) =>
      _api.setValue('ToDo', name, {'status': status.remote});

  static Future<void> setStage(TaskItem task, TaskStage stage) async {
    Future<void> tag(String t, bool on) async {
      if (on && !task.tags.contains(t)) {
        await _api.addTag('ToDo', task.name, t);
        task.tags.add(t);
      } else if (!on && task.tags.contains(t)) {
        await _api.removeTag('ToDo', task.name, t);
        task.tags.remove(t);
      }
    }

    final status = switch (stage) {
      TaskStage.done => TaskStatus.completed,
      TaskStage.archived => TaskStatus.onHold,
      _ => TaskStatus.inProgress,
    };
    if (task.status != status) {
      await setStatus(task.name, status);
      task.status = status;
    }
    await tag(TaskTags.work, stage == TaskStage.inWork || stage == TaskStage.review);
    await tag(TaskTags.review, stage == TaskStage.review);
  }

  static Future<void> setDue(String name, DateTime? due) =>
      _api.setValue('ToDo', name, {'date': due == null ? null : Fmt.iso(due)});

  static Future<void> setAssignee(String name, String user) => _api.setValue('ToDo', name, {'allocated_to': user});

  static Future<Subtask> addSubtask(String parent, String title, {String? allocatedTo}) async {
    final doc = await _api.insert({
      'doctype': 'ToDo',
      'description': escapeHtml(title),
      'status': 'Open',
      'reference_type': 'ToDo',
      'reference_name': parent,
      'allocated_to': (allocatedTo == null || allocatedTo.isEmpty) ? Session.instance.userId : allocatedTo,
    });
    return Subtask(name: doc['name'].toString(), title: title, done: false);
  }

  static Future<void> toggleSubtask(Subtask s, bool done) =>
      _api.setValue('ToDo', s.name, {'status': done ? 'Closed' : 'Open'});

  static Future<void> removeSubtask(Subtask s) => _api.setValue('ToDo', s.name, {'status': 'Cancelled'});

  static Future<void> delete(String name) => _api.delete('ToDo', name);

  static Future<Attachment?> voiceOf(String name) async {
    final files = await Files.list('ToDo', name);
    return files.where((f) => RegExp(r'\.(m4a|aac|mp3|wav|caf)$', caseSensitive: false).hasMatch(f.fileName)).lastOrNull;
  }

  /// People the current user works with most, by shared tasks.
  static List<String> frequentPeople(List<TaskItem> tasks, {int limit = 5}) {
    final me = Session.instance.userId;
    final counts = <String, int>{};
    for (final t in tasks) {
      for (final id in {t.owner, t.allocatedTo, t.assignedBy}) {
        if (id.isNotEmpty && id != me && id != 'Administrator') counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// user id -> (display name, image) from the employee directory.
  static Future<Map<String, (String, String?)>> people() async {
    try {
      final list = await Hr.employees();
      return {
        for (final e in list)
          if ((e['user_id'] ?? '').toString().isNotEmpty)
            e['user_id'].toString(): (e['employee_name']?.toString() ?? e['user_id'].toString(), e['image']?.toString()),
      };
    } catch (_) {
      return {};
    }
  }
}
