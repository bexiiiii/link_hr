import 'package:flutter/cupertino.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';

class LeaveForm extends StatefulWidget {
  const LeaveForm({super.key, this.doc});

  final Json? doc;

  @override
  State<LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<LeaveForm> {
  late final _reason = TextEditingController(text: stripHtml(widget.doc?['description']?.toString()));
  List<String> _types = [];
  List<SelectOption> _approvers = [];
  bool _approverRequired = false;

  late String? _type = widget.doc?['leave_type']?.toString();
  late DateTime? _from = Fmt.parse(widget.doc?['from_date']);
  late DateTime? _to = Fmt.parse(widget.doc?['to_date']);
  late bool _halfDay = widget.doc?['half_day'] == 1;
  late DateTime? _halfDayDate = Fmt.parse(widget.doc?['half_day_date']);
  late String? _approver = widget.doc?['leave_approver']?.toString();

  num? _days;
  num? _balance;
  bool _calculating = false;
  bool _loading = true;
  Object? _loadError;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object>([
        Hr.leaveTypes(DateTime.now()),
        Hr.leaveApprovalDetails().catchError((_) => <String, dynamic>{}),
      ]);
      final details = results[1] as Json;
      if (!mounted) return;
      setState(() {
        _types = results[0] as List<String>;
        _approvers = [
          for (final a in (details['department_approvers'] as List? ?? const []))
            SelectOption(a['name'].toString(), (a['full_name'] ?? a['name']).toString(), subtitle: a['name'].toString()),
        ];
        final def = details['leave_approver']?.toString();
        if (def != null && def.isNotEmpty && !_approvers.any((o) => o.value == def)) {
          _approvers.add(SelectOption(def, details['leave_approver_name']?.toString() ?? def, subtitle: def));
        }
        _approver ??= def;
        _approverRequired = details['is_mandatory'] == 1 || details['is_mandatory'] == true;
        _loading = false;
      });
      _recalculate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _recalculate() async {
    final type = _type, from = _from, to = _to;
    if (type == null || from == null || to == null || to.isBefore(from)) {
      setState(() {
        _days = null;
        _balance = null;
      });
      return;
    }
    setState(() => _calculating = true);
    try {
      final results = await Future.wait([
        Hr.leaveDays(
          leaveType: type,
          from: from,
          to: to,
          halfDay: _halfDay,
          halfDayDate: _halfDay ? (from == to ? from : _halfDayDate) : null,
        ),
        Hr.leaveBalanceOn(leaveType: type, from: from, to: to),
      ]);
      if (!mounted || type != _type || from != _from || to != _to) return;
      setState(() {
        _days = results[0];
        _balance = results[1];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _days = null;
          _balance = null;
        });
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _submit() async {
    String? problem;
    if (_type == null) {
      problem = 'Выберите тип отпуска';
    } else if (_from == null || _to == null) {
      problem = 'Укажите даты отпуска';
    } else if (_to!.isBefore(_from!)) {
      problem = 'Дата окончания раньше даты начала';
    } else if (_halfDay && _from != _to && _halfDayDate == null) {
      problem = 'Укажите дату полудня';
    } else if (_approverRequired && (_approver == null || _approver!.isEmpty)) {
      problem = 'Выберите согласующего';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await persistRequest(context, RequestKind.leave, widget.doc, {
        'leave_type': _type,
        'from_date': Fmt.iso(_from!),
        'to_date': Fmt.iso(_to!),
        'half_day': _halfDay ? 1 : 0,
        'half_day_date': _halfDay ? Fmt.iso(_from == _to ? _from! : _halfDayDate!) : null,
        'description': _reason.text.trim(),
        'leave_approver': _approver,
        if (widget.doc == null) ...{
          'status': 'Open',
          'posting_date': Fmt.iso(DateTime.now()),
          'follow_via_email': 1,
        },
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final short = _days != null && _balance != null && _days! > _balance!;
    return FormScaffold(
      title: widget.doc == null ? 'Заявление на отпуск' : 'Редактирование',
      submitLabel: widget.doc == null ? 'Отправить заявление' : 'Сохранить',
      loading: _loading,
      loadError: _loadError,
      onRetry: _loadMeta,
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        SelectInput(
          label: 'Тип отпуска',
          required: true,
          value: _type,
          options: [for (final t in _types) SelectOption(t, t)],
          onChanged: (v) {
            setState(() => _type = v);
            _recalculate();
          },
        ),
        const FormGap(),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: DateInput(
              label: 'С',
              required: true,
              value: _from,
              placeholder: 'Дата',
              onChanged: (d) {
                setState(() {
                  _from = d;
                  if (_to == null || (d != null && _to!.isBefore(d))) _to = d;
                });
                _recalculate();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DateInput(
              label: 'По',
              required: true,
              value: _to,
              minimum: _from,
              placeholder: 'Дата',
              onChanged: (d) {
                setState(() => _to = d);
                _recalculate();
              },
            ),
          ),
        ]),
        const FormGap(),
        SwitchInput(
          label: 'Половина дня',
          subtitle: 'Отпуск на полдня в один из дней',
          value: _halfDay,
          onChanged: (v) {
            setState(() => _halfDay = v);
            _recalculate();
          },
        ),
        if (_halfDay && _from != null && _to != null && _from != _to) ...[
          const FormGap(),
          DateInput(
            label: 'Дата полудня',
            required: true,
            value: _halfDayDate,
            minimum: _from,
            maximum: _to,
            onChanged: (d) {
              setState(() => _halfDayDate = d);
              _recalculate();
            },
          ),
        ],
        const FormGap(),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(child: _Stat(label: 'Дней отпуска', value: _days == null ? '—' : Fmt.decimal(_days))),
            Container(width: 1, height: 36, color: AppColors.line),
            const SizedBox(width: 18),
            Expanded(
              child: _Stat(label: 'Доступно', value: _balance == null ? '—' : Fmt.decimal(_balance), warn: short),
            ),
            if (_calculating) const CupertinoActivityIndicator(),
          ]),
        ),
        if (short)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text('Запрошено больше дней, чем доступно по этому типу отпуска',
                style: AppText.caption.copyWith(color: AppColors.red)),
          ),
        const FormGap(),
        AppTextField(label: 'Причина', controller: _reason, maxLines: 4, hint: 'Например, ежегодный трудовой отпуск'),
        const FormGap(),
        SelectInput(
          label: 'Согласующий',
          required: _approverRequired,
          value: _approver,
          options: _approvers,
          placeholder: 'Выберите согласующего',
          onChanged: (v) => setState(() => _approver = v),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppText.caption),
      const SizedBox(height: 4),
      Text(value,
          style: AppText.heading.copyWith(
            color: warn ? AppColors.red : AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
    ]);
  }
}
