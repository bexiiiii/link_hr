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

class TeamAttendanceScreen extends StatefulWidget {
  const TeamAttendanceScreen({super.key});

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  DateTime _day = DateTime.now();
  List<_TeamDay> _rows = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          (await Hr.teamAttendanceForDay(_day)).map(_TeamDay.from).toList()
            ..sort((a, b) {
              if (a.status != b.status)
                return a.status.index.compareTo(b.status.index);
              return a.name.compareTo(b.name);
            });
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: Locale(AppLanguageController.instance.current.code),
    );
    if (date == null || Fmt.dateOnly(date) == Fmt.dateOnly(_day)) return;
    setState(() => _day = date);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.instance.isHr) {
      return AppPage(
        header: ScreenHeader(title: tx('Команда сегодня', 'Команда бүгін')),
        body: PageScroll(
          children: [
            EmptyState(
              icon: AppIcons.lock,
              title: tx('Раздел для HR', 'HR бөлімі'),
              message: tx(
                'Посещаемость команды доступна только сотрудникам с правами отдела кадров.',
                'Команда қатысуы тек кадр бөлімі рұқсаты бар қызметкерлерге қолжетімді.',
              ),
            ),
          ],
        ),
      );
    }
    final present = _rows
        .where((row) => row.status == _DayStatus.present)
        .length;
    final left = _rows.where((row) => row.status == _DayStatus.left).length;
    final absent = _rows.where((row) => row.status == _DayStatus.absent).length;

    return AppPage(
      header: ScreenHeader(
        title: tx('Команда сегодня', 'Команда бүгін'),
        actions: [
          CircleButton(
            icon: AppIcons.calendar,
            label: tx('Выбрать дату', 'Күнді таңдау'),
            onTap: _pickDay,
          ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        children: [
          Pressable(
            onTap: _pickDay,
            child: Row(
              children: [
                Text(Fmt.long(_day), style: AppText.heading),
                const SizedBox(width: 6),
                const Icon(
                  AppIcons.chevronDown,
                  size: 16,
                  color: AppColors.ink3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Skeleton(height: 94, radius: AppRadius.card)
          else
            _TeamStats(present: present, left: left, absent: absent),
          const SectionHeader('Сотрудники', topGap: 22),
          if (_loading)
            const SkeletonCards(count: 6, height: 68)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (_rows.isEmpty)
            EmptyState(
              icon: AppIcons.person,
              title: tx('Нет сотрудников', 'Қызметкерлер жоқ'),
              message: tx(
                'Список появится, когда он станет доступен в кадровой системе.',
                'Тізім кадр жүйесінде қолжетімді болғанда пайда болады.',
              ),
            )
          else
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Divided(
                children: [for (final row in _rows) _TeamDayRow(row: row)],
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamStats extends StatelessWidget {
  const _TeamStats({
    required this.present,
    required this.left,
    required this.absent,
  });
  final int present;
  final int left;
  final int absent;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: Row(
      children: [
        _stat(tx('На работе', 'Жұмыста'), present, AppColors.blue),
        _stat(tx('Ушли', 'Кетті'), left, AppColors.amber),
        _stat(tx('Нет отметки', 'Белгі жоқ'), absent, AppColors.ink3),
      ],
    ),
  );

  Widget _stat(String label, int value, Color color) => Expanded(
    child: Column(
      children: [
        Text('$value', style: AppText.title.copyWith(color: color)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: AppText.caption),
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
    required this.status,
  });

  final String name;
  final String? image;
  final String subtitle;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final _DayStatus status;

  factory _TeamDay.from(Json person) {
    final status = switch (person['status']?.toString()) {
      'present' => _DayStatus.present,
      'left' => _DayStatus.left,
      _ => _DayStatus.absent,
    };
    return _TeamDay(
      name: (person['employee_name'] ?? person['name']).toString(),
      image: person['image']?.toString(),
      subtitle: [person['designation'], person['department']]
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .join(' · '),
      firstIn: Fmt.parse(person['first_in']),
      lastOut: Fmt.parse(person['last_out']),
      status: status,
    );
  }
}

class _TeamDayRow extends StatelessWidget {
  const _TeamDayRow({required this.row});
  final _TeamDay row;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (row.status) {
      _DayStatus.present => (tx('На работе', 'Жұмыста'), Tone.green),
      _DayStatus.left => (tx('Ушёл', 'Кетті'), Tone.amber),
      _DayStatus.absent => (tx('Нет отметки', 'Белгі жоқ'), Tone.neutral),
    };
    final hours = row.firstIn == null
        ? tx('Нет отметки', 'Белгі жоқ')
        : row.lastOut == null
        ? '${tx('Пришёл', 'Келді')} ${Fmt.time(row.firstIn)}'
        : '${Fmt.time(row.firstIn)} — ${Fmt.time(row.lastOut)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
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
                const SizedBox(height: 2),
                Text(
                  row.subtitle.isEmpty ? hours : '${row.subtitle} · $hours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          StatusPill(label, label: label, tone: tone),
        ],
      ),
    );
  }
}
