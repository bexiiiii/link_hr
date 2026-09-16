import 'package:flutter/cupertino.dart';

import '../../core/api.dart';
import '../../core/files.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import 'request_kind.dart';

/// Inserts a new request (then opens it) or saves edits to an existing one.
Future<void> persistRequest(BuildContext context, RequestKind kind, Json? original, Json values) async {
  final api = Api.instance;
  final s = Session.instance;
  if (original == null) {
    final saved = await api.insert({
      'doctype': kind.doctype,
      'employee': s.employeeId,
      'company': s.company,
      ...values,
    });
    s.notifyDataChanged();
    if (!context.mounted) return;
    showToast(context, 'Заявка отправлена');
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (_) => RequestDetailScreen(kind: kind, name: saved['name'].toString())),
    );
  } else {
    await api.save({...original, ...values});
    s.notifyDataChanged();
    if (!context.mounted) return;
    showToast(context, 'Изменения сохранены');
    Navigator.pop(context, true);
  }
}

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.kind, required this.name});

  final RequestKind kind;
  final String name;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _api = Api.instance;
  final _session = Session.instance;

  Json? _doc;
  Map<String, bool> _perms = {};
  Json _workflow = {};
  List<String> _transitions = [];
  List<String> _writable = [];
  List<Attachment> _files = [];
  bool _loading = true;
  Object? _error;
  String? _busy;
  bool _uploading = false;

  RequestKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await _api.doc(kind.doctype, widget.name);
      final results = await Future.wait<Object>([
        Hr.docPermissions(kind.doctype, widget.name).catchError((_) => <String, bool>{}),
        Hr.workflow(kind.doctype).catchError((_) => <String, dynamic>{}),
        Hr.writableFields(kind.doctype).catchError((_) => <String>[]),
        Files.list(kind.doctype, widget.name).catchError((_) => <Attachment>[]),
      ]);
      final workflow = results[1] as Json;
      var transitions = <String>[];
      if (workflow.isNotEmpty && Fmt.number(doc['docstatus']) != 2) {
        transitions = await Hr.workflowTransitions(doc).catchError((_) => <String>[]);
      }
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _perms = results[0] as Map<String, bool>;
        _workflow = workflow;
        _writable = results[2] as List<String>;
        _files = results[3] as List<Attachment>;
        _transitions = transitions;
        _loading = false;
        _error = null;
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

  String get _status {
    final doc = _doc!;
    final field = _workflow['workflow_state_field']?.toString();
    final overrides = _workflow['override_status'] == 1 || _workflow['override_status'] == true;
    if (_workflow.isNotEmpty && !overrides && field != null && (doc[field] ?? '').toString().isNotEmpty) {
      return doc[field].toString();
    }
    return kind.status(doc);
  }

  bool get _isOwn => _doc?['employee'] == _session.employeeId;

  Future<void> _run(String key, Future<void> Function() action, String success) async {
    setState(() => _busy = key);
    try {
      await action();
      _session.notifyDataChanged();
      if (mounted) showToast(context, success);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _setApproval(String value) => _run(
        value,
        () => _api.setValue(kind.doctype, widget.name, {kind.approvalField!: value}),
        value == 'Approved' ? 'Заявка одобрена' : 'Заявка отклонена',
      );

  Future<void> _submit() async {
    final ok = await confirmAction(context,
        title: 'Провести документ?',
        message: 'После проведения заявку нельзя будет изменить.',
        confirmLabel: 'Провести');
    if (!ok) return;
    await _run('submit', () async {
      final fresh = await _api.doc(kind.doctype, widget.name);
      await _api.submit(fresh);
    }, 'Документ проведён');
  }

  Future<void> _cancel() async {
    final ok = await confirmAction(context,
        title: 'Отменить документ?',
        message: 'Проведённая заявка будет отменена.',
        confirmLabel: 'Отменить документ',
        destructive: true);
    if (!ok) return;
    await _run('cancel', () => _api.cancel(kind.doctype, widget.name), 'Документ отменён');
  }

  Future<void> _delete() async {
    final ok = await confirmAction(context,
        title: 'Удалить заявку?', message: 'Черновик будет удалён.', confirmLabel: 'Удалить', destructive: true);
    if (!ok) return;
    try {
      await _api.delete(kind.doctype, widget.name);
      _session.notifyDataChanged();
      if (mounted) {
        showToast(context, 'Заявка удалена');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _more() async {
    final doc = _doc!;
    final ds = Fmt.number(doc['docstatus']).toInt();
    final pending = kind.approvalField == null || doc[kind.approvalField] == kind.pendingStatus;
    final canEdit = ds == 0 && (_perms['write'] ?? false) && _isOwn && pending;
    final canDelete = ds == 0 && (_perms['delete'] ?? false) && _isOwn;
    final canCancel = ds == 1 && (_perms['cancel'] ?? false);
    final action = await pickAction(context, actions: [
      if (canEdit) const SheetAction('edit', 'Редактировать'),
      const SheetAction('pdf', 'Открыть PDF'),
      if (canCancel) const SheetAction('cancel', 'Отменить документ', destructive: true),
      if (canDelete) const SheetAction('delete', 'Удалить', destructive: true),
    ]);
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        final saved = await pushPage<bool>(context, kind.form(doc: doc));
        if (saved == true) _load();
      case 'pdf':
        try {
          await Files.openPrint(kind.doctype, widget.name);
        } catch (e) {
          if (mounted) showToast(context, errorText(e), error: true);
        }
      case 'cancel':
        _cancel();
      case 'delete':
        _delete();
    }
  }

  Future<void> _attach() async {
    setState(() => _uploading = true);
    try {
      final file = await Files.pickAndUpload(kind.doctype, widget.name);
      if (file != null && mounted) {
        setState(() => _files.add(file));
        showToast(context, 'Файл прикреплён');
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  List<(String, String)> _rows(Json d) {
    final cur = d['currency']?.toString() ?? _session.currency;
    String money(String f) => Fmt.number(d[f]) == 0 ? '' : Fmt.money(d[f], cur);
    String date(String f) => Fmt.long(d[f]);
    String yes(String f) => (d[f] == 1 || d[f] == true) ? 'Да' : '';
    String text(String f) => stripHtml(d[f]?.toString());
    return switch (kind) {
      RequestKind.leave => [
          ('Сотрудник', text('employee_name')),
          ('Тип отпуска', text('leave_type')),
          ('С', date('from_date')),
          ('По', date('to_date')),
          ('Полдня', yes('half_day').isEmpty ? '' : Fmt.long(d['half_day_date'] ?? d['from_date'])),
          ('Количество дней', Fmt.days(d['total_leave_days'])),
          ('Остаток на дату подачи', d['leave_balance'] == null ? '' : Fmt.days(d['leave_balance'])),
          ('Согласующий', text('leave_approver_name').isEmpty ? text('leave_approver') : text('leave_approver_name')),
          ('Дата подачи', date('posting_date')),
          ('Причина', text('description')),
        ],
      RequestKind.expense => [
          ('Сотрудник', text('employee_name')),
          ('Дата', date('posting_date')),
          ('Согласующий', text('expense_approver')),
          ('Заявлено', money('total_claimed_amount')),
          ('Утверждено', money('total_sanctioned_amount')),
          ('Налоги и сборы', money('total_taxes_and_charges')),
          ('Зачтено авансов', money('total_advance_amount')),
          ('Итого к выплате', money('grand_total')),
          ('Статус оплаты', statusLabel(text('status'))),
          ('Комментарий', text('remark')),
        ],
      RequestKind.advance => [
          ('Сотрудник', text('employee_name')),
          ('Дата', date('posting_date')),
          ('Цель', text('purpose')),
          ('Сумма аванса', money('advance_amount')),
          ('Выплачено', money('paid_amount')),
          ('Закрыто отчётами', money('claimed_amount')),
          ('Возвращено', money('return_amount')),
          ('Способ оплаты', text('mode_of_payment')),
          ('Удержать остаток из зарплаты', yes('repay_unclaimed_amount_from_salary')),
        ],
      RequestKind.shift => [
          ('Сотрудник', text('employee_name')),
          ('Смена', text('shift_type')),
          ('С', date('from_date')),
          ('По', d['to_date'] == null ? 'Без срока' : date('to_date')),
          ('Согласующий', text('approver')),
        ],
      RequestKind.attendance => [
          ('Сотрудник', text('employee_name')),
          ('Причина', statusLabel(text('reason'))),
          ('С', date('from_date')),
          ('По', date('to_date')),
          ('Полдня', yes('half_day').isEmpty ? '' : Fmt.long(d['half_day_date'])),
          ('Смена', text('shift')),
          ('Включая выходные', yes('include_holidays')),
          ('Пояснение', text('explanation')),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: ScreenHeader(title: kind.singular, actions: [
        CircleButton(icon: CupertinoIcons.ellipsis, label: 'Действия', onTap: _doc == null ? null : _more),
      ]),
      body: _body(),
      bottom: _doc == null ? null : _actions(),
    );
  }

  Widget? _actions() {
    final doc = _doc!;
    final ds = Fmt.number(doc['docstatus']).toInt();
    if (ds != 0) return null;
    final hasWorkflow = _workflow.isNotEmpty;
    if (hasWorkflow) {
      if (_transitions.isEmpty) return null;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final t in _transitions) ...[
          PrimaryButton(
            label: t,
            loading: _busy == t,
            kind: t.toLowerCase().contains('reject') || t.toLowerCase().contains('cancel')
                ? ButtonKind.danger
                : t.toLowerCase().contains('approve')
                    ? ButtonKind.green
                    : ButtonKind.dark,
            onTap: () => _run(t, () => Hr.applyWorkflow(doc, t), 'Действие «$t» выполнено'),
          ),
          const SizedBox(height: 8),
        ],
      ]);
    }

    final field = kind.approvalField;
    final pending = field != null && doc[field] == kind.pendingStatus;
    final isApprover = kind.approverField != null && doc[kind.approverField] == _session.userId;
    final selfBlocked = kind == RequestKind.leave && _isOwn && _session.preventSelfLeaveApproval;
    final canApprove = pending && _writable.contains(field) && (isApprover || !_isOwn) && !selfBlocked;
    final canSubmit = (_perms['submit'] ?? false) && (field == null || !pending) && (!_isOwn || isApprover || field == null);

    if (canApprove) {
      return Row(children: [
        Expanded(
          child: PrimaryButton(
            label: 'Отклонить',
            kind: ButtonKind.danger,
            loading: _busy == 'Rejected',
            onTap: _busy == null ? () => _setApproval('Rejected') : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryButton(
            label: 'Одобрить',
            kind: ButtonKind.green,
            loading: _busy == 'Approved',
            onTap: _busy == null ? () => _setApproval('Approved') : null,
          ),
        ),
      ]);
    }
    if (canSubmit) {
      return PrimaryButton(label: 'Провести', loading: _busy == 'submit', onTap: _busy == null ? _submit : null);
    }
    return null;
  }

  Widget _body() {
    if (_loading) {
      return PageScroll(children: const [
        Skeleton(height: 64, width: 280),
        SizedBox(height: 20),
        Skeleton(height: 320, radius: AppRadius.card),
      ]);
    }
    if (_error != null) return PageScroll(children: [ErrorState(error: _error!, onRetry: _load)]);
    final doc = _doc!;
    final ds = Fmt.number(doc['docstatus']).toInt();
    final cur = doc['currency']?.toString() ?? _session.currency;
    final expenses = (doc['expenses'] as List? ?? const []).cast<Map>();
    final advances = (doc['advances'] as List? ?? const []).cast<Map>().where((a) => Fmt.number(a['allocated_amount']) > 0);
    final canAttach = ds == 0 && (_perms['write'] ?? false);

    return PageScroll(onRefresh: _load, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: kind.icon, tone: kind.tone, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Text(kind.heading(doc), style: AppText.display.copyWith(fontSize: 22)),
        ),
      ]),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(left: 66),
        child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusPill(_status),
          if (ds == 1) const StatusPill('Submitted'),
          const SizedBox.shrink(),
        ]),
      ),
      const SizedBox(height: 22),
      FieldRows(rows: _rows(doc)),
      if (expenses.isNotEmpty) ...[
        const SectionHeader('Расходы'),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Divided(children: [
            for (final e in expenses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e['expense_type']?.toString() ?? '', style: AppText.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        [Fmt.dayMonth(e['expense_date']), stripHtml(e['description']?.toString())]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: AppText.caption,
                      ),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Fmt.money(e['amount'], cur), style: AppText.number),
                    if (Fmt.number(e['sanctioned_amount']) != Fmt.number(e['amount']))
                      Text('утв. ${Fmt.money(e['sanctioned_amount'], cur)}', style: AppText.caption),
                  ]),
                ]),
              ),
          ]),
        ),
      ],
      if (advances.isNotEmpty) ...[
        const SectionHeader('Зачтённые авансы'),
        FieldRows(rows: [
          for (final a in advances) (a['employee_advance'].toString(), Fmt.money(a['allocated_amount'], cur)),
        ]),
      ],
      if (_files.isNotEmpty || canAttach) ...[
        const SectionHeader('Вложения'),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final f in _files)
              AttachmentTile(
                name: f.fileName,
                meta: f.meta,
                onTap: () async {
                  try {
                    await Files.open(f);
                  } catch (e) {
                    if (mounted) showToast(context, errorText(e), error: true);
                  }
                },
                onDelete: canAttach
                    ? () async {
                        final ok = await confirmAction(context,
                            title: 'Удалить вложение?', message: f.fileName, confirmLabel: 'Удалить', destructive: true);
                        if (!ok) return;
                        try {
                          await Files.delete(f);
                          if (mounted) setState(() => _files.remove(f));
                        } catch (e) {
                          if (mounted) showToast(context, errorText(e), error: true);
                        }
                      }
                    : null,
              ),
            if (canAttach)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Pressable(
                  onTap: _uploading ? null : _attach,
                  child: Row(children: [
                    if (_uploading)
                      const CupertinoActivityIndicator()
                    else
                      const Icon(CupertinoIcons.paperclip, size: 18, color: AppColors.violet),
                    const SizedBox(width: 10),
                    Text(_uploading ? 'Загрузка…' : 'Прикрепить файл',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.violet)),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    ]);
  }
}
