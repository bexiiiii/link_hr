import 'package:flutter/cupertino.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../attendance/attendance_request_form.dart';
import '../attendance/shift_request_form.dart';
import '../finance/advance_form.dart';
import '../finance/expense_form.dart';
import '../leave/leave_form.dart';
import 'request_detail_screen.dart';

enum RequestKind {
  leave('Leave Application', 'Заявления на отпуск', 'Заявление на отпуск', CupertinoIcons.airplane, Tone.violet),
  expense('Expense Claim', 'Авансовые отчёты', 'Авансовый отчёт', CupertinoIcons.creditcard, Tone.green),
  advance('Employee Advance', 'Авансы', 'Аванс', CupertinoIcons.money_dollar_circle, Tone.amber),
  shift('Shift Request', 'Заявки на смену', 'Заявка на смену', CupertinoIcons.clock, Tone.dark),
  attendance('Attendance Request', 'Заявки на отметку', 'Заявка на отметку', CupertinoIcons.location, Tone.violet);

  const RequestKind(this.doctype, this.plural, this.singular, this.icon, this.tone);

  final String doctype;
  final String plural;
  final String singular;
  final IconData icon;
  final Tone tone;

  static RequestKind? fromDoctype(String? doctype) =>
      RequestKind.values.where((k) => k.doctype == doctype).firstOrNull;

  bool get hasTeam => this != RequestKind.advance;

  /// Field an approver flips to Approved / Rejected before submitting.
  String? get approvalField => switch (this) {
        RequestKind.leave => 'status',
        RequestKind.expense => 'approval_status',
        RequestKind.shift => 'status',
        _ => null,
      };

  String? get approverField => switch (this) {
        RequestKind.leave => 'leave_approver',
        RequestKind.expense => 'expense_approver',
        RequestKind.shift => 'approver',
        _ => null,
      };

  String? get pendingStatus => switch (this) {
        RequestKind.leave => 'Open',
        RequestKind.expense || RequestKind.shift => 'Draft',
        _ => null,
      };

  Future<List<Json>> fetch({bool team = false, int? limit}) => switch (this) {
        RequestKind.leave => Hr.leaves(team: team, limit: limit),
        RequestKind.expense => Hr.expenseClaims(team: team, limit: limit),
        RequestKind.advance => team ? Future.value(<Json>[]) : Hr.advances(limit: limit),
        RequestKind.shift => Hr.shiftRequests(team: team, limit: limit),
        RequestKind.attendance => Hr.attendanceRequests(team: team, limit: limit),
      };

  Widget form({Json? doc}) => switch (this) {
        RequestKind.leave => LeaveForm(doc: doc),
        RequestKind.expense => ExpenseForm(doc: doc),
        RequestKind.advance => AdvanceForm(doc: doc),
        RequestKind.shift => ShiftRequestForm(doc: doc),
        RequestKind.attendance => AttendanceRequestForm(doc: doc),
      };

  String status(Json d) {
    final wf = d['workflow_state_field']?.toString();
    if (wf != null && wf.isNotEmpty && (d[wf]?.toString() ?? '').isNotEmpty) return d[wf].toString();
    final docstatus = Fmt.number(d['docstatus']).toInt();
    if (docstatus == 2) return 'Cancelled';
    return switch (this) {
      RequestKind.leave || RequestKind.shift => d['status']?.toString() ?? 'Open',
      RequestKind.expense => d['approval_status']?.toString() ?? 'Draft',
      RequestKind.advance => docstatus == 0 ? 'Draft' : (d['status']?.toString() ?? 'Submitted'),
      RequestKind.attendance => docstatus == 1 ? 'Submitted' : 'Draft',
    };
  }

  String heading(Json d) => switch (this) {
        RequestKind.leave => d['leave_type']?.toString() ?? singular,
        RequestKind.expense => () {
            final type = d['expense_type']?.toString() ?? 'Расходы';
            final n = Fmt.number(d['total_expenses']).toInt();
            return n > 1 ? '$type и ещё ${n - 1}' : type;
          }(),
        RequestKind.advance => stripHtml(d['purpose']?.toString()).split('\n').first,
        RequestKind.shift => d['shift_type']?.toString() ?? singular,
        RequestKind.attendance => statusLabel(d['reason']?.toString() ?? 'Work From Home'),
      };

  String subtitle(Json d) {
    final currency = d['currency']?.toString() ?? Session.instance.currency;
    return switch (this) {
      RequestKind.leave => '${Fmt.range(d['from_date'], d['to_date'])} · ${Fmt.days(d['total_leave_days'])}',
      RequestKind.expense => '${Fmt.money(d['total_claimed_amount'], currency)} · ${Fmt.dayMonth(d['posting_date'])}',
      RequestKind.advance => '${Fmt.money(d['advance_amount'], currency)} · ${Fmt.dayMonth(d['posting_date'])}',
      RequestKind.shift => Fmt.range(d['from_date'], d['to_date']),
      RequestKind.attendance => Fmt.range(d['from_date'], d['to_date']),
    };
  }
}

/// Mixes every request kind into one feed, newest first, like the PWA's
/// "My Requests / Team Requests" panel.
Future<List<(RequestKind, Json)>> fetchRequestFeed({required bool team, int perKind = 10}) async {
  final kinds = team ? RequestKind.values.where((k) => k.hasTeam).toList() : RequestKind.values;
  final results = await Future.wait(kinds.map((k) => k.fetch(team: team, limit: perKind).then(
        (rows) => rows.map((r) => (k, r)).toList(),
        onError: (_) => <(RequestKind, Json)>[],
      )));
  final all = results.expand((e) => e).toList()
    ..sort((a, b) => (Fmt.parse(b.$2['creation']) ?? DateTime(2000)).compareTo(Fmt.parse(a.$2['creation']) ?? DateTime(2000)));
  return all.take(10).toList();
}

class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.kind, required this.data, this.showEmployee = false, this.onChanged});

  final RequestKind kind;
  final Json data;
  final bool showEmployee;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        radius: AppRadius.tile,
        padding: const EdgeInsets.all(16),
        onTap: () async {
          await pushPage(context, RequestDetailScreen(kind: kind, name: data['name'].toString()));
          onChanged?.call();
        },
        child: Row(children: [
          IconBadge(icon: kind.icon, tone: kind.tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showEmployee && (data['employee_name'] ?? '').toString().isNotEmpty) ...[
                Text(data['employee_name'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: AppColors.violet, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
              ],
              Text(kind.heading(data),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(fontSize: 15)),
              const SizedBox(height: 3),
              Text(kind.subtitle(data), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            ]),
          ),
          const SizedBox(width: 10),
          StatusPill(kind.status(data)),
        ]),
      ),
    );
  }
}
