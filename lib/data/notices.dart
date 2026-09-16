import '../core/api.dart';
import '../core/fmt.dart';
import '../core/media.dart';
import '../core/session.dart';

/// Announcements ("Оповещение") and document signature requests, both stored
/// as tagged ToDos addressed to each recipient.
abstract final class NoticeTags {
  static const notice = 'link-notice';
  static const sign = 'link-sign';
}

class Notice {
  Notice({
    required this.name,
    required this.title,
    required this.body,
    required this.from,
    required this.date,
    required this.created,
    required this.read,
  });

  final String name;
  final String title;
  final String body;
  final String from;
  final DateTime? date;
  final DateTime? created;
  bool read;
}

class SignRequest {
  SignRequest({
    required this.name,
    required this.doctype,
    required this.docname,
    required this.to,
    required this.from,
    required this.signed,
    required this.modified,
  });

  final String name;
  final String doctype;
  final String docname;
  final String to;
  final String from;
  final bool signed;
  final DateTime? modified;
}

abstract final class Notices {
  static Api get _api => Api.instance;

  static Future<int> send({
    required String title,
    required String body,
    required List<String> recipients,
    required DateTime when,
    List<PendingFile> files = const [],
  }) async {
    final html = '<p>${escapeHtml(title)}</p>'
        '${body.trim().isEmpty ? '' : '<p>${escapeHtml(body.trim()).replaceAll('\n', '<br>')}</p>'}'
        '<p>Дата: ${Fmt.long(when)}, ${Fmt.time(when)}</p>';
    for (final user in recipients.toSet()) {
      final doc = await _api.insert({
        'doctype': 'ToDo',
        'description': html,
        'status': 'Open',
        'priority': 'High',
        'date': Fmt.iso(when),
        'allocated_to': user,
        'assigned_by': Session.instance.userId,
      });
      final name = doc['name'].toString();
      await _api.addTag('ToDo', name, NoticeTags.notice);
      for (final f in files) {
        await f.upload('ToDo', name);
      }
    }
    return recipients.toSet().length;
  }

  static Future<List<Notice>> mine({bool unreadOnly = false}) async {
    final rows = await _api.list('ToDo',
        fields: ['name', 'description', 'status', 'owner', 'date', 'creation'],
        filters: [
          ['_user_tags', 'like', '%${NoticeTags.notice}%'],
          ['allocated_to', '=', Session.instance.userId],
          if (unreadOnly) ['status', '=', 'Open'],
          if (unreadOnly) ['date', '<=', Fmt.iso(DateTime.now())],
        ],
        orderBy: 'creation desc',
        limit: 100);
    return rows.map((r) {
      final lines = stripHtml(r['description']?.toString()).split('\n').where((l) => !l.startsWith('Дата:')).toList();
      return Notice(
        name: r['name'].toString(),
        title: lines.isEmpty ? 'Оповещение' : lines.first,
        body: lines.skip(1).join('\n').trim(),
        from: r['owner']?.toString() ?? '',
        date: Fmt.parse(r['date']),
        created: Fmt.parse(r['creation']),
        read: r['status'] == 'Closed',
      );
    }).toList();
  }

  static Future<void> acknowledge(String name) => _api.setValue('ToDo', name, {'status': 'Closed'});

  static Future<void> requestSignature({
    required String doctype,
    required String docname,
    required String userId,
    required String title,
  }) async {
    final doc = await _api.insert({
      'doctype': 'ToDo',
      'description': '<p>Подпишите документ: ${escapeHtml(title)}</p>',
      'status': 'Open',
      'priority': 'High',
      'date': Fmt.iso(DateTime.now()),
      'reference_type': doctype,
      'reference_name': docname,
      'allocated_to': userId,
      'assigned_by': Session.instance.userId,
    });
    await _api.addTag('ToDo', doc['name'].toString(), NoticeTags.sign);
  }

  static Future<List<SignRequest>> signRequests() async {
    final rows = await _api.list('ToDo',
        fields: ['name', 'reference_type', 'reference_name', 'allocated_to', 'owner', 'status', 'modified'],
        filters: [
          ['_user_tags', 'like', '%${NoticeTags.sign}%'],
          ['status', '!=', 'Cancelled'],
        ],
        orderBy: 'modified desc',
        limit: 1000);
    return [
      for (final r in rows)
        SignRequest(
          name: r['name'].toString(),
          doctype: r['reference_type']?.toString() ?? '',
          docname: r['reference_name']?.toString() ?? '',
          to: r['allocated_to']?.toString() ?? '',
          from: r['owner']?.toString() ?? '',
          signed: r['status'] == 'Closed',
          modified: Fmt.parse(r['modified']),
        ),
    ];
  }

  static Future<void> sign(String name) => _api.setValue('ToDo', name, {'status': 'Closed'});
}
