import 'package:flutter/cupertino.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/files.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';

class SalarySlipDetailScreen extends StatefulWidget {
  const SalarySlipDetailScreen({super.key, required this.name});

  final String name;

  @override
  State<SalarySlipDetailScreen> createState() => _SalarySlipDetailScreenState();
}

class _SalarySlipDetailScreenState extends State<SalarySlipDetailScreen> {
  Json? _doc;
  Object? _error;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await Api.instance.doc('Salary Slip', widget.name);
      if (mounted) {
        setState(() {
          _doc = doc;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final uri = await Hr.salarySlipPdf(widget.name);
      await Files.openDataUri(uri, '${widget.name}.pdf');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  List<(String, String)> _components(String table, String cur) => [
    for (final row in (_doc?[table] as List? ?? const []))
      if (row['statistical_component'] != 1 && Fmt.number(row['amount']) != 0)
        (row['salary_component'].toString(), Fmt.money(row['amount'], cur)),
  ];

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    return AppPage(
      header: ScreenHeader(
        title: 'Расчётный листок',
        actions: [
          _downloading
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: CupertinoActivityIndicator(),
                )
              : CircleButton(
                  icon: AppIcons.arrowDownDoc,
                  label: 'Скачать PDF',
                  onTap: d == null ? null : _download,
                ),
        ],
      ),
      body: _error != null
          ? PageScroll(
              children: [ErrorState(error: _error!, onRetry: _load)],
            )
          : d == null
          ? PageScroll(
              children: const [
                Skeleton(height: 120, radius: AppRadius.card),
                SizedBox(height: 16),
                SkeletonCards(count: 2, height: 180),
              ],
            )
          : _content(d),
    );
  }

  Widget _content(Json d) {
    final cur = d['currency']?.toString() ?? 'KZT';
    final earnings = _components('earnings', cur);
    final deductions = _components('deductions', cur);
    return PageScroll(
      onRefresh: _load,
      children: [
        Text(
          Fmt.monthYear(Fmt.parse(d['start_date']) ?? DateTime.now()),
          style: AppText.display,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              Fmt.range(d['start_date'], d['end_date']),
              style: AppText.label.copyWith(color: AppColors.ink3),
            ),
            const SizedBox(width: 10),
            StatusPill(d['status']?.toString()),
          ],
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('К выплате', style: AppText.caption),
              const SizedBox(height: 4),
              Text(
                Fmt.money(d['rounded_total'] ?? d['net_pay'], cur),
                style: AppText.display.copyWith(
                  fontSize: 28,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if ((d['total_in_words'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(d['total_in_words'].toString(), style: AppText.caption),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: 'Начислено',
                      value: Fmt.money(d['gross_pay'], cur),
                      color: AppColors.greenDeep,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'Удержано',
                      value: Fmt.money(d['total_deduction'], cur),
                      color: AppColors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (earnings.isNotEmpty) ...[
          const SectionHeader('Начисления'),
          FieldRows(rows: earnings),
        ],
        if (deductions.isNotEmpty) ...[
          const SectionHeader('Удержания и налоги'),
          FieldRows(rows: deductions),
        ],
        const SectionHeader('Рабочее время'),
        FieldRows(
          rows: [
            ('Рабочих дней', Fmt.decimal(d['total_working_days'])),
            ('Оплачиваемых дней', Fmt.decimal(d['payment_days'])),
            (
              'Без сохранения зарплаты',
              Fmt.number(d['leave_without_pay']) == 0
                  ? ''
                  : Fmt.decimal(d['leave_without_pay']),
            ),
            (
              'Отсутствие',
              Fmt.number(d['absent_days']) == 0
                  ? ''
                  : Fmt.decimal(d['absent_days']),
            ),
            ('Способ выплаты', d['mode_of_payment']?.toString() ?? ''),
            ('Банк', d['bank_name']?.toString() ?? ''),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LegendDot(color: color, label: label),
        const SizedBox(height: 4),
        Text(value, style: AppText.number),
      ],
    );
  }
}
