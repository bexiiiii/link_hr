import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';

class AdvanceForm extends StatefulWidget {
  const AdvanceForm({super.key, this.doc});

  final Json? doc;

  @override
  State<AdvanceForm> createState() => _AdvanceFormState();
}

class _AdvanceFormState extends State<AdvanceForm> {
  late final _purpose = TextEditingController(text: stripHtml(widget.doc?['purpose']?.toString()));
  late final _amount = TextEditingController(
      text: widget.doc == null ? '' : Fmt.decimal(widget.doc!['advance_amount']).replaceAll(',', '.'));
  late DateTime _posting = Fmt.parse(widget.doc?['posting_date']) ?? Fmt.dateOnly(DateTime.now());
  late String? _mode = widget.doc?['mode_of_payment']?.toString();
  late bool _repay = widget.doc?['repay_unclaimed_amount_from_salary'] == 1;
  String? _account;
  List<SelectOption> _modes = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Hr.advanceAccount().then((a) => _account = a).catchError((_) => null);
    Hr.modesOfPayment().then((rows) {
      if (mounted) setState(() => _modes = [for (final r in rows) SelectOption(r['name'].toString(), r['name'].toString())]);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _purpose.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amount.text.replaceAll(',', '.').replaceAll(' ', ''));
    String? problem;
    if (_purpose.text.trim().isEmpty) {
      problem = 'Укажите цель аванса';
    } else if (amount == null || amount <= 0) {
      problem = 'Укажите сумму больше нуля';
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
      await persistRequest(context, RequestKind.advance, widget.doc, {
        'purpose': _purpose.text.trim(),
        'advance_amount': amount,
        'posting_date': Fmt.iso(_posting),
        'currency': widget.doc?['currency'] ?? Session.instance.currency,
        'exchange_rate': widget.doc?['exchange_rate'] ?? 1,
        'advance_account': ?(widget.doc?['advance_account'] ?? _account),
        'mode_of_payment': _mode,
        'repay_unclaimed_amount_from_salary': _repay ? 1 : 0,
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
      title: widget.doc == null ? 'Запрос аванса' : 'Редактирование',
      submitLabel: widget.doc == null ? 'Запросить аванс' : 'Сохранить',
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        AppTextField(
          label: 'Цель',
          controller: _purpose,
          required: true,
          maxLines: 3,
          hint: 'Например, командировка в Астану',
        ),
        const FormGap(),
        AppTextField(
          label: 'Сумма, ${Fmt.symbol(Session.instance.currency)}',
          controller: _amount,
          required: true,
          hint: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const FormGap(),
        DateInput(
          label: 'Дата',
          required: true,
          value: _posting,
          onChanged: (d) => setState(() => _posting = d ?? _posting),
        ),
        const FormGap(),
        SelectInput(
          label: 'Способ оплаты',
          value: _mode,
          options: _modes,
          placeholder: 'Не указан',
          onChanged: (v) => setState(() => _mode = v),
        ),
        const FormGap(),
        SwitchInput(
          label: 'Удержать остаток из зарплаты',
          subtitle: 'Если аванс не будет закрыт отчётом',
          value: _repay,
          onChanged: (v) => setState(() => _repay = v),
        ),
      ],
    );
  }
}
