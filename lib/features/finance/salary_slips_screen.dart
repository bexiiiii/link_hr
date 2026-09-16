import 'package:flutter/cupertino.dart';

import '../../core/api.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import 'salary_slip_detail_screen.dart';

class SalarySlipsScreen extends StatefulWidget {
  const SalarySlipsScreen({super.key});

  @override
  State<SalarySlipsScreen> createState() => _SalarySlipsScreenState();
}

class _SalarySlipsScreenState extends State<SalarySlipsScreen> {
  List<Json> _periods = [];
  Json? _period;
  List<Json> _slips = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _periods = await Hr.payrollPeriods().catchError((_) => <Json>[]);
    _period = _periods.isEmpty ? null : _periods.first;
    await _load();
  }

  Future<void> _load() async {
    try {
      final slips = await Hr.salarySlips(
        from: Fmt.parse(_period?['start_date']),
        to: Fmt.parse(_period?['end_date']),
      );
      if (!mounted) return;
      setState(() {
        _slips = slips;
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

  String _periodLabel(Json p) =>
      '${Fmt.monthYear(Fmt.parse(p['start_date'])!)} – ${Fmt.monthYear(Fmt.parse(p['end_date'])!)}';

  @override
  Widget build(BuildContext context) {
    final latest = _slips.isEmpty ? null : _slips.first;
    return AppPage(
      header: const ScreenHeader(title: 'Расчётные листки'),
      body: PageScroll(onRefresh: _load, children: [
        if (_periods.isNotEmpty) ...[
          SelectInput(
            label: 'Расчётный период',
            value: _period?['name']?.toString(),
            options: [for (final p in _periods) SelectOption(p['name'].toString(), _periodLabel(p))],
            onChanged: (v) {
              setState(() {
                _period = _periods.firstWhere((p) => p['name'] == v);
                _loading = true;
              });
              _load();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (_loading)
          const SkeletonCards(count: 4, height: 84)
        else if (_error != null)
          ErrorState(error: _error!, onRetry: _load)
        else if (_slips.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.doc_plaintext,
            title: 'Расчётных листков пока нет',
            message: 'Листки появятся после того, как бухгалтерия проведёт расчёт зарплаты.',
          )
        else ...[
          SurfaceCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Выплачено с начала года', style: AppText.caption),
                  const SizedBox(height: 4),
                  Text(Fmt.money(latest!['year_to_date'], latest['currency']?.toString()),
                      style: AppText.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),
              const IconBadge(icon: CupertinoIcons.chart_bar_alt_fill, tone: Tone.green, size: 48),
            ]),
          ),
          const SectionHeader('Листки'),
          for (final s in _slips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                radius: AppRadius.tile,
                padding: const EdgeInsets.all(16),
                onTap: () => pushPage(context, SalarySlipDetailScreen(name: s['name'].toString())),
                child: Row(children: [
                  const IconBadge(icon: CupertinoIcons.doc_plaintext, tone: Tone.dark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(Fmt.monthYear(Fmt.parse(s['start_date']) ?? DateTime.now()),
                          style: AppText.cardTitle.copyWith(fontSize: 15)),
                      Text(Fmt.range(s['start_date'], s['end_date']), style: AppText.caption),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Fmt.money(s['net_pay'], s['currency']?.toString()), style: AppText.number),
                    Text('до вычетов ${Fmt.money(s['gross_pay'], s['currency']?.toString())}', style: AppText.caption),
                  ]),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
