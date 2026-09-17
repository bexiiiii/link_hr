import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import '../requests/request_kind.dart';
import '../requests/request_list_screen.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  Map<String, Json> _balance = {};
  List<Json> _leaves = [];
  List<Json> _holidays = [];
  bool _loading = true;
  Object? _error;

  static const _gaugeColors = [
    AppColors.violet,
    AppColors.green,
    AppColors.charcoal,
    AppColors.amber,
  ];

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
    try {
      final results = await Future.wait<Object>([
        Hr.leaveBalance().catchError((_) => <String, Json>{}),
        Hr.leaves(limit: 5),
        Hr.holidays().catchError((_) => <Json>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as Map<String, Json>;
        _leaves = results[1] as List<Json>;
        _holidays = results[2] as List<Json>;
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

  void _showAllHolidays() {
    final today = Fmt.dateOnly(DateTime.now());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (c) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(c).size.height * 0.8,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Праздники', style: AppText.heading),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: _holidays.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final h = _holidays[i];
                    final past = (Fmt.parse(h['holiday_date']) ?? today)
                        .isBefore(today);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              h['description']?.toString() ?? '',
                              style: AppText.body.copyWith(
                                color: past ? AppColors.ink3 : AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            Fmt.dayMonth(h['holiday_date']),
                            style: AppText.number.copyWith(
                              color: past ? AppColors.ink3 : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = Fmt.dateOnly(DateTime.now());
    final upcoming = _holidays
        .where((h) => !(Fmt.parse(h['holiday_date']) ?? today).isBefore(today))
        .take(3)
        .toList();
    return AppPage(
      header: ScreenHeader(
        title: 'Отпуска',
        showBack: widget.showBack,
        actions: [
          CircleButton(
            icon: AppIcons.add,
            label: 'Заявление на отпуск',
            onTap: () => pushPage(context, RequestKind.leave.form()),
          ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        children: [
          SectionHeader(
            'Остаток отпуска',
            topGap: 0,
            actionLabel: 'История',
            onAction: () => pushPage(
              context,
              const RequestListScreen(kind: RequestKind.leave),
            ),
          ),
          if (_loading)
            const Skeleton(height: 168, radius: AppRadius.card)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (_balance.isEmpty)
            const EmptyState(
              icon: AppIcons.airplane,
              title: 'Дни отпуска не распределены',
              message:
                  'Когда отдел кадров выделит дни отпуска, здесь появится остаток по каждому виду.',
            )
          else
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                itemCount: _balance.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final entry = _balance.entries.elementAt(i);
                  final allocated = Fmt.number(entry.value['allocated_leaves']);
                  final left = Fmt.number(entry.value['balance_leaves']);
                  return SizedBox(
                    width: 156,
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SemicircleGauge(
                            value: allocated == 0
                                ? 0
                                : (left / allocated).toDouble(),
                            color: _gaugeColors[i % _gaugeColors.length],
                            size: 92,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${Fmt.decimal(left)}/${Fmt.decimal(allocated)}',
                            style: AppText.heading.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.key,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Подать заявление на отпуск',
            icon: AppIcons.airplane,
            kind: ButtonKind.violet,
            onTap: () => pushPage(context, RequestKind.leave.form()),
          ),
          SectionHeader(
            'Недавние заявления',
            actionLabel: 'Все',
            onAction: () => pushPage(
              context,
              const RequestListScreen(kind: RequestKind.leave),
            ),
          ),
          if (_loading)
            const SkeletonCards(count: 2, height: 76)
          else if (_leaves.isEmpty)
            const EmptyState(
              icon: AppIcons.docText,
              title: 'Заявлений пока нет',
              message:
                  'Поданные заявления на отпуск и их статус согласования появятся здесь.',
            )
          else
            for (final l in _leaves)
              RequestTile(kind: RequestKind.leave, data: l, onChanged: _load),
          SectionHeader(
            'Праздники',
            actionLabel: _holidays.isEmpty ? null : 'Все',
            onAction: _showAllHolidays,
          ),
          if (!_loading && upcoming.isEmpty)
            const EmptyState(
              icon: AppIcons.calendar,
              title: 'Ближайших праздников нет',
              message:
                  'Праздничные дни берутся из списка выходных, назначенного вам в HR.',
            )
          else
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Divided(
                children: [
                  for (final h in upcoming)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const IconBadge(
                            icon: AppIcons.gift,
                            tone: Tone.amber,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              h['description']?.toString() ?? '',
                              style: AppText.bodyStrong,
                            ),
                          ),
                          Text(
                            Fmt.dayMonth(h['holiday_date']),
                            style: AppText.number,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
