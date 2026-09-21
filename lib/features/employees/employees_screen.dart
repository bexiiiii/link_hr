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
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
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
