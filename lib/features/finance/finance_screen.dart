import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_kind.dart';
import '../requests/request_list_screen.dart';
import 'salary_slip_detail_screen.dart';
import 'salary_slips_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Json _summary = {};
  List<Json> _claims = [];
  List<Json> _advances = [];
  Json? _slip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    Session.instance.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    Session.instance.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      Hr.expenseSummary().catchError((_) => <String, dynamic>{}),
      Hr.expenseClaims(limit: 5).catchError((_) => <Json>[]),
      Hr.advanceBalance().catchError((_) => <Json>[]),
      Hr.salarySlips().catchError((_) => <Json>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = results[0] as Json;
      _claims = results[1] as List<Json>;
      _advances = results[2] as List<Json>;
      final slips = results[3] as List<Json>;
      _slip = slips.isEmpty ? null : slips.first;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cur = _summary['currency']?.toString() ?? Session.instance.currency;
    final pending = Fmt.number(_summary['total_pending_amount']);
    final approved = Fmt.number(_summary['total_approved_amount']);
    final rejected = Fmt.number(_summary['total_rejected_amount']) +
        (Fmt.number(_summary['total_claimed_in_approved']) - approved);
    final total = pending + Fmt.number(_summary['total_claimed_in_approved']) + Fmt.number(_summary['total_rejected_amount']);

    return AppPage(
      header: ScreenHeader(title: 'Финансы', showBack: widget.showBack, actions: [
        CircleButton(
          icon: CupertinoIcons.add,
          label: 'Новый расход',
          onTap: () async {
            final kind = await pickAction(context, actions: const [
              SheetAction('expense', 'Авансовый отчёт'),
              SheetAction('advance', 'Запросить аванс'),
            ]);
            if (kind != null && context.mounted) pushPage(context, RequestKind.values.byName(kind).form());
          },
        ),
      ]),
      body: PageScroll(onRefresh: _load, children: [
        if (_loading)
          const Skeleton(height: 132, radius: AppRadius.card)
        else
          SurfaceCard(
            color: AppColors.charcoal,
            onTap: () => pushPage(
              context,
              _slip == null ? const SalarySlipsScreen() : SalarySlipDetailScreen(name: _slip!['name'].toString()),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    _slip == null
                        ? 'Расчётные листки'
                        : 'К выплате за ${Fmt.monthYear(Fmt.parse(_slip!['start_date']) ?? DateTime.now()).toLowerCase()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFB9B9C8)),
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right, size: 16, color: Color(0xFFB9B9C8)),
              ]),
              const SizedBox(height: 8),
              Text(
                _slip == null ? 'Пока нет' : Fmt.money(_slip!['net_pay'], _slip!['currency']?.toString()),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _slip == null
                    ? 'Листки появятся после расчёта зарплаты'
                    : 'Начислено ${Fmt.money(_slip!['gross_pay'], _slip!['currency']?.toString())} · удержано ${Fmt.money(_slip!['total_deduction'], _slip!['currency']?.toString())}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB9B9C8)),
              ),
            ]),
          ),
        const SectionHeader('Расходы'),
        SurfaceCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Всего заявлено', style: AppText.caption),
            const SizedBox(height: 4),
            Text(Fmt.money(total, cur), style: AppText.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Amount(label: 'Ожидает', value: Fmt.money(pending, cur), color: AppColors.amber)),
              Expanded(child: _Amount(label: 'Одобрено', value: Fmt.money(approved, cur), color: AppColors.greenDeep)),
              Expanded(child: _Amount(label: 'Отклонено', value: Fmt.money(rejected, cur), color: AppColors.red)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: PrimaryButton(
              label: 'Отчёт',
              icon: CupertinoIcons.creditcard,
              kind: ButtonKind.violet,
              height: 52,
              onTap: () => pushPage(context, RequestKind.expense.form()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PrimaryButton(
              label: 'Аванс',
              icon: CupertinoIcons.money_dollar_circle,
              height: 52,
              onTap: () => pushPage(context, RequestKind.advance.form()),
            ),
          ),
        ]),
        SectionHeader('Недавние отчёты',
            actionLabel: 'Все', onAction: () => pushPage(context, const RequestListScreen(kind: RequestKind.expense))),
        if (_loading)
          const SkeletonCards(count: 2, height: 76)
        else if (_claims.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.creditcard,
            title: 'Отчётов пока нет',
            message: 'Добавьте расходы на командировку, связь или питание и отправьте их на согласование.',
          )
        else
          for (final c in _claims) RequestTile(kind: RequestKind.expense, data: c, onChanged: _load),
        SectionHeader('Баланс авансов',
            actionLabel: 'Все', onAction: () => pushPage(context, const RequestListScreen(kind: RequestKind.advance))),
        if (!_loading && _advances.isEmpty)
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Text('Невозвращённых авансов нет.', style: AppText.label.copyWith(color: AppColors.ink3)),
          )
        else
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Divided(children: [
              for (final a in _advances)
                Pressable(
                  onTap: () => pushPage(
                      context, RequestDetailScreen(kind: RequestKind.advance, name: a['name'].toString())),
                  scale: 0.99,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      const IconBadge(icon: CupertinoIcons.money_dollar_circle, tone: Tone.amber, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(stripHtml(a['purpose']?.toString()),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                          Text('${Fmt.dayMonth(a['posting_date'])} · ${statusLabel(a['status']?.toString())}',
                              style: AppText.caption),
                        ]),
                      ),
                      Text(Fmt.money(a['balance_amount'], a['currency']?.toString()), style: AppText.number),
                    ]),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LegendDot(color: color, label: label),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: AppText.number),
      ),
    ]);
  }
}
