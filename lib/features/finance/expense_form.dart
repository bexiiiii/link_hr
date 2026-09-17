import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';

class _Item {
  _Item({
    required this.type,
    required this.date,
    required this.amount,
    this.description = '',
  });

  String type;
  DateTime date;
  num amount;
  String description;
}

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, this.doc});

  final Json? doc;

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  List<SelectOption> _types = [];
  List<SelectOption> _approvers = [];
  bool _approverRequired = false;
  Json _costCenter = {};
  List<Json> _advances = [];
  final Set<String> _allocate = {};

  late DateTime _posting =
      Fmt.parse(widget.doc?['posting_date']) ?? Fmt.dateOnly(DateTime.now());
  late String? _approver = widget.doc?['expense_approver']?.toString();
  late final List<_Item> _items = [
    for (final e in (widget.doc?['expenses'] as List? ?? const []))
      _Item(
        type: e['expense_type'].toString(),
        date: Fmt.parse(e['expense_date']) ?? DateTime.now(),
        amount: Fmt.number(e['amount']),
        description: stripHtml(e['description']?.toString()),
      ),
  ];

  bool _loading = true;
  Object? _loadError;
  bool _busy = false;
  String? _error;

  String get _currency => Session.instance.currency;
  num get _total => _items.fold<num>(0, (s, i) => s + i.amount);

  @override
  void initState() {
    super.initState();
    for (final a in (widget.doc?['advances'] as List? ?? const [])) {
      if (Fmt.number(a['allocated_amount']) > 0)
        _allocate.add(a['employee_advance'].toString());
    }
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object>([
        Hr.expenseTypes(),
        Hr.expenseApprovalDetails().catchError((_) => <String, dynamic>{}),
        Hr.companyCostCenter().catchError((_) => <String, dynamic>{}),
        Hr.unclaimedAdvances().catchError((_) => <Json>[]),
      ]);
      final details = results[1] as Json;
      if (!mounted) return;
      setState(() {
        _types = [
          for (final t in results[0] as List<Json>)
            SelectOption(
              t['name'].toString(),
              t['name'].toString(),
              subtitle: stripHtml(t['description']?.toString()),
            ),
        ];
        _approvers = [
          for (final a
              in (details['department_approvers'] as List? ?? const []))
            SelectOption(
              a['name'].toString(),
              (a['full_name'] ?? a['name']).toString(),
              subtitle: a['name'].toString(),
            ),
        ];
        final def = details['expense_approver']?.toString();
        if (def != null &&
            def.isNotEmpty &&
            !_approvers.any((o) => o.value == def)) {
          _approvers.add(
            SelectOption(
              def,
              details['expense_approver_name']?.toString() ?? def,
              subtitle: def,
            ),
          );
        }
        _approver ??= def;
        _approverRequired =
            details['is_mandatory'] == 1 || details['is_mandatory'] == true;
        _costCenter = results[2] as Json;
        _advances = (results[3] as List<Json>)
            .where((a) => _unclaimed(a) > 0)
            .toList();
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

  num _unclaimed(Json a) =>
      Fmt.number(a['paid_amount']) -
      Fmt.number(a['claimed_amount']) -
      Fmt.number(a['return_amount']);

  Future<void> _editItem([_Item? existing]) async {
    final result = await showModalBottomSheet<_Item?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) =>
          _ItemSheet(types: _types, item: existing, currency: _currency),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) _items.add(result);
    });
  }

  Future<void> _submit() async {
    String? problem;
    if (_items.isEmpty) {
      problem = 'Добавьте хотя бы один расход';
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
    var remaining = _total;
    final advances = <Json>[];
    for (final a in _advances.where((a) => _allocate.contains(a['name']))) {
      final allocated = math.min(_unclaimed(a), remaining);
      remaining -= allocated;
      advances.add({
        'employee_advance': a['name'],
        'posting_date': a['posting_date'],
        'advance_paid': a['paid_amount'],
        'unclaimed_amount': _unclaimed(a),
        'allocated_amount': allocated,
        'advance_account': a['advance_account'],
      });
    }
    try {
      await persistRequest(context, RequestKind.expense, widget.doc, {
        'posting_date': Fmt.iso(_posting),
        'expense_approver': _approver,
        if (_costCenter['cost_center'] != null)
          'cost_center': _costCenter['cost_center'],
        if (_costCenter['default_expense_claim_payable_account'] != null)
          'payable_account':
              _costCenter['default_expense_claim_payable_account'],
        'expenses': [
          for (final i in _items)
            {
              'expense_type': i.type,
              'expense_date': Fmt.iso(i.date),
              'amount': i.amount,
              'sanctioned_amount': i.amount,
              'description': i.description,
            },
        ],
        'advances': advances,
        if (widget.doc == null) 'approval_status': 'Draft',
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
      title: widget.doc == null ? 'Авансовый отчёт' : 'Редактирование',
      submitLabel: _items.isEmpty
          ? 'Отправить отчёт'
          : 'Отправить · ${Fmt.money(_total, _currency)}',
      loading: _loading,
      loadError: _loadError,
      onRetry: _loadMeta,
      busy: _busy,
      error: _error,
      onSubmit: _submit,
      children: [
        const FieldLabel('Расходы', required: true),
        if (_items.isNotEmpty)
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Divided(
              children: [
                for (final i in _items)
                  Dismissible(
                    key: ObjectKey(i),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => setState(() => _items.remove(i)),
                    background: Container(
                      alignment: Alignment.centerRight,
                      child: const Icon(
                        AppIcons.trash,
                        color: AppColors.red,
                        size: 20,
                      ),
                    ),
                    child: Pressable(
                      onTap: () async {
                        await _editItem(i);
                        setState(() {});
                      },
                      scale: 0.99,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.type, style: AppText.bodyStrong),
                                  Text(
                                    [
                                      Fmt.dayMonth(i.date),
                                      i.description,
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Fmt.money(i.amount, _currency),
                              style: AppText.number,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Добавить расход',
          icon: AppIcons.plus,
          kind: ButtonKind.soft,
          height: 50,
          onTap: _types.isEmpty ? null : () => _editItem(),
        ),
        if (_items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(
              'Смахните расход влево, чтобы удалить',
              style: AppText.caption,
            ),
          ),
        const FormGap(),
        DateInput(
          label: 'Дата отчёта',
          required: true,
          value: _posting,
          onChanged: (d) => setState(() => _posting = d ?? _posting),
        ),
        const FormGap(),
        SelectInput(
          label: 'Согласующий',
          required: _approverRequired,
          value: _approver,
          options: _approvers,
          placeholder: 'Выберите согласующего',
          onChanged: (v) => setState(() => _approver = v),
        ),
        if (_advances.isNotEmpty) ...[
          const FormGap(),
          const FieldLabel('Зачесть авансы'),
          for (final a in _advances) ...[
            SwitchInput(
              label: '${a['name']} · ${Fmt.money(_unclaimed(a), _currency)}',
              subtitle: 'Выдан ${Fmt.long(a['posting_date'])}',
              value: _allocate.contains(a['name']),
              onChanged: (v) => setState(
                () => v
                    ? _allocate.add(a['name'].toString())
                    : _allocate.remove(a['name']),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.types, required this.currency, this.item});

  final List<SelectOption> types;
  final String currency;
  final _Item? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late String? _type = widget.item?.type;
  late DateTime _date = widget.item?.date ?? Fmt.dateOnly(DateTime.now());
  late final _amount = TextEditingController(
    text: widget.item == null
        ? ''
        : Fmt.decimal(widget.item!.amount).replaceAll(',', '.'),
  );
  late final _description = TextEditingController(
    text: widget.item?.description,
  );
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final amount = num.tryParse(
      _amount.text.replaceAll(',', '.').replaceAll(' ', ''),
    );
    if (_type == null) {
      setState(() => _error = 'Выберите вид расхода');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Укажите сумму больше нуля');
      return;
    }
    final existing = widget.item;
    if (existing != null) {
      existing
        ..type = _type!
        ..date = _date
        ..amount = amount
        ..description = _description.text.trim();
      Navigator.pop(context);
    } else {
      Navigator.pop(
        context,
        _Item(
          type: _type!,
          date: _date,
          amount: amount,
          description: _description.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item == null ? 'Новый расход' : 'Расход',
                style: AppText.title,
              ),
              const SizedBox(height: 18),
              SelectInput(
                label: 'Вид расхода',
                required: true,
                value: _type,
                options: widget.types,
                onChanged: (v) => setState(() => _type = v),
              ),
              const FormGap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Сумма, ${Fmt.symbol(widget.currency)}',
                      controller: _amount,
                      required: true,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateInput(
                      label: 'Дата',
                      value: _date,
                      maximum: DateTime.now(),
                      onChanged: (d) => setState(() => _date = d ?? _date),
                    ),
                  ),
                ],
              ),
              const FormGap(),
              AppTextField(
                label: 'Описание',
                controller: _description,
                maxLines: 3,
                hint: 'Такси до аэропорта',
              ),
              if (_error != null) InlineError(_error!),
              const SizedBox(height: 20),
              PrimaryButton(
                label: widget.item == null ? 'Добавить' : 'Сохранить',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _save();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
