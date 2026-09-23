import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';
import 'team_map_screen.dart';

enum _ReportMode { now, day, month }

class TeamAttendanceScreen extends StatefulWidget {
  const TeamAttendanceScreen({super.key});

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  _ReportMode _mode = _ReportMode.now;
  DateTime _day = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<_TeamDay> _dayRows = const [];
  List<_MonthRow> _monthRows = const [];
  String _query = '';
  Object? _error;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _mode == _ReportMode.now) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (_mode == _ReportMode.month) {
        final rows =
            (await Hr.teamAttendanceForMonth(
                _month,
              )).map(_MonthRow.from).toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        if (!mounted) return;
        setState(() {
          _monthRows = rows;
          _loading = false;
          _error = null;
        });
      } else {
        final target = _mode == _ReportMode.now ? DateTime.now() : _day;
        final rows =
            (await Hr.teamAttendanceForDay(target)).map(_TeamDay.from).toList()
              ..sort((a, b) {
                if (a.status != b.status) {
                  return a.status.index.compareTo(b.status.index);
                }
                return a.name.compareTo(b.name);
              });
        if (!mounted) return;
        setState(() {
          _dayRows = rows;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _setMode(int index) {
    final next = _ReportMode.values[index];
    if (next == _mode) return;
    setState(() {
      _mode = next;
      _query = '';
    });
    _load();
  }

  Future<void> _pickPeriod() async {
    final initial = _mode == _ReportMode.month ? _month : _day;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      locale: Locale(AppLanguageController.instance.current.code),
    );
    if (date == null) return;
    setState(() {
      if (_mode == _ReportMode.month) {
        _month = DateTime(date.year, date.month);
      } else {
        _day = date;
      }
    });
    _load();
  }

  bool _matches(String name, String subtitle) {
    final needle = _query.trim().toLowerCase();
    return needle.isEmpty ||
        name.toLowerCase().contains(needle) ||
        subtitle.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.instance.isHr) return _locked();
    final dayRows = _dayRows
        .where((row) => _matches(row.name, row.subtitle))
        .toList();
    final monthRows = _monthRows
        .where((row) => _matches(row.name, row.subtitle))
        .toList();

    return AppPage(
      header: ScreenHeader(
        title: tx('Отчёты команды', 'Команда есептері'),
        actions: [
          if (_mode == _ReportMode.now)
            CircleButton(
              icon: AppIcons.location,
              label: tx('Карта команды', 'Команда картасы'),
              onTap: () => pushPage(context, const TeamMapScreen()),
            ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
        children: [
          SegmentTabs(
            labels: [
              tx('Сейчас', 'Қазір'),
              tx('День', 'Күн'),
              tx('Месяц', 'Ай'),
            ],
            index: _mode.index,
            onChanged: _setMode,
          ),
          const SizedBox(height: 14),
          if (_mode != _ReportMode.now)
            _PeriodButton(
              label: _mode == _ReportMode.month
                  ? Fmt.monthYear(_month)
                  : Fmt.long(_day),
              onTap: _pickPeriod,
            ),
          if (_mode != _ReportMode.now) const SizedBox(height: 12),
          CupertinoSearchTextField(
            placeholder: tx(
              'Поиск сотрудника или отдела',
              'Қызметкерді немесе бөлімді іздеу',
            ),
            backgroundColor: AppColors.surface,
            itemColor: AppColors.ink2,
            style: AppText.body,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Skeleton(height: 120, radius: AppRadius.card)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (_mode == _ReportMode.month) ...[
            _MonthSummary(rows: _monthRows),
            SectionHeader(tx('По сотрудникам', 'Қызметкерлер бойынша')),
            if (monthRows.isEmpty)
              _emptySearch()
            else
              SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divided(
                  children: [
                    for (final row in monthRows) _MonthRowTile(row: row),
                  ],
                ),
              ),
          ] else ...[
            _DaySummary(rows: _dayRows, live: _mode == _ReportMode.now),
            SectionHeader(
              _mode == _ReportMode.now
                  ? tx('Сотрудники сейчас', 'Қазір қызметкерлер')
                  : tx('Сотрудники', 'Қызметкерлер'),
              actionLabel: _mode == _ReportMode.now
                  ? tx('Обновляется автоматически', 'Автоматты жаңартылады')
                  : null,
            ),
            if (dayRows.isEmpty)
              _emptySearch()
            else
              SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divided(
                  children: [for (final row in dayRows) _TeamDayRow(row: row)],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _locked() => AppPage(
    header: ScreenHeader(title: tx('Отчёты команды', 'Команда есептері')),
    body: PageScroll(
      children: [
        EmptyState(
          icon: AppIcons.lock,
          title: tx('Раздел для HR', 'HR бөлімі'),
          message: tx(
            'Командные отчёты доступны только сотрудникам с правами отдела кадров.',
            'Команда есептері тек кадр бөлімі рұқсаты бар қызметкерлерге қолжетімді.',
          ),
        ),
      ],
    ),
  );

  Widget _emptySearch() => EmptyState(
    icon: AppIcons.search,
    title: tx('Ничего не найдено', 'Ештеңе табылмады'),
    message: tx(
      'Измените запрос или выбранный период.',
      'Сұрауды немесе таңдалған кезеңді өзгертіңіз.',
    ),
  );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.calendar, size: 19, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppText.bodyStrong)),
          const Icon(AppIcons.chevronDown, size: 16, color: AppColors.ink3),
        ],
      ),
    ),
  );
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.rows, required this.live});
  final List<_TeamDay> rows;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final present = rows
        .where((row) => row.status == _DayStatus.present)
        .length;
    final left = rows.where((row) => row.status == _DayStatus.left).length;
    final absent = rows.where((row) => row.status == _DayStatus.absent).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (live) ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                tx('Данные за сегодня', 'Бүгінгі деректер'),
                style: AppText.label,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: tx('Всего', 'Барлығы'),
                value: rows.length,
                color: AppColors.violet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: tx('На работе', 'Жұмыста'),
                value: present,
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: tx('Ушли', 'Кетті'),
                value: left,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: tx('Без отметки', 'Белгісіз'),
                value: absent,
                color: AppColors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.rows});
  final List<_MonthRow> rows;

  @override
  Widget build(BuildContext context) {
    final hours = rows.fold<double>(0, (sum, row) => sum + row.hours);
    final present = rows.fold<double>(0, (sum, row) => sum + row.present);
    final late = rows.fold<int>(0, (sum, row) => sum + row.late);
    final missing = rows.fold<double>(0, (sum, row) => sum + row.missing);
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: tx('Часы', 'Сағат'),
            valueText: hours.toStringAsFixed(1),
            color: AppColors.violet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: tx('Дни', 'Күн'),
            valueText: Fmt.decimal(present),
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: tx('Опоздания', 'Кешігу'),
            value: late,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: tx('Нет данных', 'Дерек жоқ'),
            valueText: Fmt.decimal(missing),
            color: AppColors.red,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.color,
    this.value,
    this.valueText,
  });
  final String label;
  final Color color;
  final int? value;
  final String? valueText;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.tile),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 12),
        Text(valueText ?? '${value ?? 0}', style: AppText.heading),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption,
        ),
      ],
    ),
  );
}

