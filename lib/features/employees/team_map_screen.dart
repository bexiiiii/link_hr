import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/fmt.dart';
import '../../core/minimap.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';

class TeamMapScreen extends StatefulWidget {
  const TeamMapScreen({super.key});

  @override
  State<TeamMapScreen> createState() => _TeamMapScreenState();
}

class _TeamMapScreenState extends State<TeamMapScreen> {
  List<TeamMapMarker> _markers = const [];
  List<Json> _locations = const [];
  Object? _error;
  bool _loading = true;
  ShiftLocation? _office;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(quiet: true),
    );
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
      final results = await Future.wait<Object?>([
        Hr.teamLocationsToday(),
        Hr.shiftLocation().catchError((_) => null),
      ]);
      final markers = (results[0] as List<Json>).map((row) {
        return TeamMapMarker(
          latitude: Fmt.number(row['latitude']).toDouble(),
          longitude: Fmt.number(row['longitude']).toDouble(),
          name: (row['employee_name'] ?? row['employee']).toString(),
          imageUrl: row['image']?.toString(),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _locations = results[0] as List<Json>;
        _office = results[1] as ShiftLocation?;
        _loading = false;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    if (!Session.instance.isHr) {
      return AppPage(
        header: ScreenHeader(title: tx('Карта команды', 'Команда картасы')),
        body: PageScroll(
          children: [
            EmptyState(
              icon: AppIcons.lock,
              title: tx('Раздел для HR', 'HR бөлімі'),
              message: tx(
                'Карта команды доступна только сотрудникам с правами отдела кадров.',
                'Команда картасы тек кадр бөлімі рұқсаты бар қызметкерлерге қолжетімді.',
              ),
            ),
          ],
        ),
      );
    }
    return AppPage(
      header: ScreenHeader(
        title: tx('Карта команды', 'Команда картасы'),
        actions: [
          CircleButton(
            icon: AppIcons.clock,
            label: tx('Обновить', 'Жаңарту'),
            onTap: _loading ? null : _load,
          ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        children: [
          Text(
            tx('Команда в реальном времени', 'Команда нақты уақытта'),
            style: AppText.heading,
          ),
          const SizedBox(height: 4),
          Text(
            tx(
              'Последние GPS-отметки обновляются каждые 30 секунд.',
              'Соңғы GPS белгілері әр 30 секунд сайын жаңартылады.',
            ),
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Skeleton(height: 360, radius: AppRadius.card)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (_markers.isEmpty)
            EmptyState(
              icon: AppIcons.location,
              title: tx('Нет отметок с GPS', 'GPS белгілері жоқ'),
              message: tx(
                'Когда сотрудники отметятся с геолокацией, их точки появятся здесь.',
                'Қызметкерлер геолокациямен белгіленгеннен кейін олардың нүктелері осында көрінеді.',
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: MiniMap(
                height: 420,
                officeLat: _office?.latitude,
                officeLon: _office?.longitude,
                officeRadius: _office?.radius,
                officeName: _office?.name,
                team: _markers,
                onRefresh: _load,
              ),
            ),
          if (!_loading && _error == null && _markers.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionHeader(
              tx('Сейчас на работе', 'Қазір жұмыста'),
              actionLabel: '${tx('На карте', 'Картада')} ${_markers.length}',
            ),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divided(
                children: [
                  for (final row in _locations.where(
                    (item) => item['status']?.toString() == 'present',
                  ))
                    _LiveEmployeeRow(row: row),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveEmployeeRow extends StatelessWidget {
  const _LiveEmployeeRow({required this.row});
  final Json row;

  @override
  Widget build(BuildContext context) {
    final name = (row['employee_name'] ?? row['employee']).toString();
    final subtitle = [row['designation'], row['department']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' · ');
    final event = Fmt.parse(row['last_event_time']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AppAvatar(name: name, imageUrl: row['image']?.toString(), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.bodyStrong),
                if (subtitle.isNotEmpty) Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                null,
                label: tx('На работе', 'Жұмыста'),
                tone: Tone.green,
              ),
              if (event != null) ...[
                const SizedBox(height: 4),
                Text(Fmt.time(event), style: AppText.caption),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
