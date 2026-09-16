import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';
import 'attendance_screen.dart';

class ShiftRequestForm extends StatefulWidget {
  const ShiftRequestForm({super.key, this.doc});

  final Json? doc;

  @override
  State<ShiftRequestForm> createState() => _ShiftRequestFormState();
}

class _ShiftRequestFormState extends State<ShiftRequestForm> {
  List<SelectOption> _shiftTypes = [];
  List<SelectOption> _approvers = [];
  late String? _shift = widget.doc?['shift_type']?.toString();
  late DateTime? _from = Fmt.parse(widget.doc?['from_date']) ?? Fmt.dateOnly(DateTime.now());
  late DateTime? _to = Fmt.parse(widget.doc?['to_date']);
  late String? _approver = widget.doc?['approver']?.toString();
  bool _loading = true;
  Object? _loadError;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<List<Json>>([
        Hr.shiftTypes(),
        Hr.shiftApprovers().catchError((_) => <Json>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _shiftTypes = [
          for (final s in results[0])
            SelectOption(s['name'].toString(), s['name'].toString(),
                subtitle: s['start_time'] == null ? null : '${hm(s['start_time'])}–${hm(s['end_time'])}'),
        ];
        _approvers = [
          for (final a in results[1])
            SelectOption(a['name'].toString(), (a['full_name'] ?? a['name']).toString(), subtitle: a['name'].toString()),
        ];
        _approver ??= _approvers.isEmpty ? null : _approvers.first.value;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _submit() async {
    String? problem;
    if (_shift == null) {
      problem = 'Выберите смену';
    } else if (_from == null) {
      problem = 'Укажите дату начала';
    } else if (_to != null && _to!.isBefore(_from!)) {
      problem = 'Дата окончания раньше даты начала';
    } else if (_approver == null || _approver!.isEmpty) {
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
      await persistRequest(context, RequestKind.shift, widget.doc, {
        'shift_type': _shift,
        'from_date': Fmt.iso(_from!),
        'to_date': _to == null ? null : Fmt.iso(_to!),
        'approver': _approver,
        if (widget.doc == null) 'status': 'Draft',
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.doc == null ? 'Заявка на смену' : 'Редактирование',
      submitLabel: widget.doc == null ? 'Отправить заявку' : 'Сохранить',
      loading: _loading,
      loadError: _loadError,
      onRetry: _loadMeta,
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        SelectInput(
          label: 'Смена',
          required: true,
          value: _shift,
          options: _shiftTypes,
          onChanged: (v) => setState(() => _shift = v),
        ),
        const FormGap(),
        DateInput(
          label: 'С',
          required: true,
          value: _from,
          onChanged: (d) => setState(() {
            _from = d;
            if (_to != null && d != null && _to!.isBefore(d)) _to = d;
          }),
        ),
        const FormGap(),
        DateInput(
          label: 'По',
          value: _to,
          minimum: _from,
          clearable: true,
          placeholder: 'Без даты окончания',
          onChanged: (d) => setState(() => _to = d),
        ),
        const FormGap(),
        SelectInput(
          label: 'Согласующий',
          required: true,
          value: _approver,
          options: _approvers,
          placeholder: 'Выберите согласующего',
          onChanged: (v) => setState(() => _approver = v),
        ),
      ],
    );
  }
}