enum _DayStatus { present, left, absent }

class _TeamDay {
  const _TeamDay({
    required this.name,
    required this.image,
    required this.subtitle,
    required this.firstIn,
    required this.lastOut,
    required this.lastEvent,
    required this.status,
  });

  final String name;
  final String? image;
  final String subtitle;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final DateTime? lastEvent;
  final _DayStatus status;

  factory _TeamDay.from(Json person) => _TeamDay(
    name: (person['employee_name'] ?? person['name']).toString(),
    image: person['image']?.toString(),
    subtitle: [person['designation'], person['department']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' · '),
    firstIn: Fmt.parse(person['first_in']),
    lastOut: Fmt.parse(person['last_out']),
    lastEvent: Fmt.parse(person['last_event_time']),
    status: switch (person['status']?.toString()) {
      'present' => _DayStatus.present,
      'left' => _DayStatus.left,
      _ => _DayStatus.absent,
    },
  );
}

class _TeamDayRow extends StatelessWidget {
  const _TeamDayRow({required this.row});
  final _TeamDay row;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (row.status) {
      _DayStatus.present => (tx('На работе', 'Жұмыста'), Tone.green),
      _DayStatus.left => (tx('Ушёл', 'Кетті'), Tone.amber),
      _DayStatus.absent => (tx('Без отметки', 'Белгісіз'), Tone.neutral),
    };
    final interval = row.firstIn == null
        ? tx('Нет отметки', 'Белгі жоқ')
        : row.lastOut == null
        ? '${tx('Пришёл', 'Келді')} ${Fmt.time(row.firstIn)}'
        : '${Fmt.time(row.firstIn)} – ${Fmt.time(row.lastOut)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AppAvatar(name: row.name, imageUrl: row.image, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 3),
                Text(
                  row.subtitle.isEmpty
                      ? interval
                      : '${row.subtitle} · $interval',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label, label: label, tone: tone),
        ],
      ),
    );
  }
}

class _MonthRow {
  const _MonthRow({
    required this.name,
    required this.image,
    required this.subtitle,
    required this.present,
    required this.absent,
    required this.leave,
    required this.missing,
    required this.late,
    required this.hours,
    required this.workingDays,
  });

  final String name;
  final String? image;
  final String subtitle;
  final double present;
  final double absent;
  final double leave;
  final double missing;
  final int late;
  final double hours;
  final int workingDays;

  factory _MonthRow.from(Json row) => _MonthRow(
    name: (row['employee_name'] ?? row['employee']).toString(),
    image: row['image']?.toString(),
    subtitle: [row['designation'], row['department']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' · '),
    present: Fmt.number(row['present_days']).toDouble(),
    absent: Fmt.number(row['absent_days']).toDouble(),
    leave: Fmt.number(row['leave_days']).toDouble(),
    missing: Fmt.number(row['missing_days']).toDouble(),
    late: Fmt.number(row['late_days']).toInt(),
    hours: Fmt.number(row['working_hours']).toDouble(),
    workingDays: Fmt.number(row['working_days']).toInt(),
  );
}

class _MonthRowTile extends StatelessWidget {
  const _MonthRowTile({required this.row});
  final _MonthRow row;

  @override
  Widget build(BuildContext context) {
    final ratio = row.workingDays == 0
        ? 0.0
        : (row.present / row.workingDays).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(name: row.name, imageUrl: row.image, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '${row.hours.toStringAsFixed(1)} ${tx('ч', 'сағ')}',
                style: AppText.bodyStrong,
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _mini(
                tx('Присутствие', 'Қатысу'),
                Fmt.decimal(row.present),
                AppColors.green,
              ),
              _mini(
                tx('Отсутствие', 'Жоқ'),
                Fmt.decimal(row.absent + row.missing),
                AppColors.red,
              ),
              _mini(tx('Опоздания', 'Кешігу'), '${row.late}', AppColors.amber),
              if (row.leave > 0)
                _mini(
                  tx('Отпуск', 'Демалыс'),
                  Fmt.decimal(row.leave),
                  AppColors.violet,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) => Expanded(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$value $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption,
          ),
        ),
      ],
    ),
  );
}
