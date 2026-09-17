import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';

class AttendanceRequestForm extends StatefulWidget {
  const AttendanceRequestForm({super.key, this.doc});

  final Json? doc;

  @override
  State<AttendanceRequestForm> createState() => _AttendanceRequestFormState();
}

class _AttendanceRequestFormState extends State<AttendanceRequestForm> {
  static const _reasons = ['Work From Home', 'On Duty'];

  late final _explanation = TextEditingController(
    text: widget.doc?['explanation']?.toString(),
  );
  late String _reason = widget.doc?['reason']?.toString() ?? 'Work From Home';
  late DateTime? _from =
      Fmt.parse(widget.doc?['from_date']) ?? Fmt.dateOnly(DateTime.now());
  late DateTime? _to =
      Fmt.parse(widget.doc?['to_date']) ?? Fmt.dateOnly(DateTime.now());
  late bool _halfDay = widget.doc?['half_day'] == 1;
  late DateTime? _halfDayDate = Fmt.parse(widget.doc?['half_day_date']);
  late bool _includeHolidays = widget.doc?['include_holidays'] == 1;
  late String? _shift = widget.doc?['shift']?.toString();
  List<SelectOption> _shifts = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Hr.shiftTypes()
        .then((rows) {
          if (mounted) {
            setState(
              () => _shifts = [
                for (final r in rows)
                  SelectOption(r['name'].toString(), r['name'].toString()),
              ],
            );
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String? problem;
    if (_from == null || _to == null) {
      problem = 'Укажите даты';
    } else if (_to!.isBefore(_from!)) {
      problem = 'Дата окончания раньше даты начала';
    } else if (_halfDay && _halfDayDate == null && _from != _to) {
      problem = 'Укажите дату полудня';
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
      await persistRequest(context, RequestKind.attendance, widget.doc, {
        'reason': _reason,
        'from_date': Fmt.iso(_from!),
        'to_date': Fmt.iso(_to!),
        'half_day': _halfDay ? 1 : 0,
        'half_day_date': _halfDay ? Fmt.iso(_halfDayDate ?? _from!) : null,
        'include_holidays': _includeHolidays ? 1 : 0,
        'shift': _shift,
        'explanation': _explanation.text.trim(),
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
      title: widget.doc == null ? 'Заявка на отметку' : 'Редактирование',
      submitLabel: widget.doc == null ? 'Отправить заявку' : 'Сохранить',
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        const FieldLabel('Причина', required: true),
        SegmentTabs(
          labels: [for (final r in _reasons) statusLabel(r)],
          index: _reasons.indexOf(_reason).clamp(0, 1),
          onChanged: (i) => setState(() => _reason = _reasons[i]),
        ),
        const FormGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DateInput(
                label: 'С',
                required: true,
                value: _from,
                placeholder: 'Дата',
                onChanged: (d) => setState(() {
                  _from = d;
                  if (_to == null || (d != null && _to!.isBefore(d))) _to = d;
                }),
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
                onChanged: (d) => setState(() => _to = d),
              ),
            ),
          ],
        ),
        const FormGap(),
        SwitchInput(
          label: 'Половина дня',
          value: _halfDay,
          onChanged: (v) => setState(() => _halfDay = v),
        ),
        if (_halfDay && _from != null && _to != null && _from != _to) ...[
          const FormGap(),
          DateInput(
            label: 'Дата полудня',
            required: true,
            value: _halfDayDate,
            minimum: _from,
            maximum: _to,
            onChanged: (d) => setState(() => _halfDayDate = d),
          ),
        ],
        const FormGap(),
        SwitchInput(
          label: 'Включая выходные',
          subtitle: 'Отметить также праздничные и выходные дни',
          value: _includeHolidays,
          onChanged: (v) => setState(() => _includeHolidays = v),
        ),
        const FormGap(),
        SelectInput(
          label: 'Смена',
          value: _shift,
          options: _shifts,
          placeholder: 'Не указана',
          onChanged: (v) => setState(() => _shift = v),
        ),
        const FormGap(),
        AppTextField(
          label: 'Пояснение',
          controller: _explanation,
          maxLines: 4,
          hint: 'Например, работа с клиентом на выезде',
        ),
      ],
    );
  }
}
