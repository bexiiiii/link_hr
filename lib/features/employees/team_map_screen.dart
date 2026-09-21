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
  Object? _error;
  bool _loading = true;
  ShiftLocation? _office;

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
        _office = results[1] as ShiftLocation?;
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
            icon: AppIcons.arrowRight,
            label: tx('Обновить', 'Жаңарту'),
            onTap: _loading ? null : _load,
          ),
        ],
      ),
      body: PageScroll(
        onRefresh: _load,
        children: [
          Text(
            tx('Кто сейчас на работе', 'Қазір жұмыстағылар'),
            style: AppText.heading,
          ),
          const SizedBox(height: 4),
          Text(
            tx(
              'Точки показываются по последней отметке прихода с GPS за сегодня.',
              'Нүктелер бүгінгі GPS-пен тіркелген соңғы келу белгісінен көрсетіледі.',
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
            Text(
              '${tx('На карте', 'Картада')}: ${_markers.length}',
              style: AppText.label,
            ),
          ],
        ],
      ),
    );
  }
}
