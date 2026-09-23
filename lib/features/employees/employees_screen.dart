import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/hr.dart';

/// HR directory backed by `hrms.api.get_all_employees`; no placeholder people
/// are shown here. The endpoint itself enforces the caller's Frappe rights.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Json> _people = const [];
  Object? _error;
  bool _loading = true;
  String _query = '';

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
      final people = await Hr.employees(refresh: true);
      if (!mounted) return;
      setState(() {
        _people = people;
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
    final q = _query.trim().toLowerCase();
    final rows = _people.where((person) {
      if (q.isEmpty) return true;
      return [
        person['employee_name'],
        person['name'],
        person['designation'],
        person['department'],
        person['user_id'],
      ].join(' ').toLowerCase().contains(q);
    }).toList();

    return AppPage(
      header: ScreenHeader(title: tx('Сотрудники', 'Қызметкерлер')),
      body: PageScroll(
        onRefresh: _load,
        children: [
          CupertinoSearchTextField(
            placeholder: tx('Поиск сотрудника', 'Қызметкерді іздеу'),
            backgroundColor: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.field),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          if (!_loading && _error == null) ...[
            Row(
              children: [
                Expanded(
                  child: _DirectoryMetric(
                    value: '${_people.length}',
                    label: tx('В команде', 'Командада'),
                    color: AppColors.greenSoft,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectoryMetric(
                    value:
                        '${_people.map((e) => e['department']).where((e) => e != null && e.toString().isNotEmpty).toSet().length}',
                    label: tx('Отделов', 'Бөлімдер'),
                    color: AppColors.blueSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx('Вся команда', 'Барлық команда'),
                    style: AppText.sectionTitle,
                  ),
                ),
                Text(
                  '${rows.length}',
                  style: AppText.label.copyWith(color: AppColors.ink3),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_loading)
            const SkeletonCards(count: 6, height: 66)
          else if (_error != null)
            ErrorState(error: _error!, onRetry: _load)
          else if (rows.isEmpty)
            EmptyState(
              icon: AppIcons.person,
              title: tx('Сотрудники не найдены', 'Қызметкерлер табылмады'),
              message: q.isEmpty
                  ? tx(
                      'Доступные сотрудники появятся здесь после добавления в кадровую систему.',
                      'Қолжетімді қызметкерлер кадр жүйесіне қосылғаннан кейін осында шығады.',
                    )
                  : tx(
                      'Попробуйте другой запрос.',
                      'Басқа сұрауды қолданып көріңіз.',
                    ),
            )
          else
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Divided(
                children: [
                  for (final person in rows) _EmployeeRow(person: person),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DirectoryMetric extends StatelessWidget {
  const _DirectoryMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.tile),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.title),
        const SizedBox(height: 3),
        Text(label, style: AppText.caption.copyWith(color: AppColors.ink2)),
      ],
    ),
  );
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.person});

  final Json person;

  @override
  Widget build(BuildContext context) {
    final name = (person['employee_name'] ?? person['name'] ?? '').toString();
    final subtitle = [
      person['designation'],
      person['department'],
    ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · ');
    final status = person['status']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          AppAvatar(
            name: name,
            imageUrl: person['image']?.toString(),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ],
            ),
          ),
          if (status != null && status.isNotEmpty)
            StatusPill(status, label: _statusLabel(status)),
        ],
      ),
    );
  }

  String _statusLabel(String value) => switch (value.toLowerCase()) {
    'active' => tx('Активен', 'Белсенді'),
    'inactive' => tx('Неактивен', 'Белсенді емес'),
    _ => value,
  };
}
