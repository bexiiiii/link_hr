import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/kit.dart';
import '../../core/motion.dart';
import '../../core/people.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/payroll.dart';

String _num(double v) => Fmt.money(v, '').trim();

String _hours(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toStringAsFixed(2);

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<PayRow>? _rows;
  Object? _error;
  String _query = '';
  String? _department;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await Payroll.load(_month);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final months = [
      for (var i = 0; i < 18; i++) DateTime(now.year, now.month - i),
    ];
    final picked = await showSelectSheet(
      context,
      title: 'Месяц',
      options: [
        for (final m in months)
          SelectOption(Fmt.iso(m), '${Fmt.month(m)}, ${m.year}'),
      ],
      selected: Fmt.iso(_month),
    );
    if (picked == null) return;
    final d = DateTime.parse(picked);
    setState(() {
      _month = DateTime(d.year, d.month);
      _rows = null;
    });
    _load();
  }

  Future<void> _pickDepartment() async {
    final departments = {
      for (final r in _rows ?? const <PayRow>[])
        if (r.person.department.isNotEmpty) r.person.department,
    }.toList()..sort();
    final picked = await showSelectSheet(
      context,
      title: 'Отдел',
      options: [
        const SelectOption('', 'Все отделы'),
        for (final d in departments) SelectOption(d, d),
      ],
      selected: _department ?? '',
    );
    if (picked != null)
      setState(() => _department = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = (_rows ?? const <PayRow>[])
        .where(
          (r) =>
              (_department == null || r.person.department == _department) &&
              (q.isEmpty ||
                  r.person.name.toLowerCase().contains(q) ||
                  r.person.role.toLowerCase().contains(q)),
        )
        .toList();
    final total = rows.fold<double>(0, (s, r) => s + r.payout);

    return AppPage(
      header: const ScreenHeader(title: 'Подсчёт ЗП'),
      body: PageScroll(
        onRefresh: _load,
        children: [
          Pressable(
            onTap: _pickMonth,
            semanticLabel: 'Выбрать месяц',
            child: Row(
              children: [
                const Icon(AppIcons.calendar, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${Fmt.month(_month)}, ${_month.year}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CupertinoSearchTextField(
            placeholder: 'Поиск сотрудника',
            backgroundColor: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownPill(
              label: _department ?? 'Выберите отдел',
              onTap: _pickDepartment,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Итог:', style: AppText.bodyStrong),
              const Spacer(),
              Text(
                '${_num(total)} ₸',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.violet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'СОТРУДНИК',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Фикс оклад (₸)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Часы факт',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ErrorState(error: _error!, onRetry: _load),
            )
          else if (_rows == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SkeletonCards(count: 4, height: 70),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: EmptyState(
                icon: AppIcons.person3,
                title: 'Сотрудники не найдены',
                message: 'Измените поиск или выберите другой отдел.',
              ),
            )
          else
            for (final (i, r) in rows.indexed)
              Reveal(
                index: i.clamp(0, 12),
                child: Pressable(
                  onTap: () async {
                    final changed = await pushPage<bool>(
                      context,
                      PayrollEmployeeScreen(row: r, month: _month),
                    );
                    if (changed == true && mounted) setState(() {});
                  },
                  scale: 0.99,
                  semanticLabel: r.person.name,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.person.name,
                                style: AppText.bodyStrong.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              if (r.person.role.isNotEmpty)
                                Text(
                                  r.person.role,
                                  style: AppText.label.copyWith(
                                    color: AppColors.ink3,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              _PaidChip(paid: r.paid),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _num(r.fixed),
                            textAlign: TextAlign.right,
                            style: AppText.body.copyWith(
                              color: r.paid ? AppColors.ink : AppColors.ink3,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _hours(r.factHours),
                            textAlign: TextAlign.right,
                            style: AppText.body.copyWith(
                              color: r.paid ? AppColors.ink : AppColors.ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _PaidChip extends StatelessWidget {
  const _PaidChip({required this.paid, this.onTap});

  final bool paid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: paid ? AppColors.greenSoft : AppColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        paid ? 'Выплачено' : 'Не выплачено',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: paid ? AppColors.greenDeep : AppColors.ink2,
        ),
      ),
    );
    return onTap == null
        ? chip
        : Pressable(onTap: onTap, semanticLabel: 'Статус выплаты', child: chip);
  }
}

class PayrollEmployeeScreen extends StatefulWidget {
  const PayrollEmployeeScreen({
    super.key,
    required this.row,
    required this.month,
  });

  final PayRow row;
  final DateTime month;

  @override
  State<PayrollEmployeeScreen> createState() => _PayrollEmployeeScreenState();
}

class _PayrollEmployeeScreenState extends State<PayrollEmployeeScreen> {
  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

  late final _fixed = TextEditingController(text: _plain(widget.row.fixed));
  late final _bonus = TextEditingController(text: _plain(widget.row.bonus));
  late final _deduction = TextEditingController(
    text: _plain(widget.row.deduction),
  );
  late bool _hourly = widget.row.hourly;
  late bool _paid = widget.row.paid;
  bool _busy = false;
  String? _error;

  double _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(' ', '').replaceAll(',', '.')) ??
      0;

  @override
  void dispose() {
    _fixed.dispose();
    _bonus.dispose();
    _deduction.dispose();
    super.dispose();
  }

  PayRow get _preview => PayRow(
    person: widget.row.person,
    fixed: _v(_fixed),
    bonus: _v(_bonus),
    deduction: _v(_deduction),
    hourly: _hourly,
    paid: _paid,
    planHours: widget.row.planHours,
    factHours: widget.row.factHours,
  );

  Future<void> _save() async {
    final r = widget.row;
    final previous = (r.fixed, r.bonus, r.deduction, r.hourly, r.paid);
    r
      ..fixed = _v(_fixed)
      ..bonus = _v(_bonus)
      ..deduction = _v(_deduction)
      ..hourly = _hourly
      ..paid = _paid;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Payroll.save(r, widget.month);
      if (mounted) {
        showToast(context, 'Сохранено');
        Navigator.pop(context, true);
      }
    } catch (e) {
      r
        ..fixed = previous.$1
        ..bonus = previous.$2
        ..deduction = previous.$3
        ..hourly = previous.$4
        ..paid = previous.$5;
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return AppPage(
      header: ScreenHeader(title: Fmt.month(widget.month)),
      bottom: PrimaryButton(label: 'Сохранить', loading: _busy, onTap: _save),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageScroll(
          children: [
            PersonRow(person: widget.row.person),
            const SizedBox(height: 16),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('К выплате', style: AppText.bodyStrong),
                  ),
                  Text(
                    '${_num(p.payout)} ₸',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.violet,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Заработная плата', style: AppText.heading),
                const SizedBox(width: 10),
                _PaidChip(
                  paid: _paid,
                  onTap: () => setState(() => _paid = !_paid),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectInput(
              label: 'Тип оплаты',
              value: _hourly ? 'hourly' : 'fixed',
              options: const [
                SelectOption('fixed', 'Оклад'),
                SelectOption('hourly', 'Почасовая'),
              ],
              onChanged: (v) => setState(() => _hourly = v == 'hourly'),
            ),
            const FormGap(),
            AppTextField(
              label: _hourly ? 'Ставка за час (₸)' : 'Фикс оклад (₸)',
              controller: _fixed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const FormGap(),
            AppTextField(
              label: 'Бонус (₸)',
              controller: _bonus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const FormGap(),
            AppTextField(
              label: 'Удержание (₸)',
              controller: _deduction,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            for (final (label, value) in [
              ('Ставка за час (₸)', _num(p.rate.roundToDouble())),
              ('Часы план (ч)', _hours(p.planHours)),
              ('Часы факт (ч)', _hours(p.factHours)),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.body.copyWith(color: AppColors.ink3),
                      ),
                    ),
                    Text(value, style: AppText.number),
                  ],
                ),
              ),
            if (_error != null) InlineError(_error!),
          ],
        ),
      ),
    );
  }
}
