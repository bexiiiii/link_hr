import 'package:flutter/cupertino.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/tasks.dart';
import '../attendance/checkin_history_screen.dart';
import '../documents/documents_screen.dart';
import '../finance/salary_slips_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../requests/request_kind.dart';
import '../requests/request_list_screen.dart';
import '../tasks/task_card.dart';
import '../tasks/task_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<TaskItem> _tasks = [];
  List<(RequestKind, Json)> _requests = [];
  bool _loading = true;

  late final List<(String, IconData, Widget Function())> _destinations = [
    (
      'Расчётные листки',
      AppIcons.docPlaintext,
      () => const SalarySlipsScreen(),
    ),
    ('Кадровые документы', AppIcons.folder, () => const DocumentsScreen()),
    ('История отметок', AppIcons.clock, () => const CheckinHistoryScreen()),
    ('Уведомления', AppIcons.bell, () => const NotificationsScreen()),
    ('Профиль', AppIcons.person, () => const ProfileScreen()),
    ('Смена пароля', AppIcons.lock, () => const ChangePasswordScreen()),
    for (final k in RequestKind.values)
      (k.plural, k.icon, () => RequestListScreen(kind: k)),
    for (final k in RequestKind.values)
      ('Создать: ${k.singular.toLowerCase()}', AppIcons.add, () => k.form()),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      Tasks.list().catchError((_) => <TaskItem>[]),
      Future.wait(
        RequestKind.values.map(
          (k) => k
              .fetch(limit: 100)
              .then(
                (rows) => rows.map((r) => (k, r)).toList(),
                onError: (_) => <(RequestKind, Json)>[],
              ),
        ),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _tasks = results[0] as List<TaskItem>;
      _requests = (results[1] as List<List<(RequestKind, Json)>>)
          .expand((e) => e)
          .toList();
      _loading = false;
    });
  }

  bool _match(String text) => text.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final q = _query;
    final tasks = q.isEmpty
        ? <TaskItem>[]
        : _tasks
              .where((t) => _match('${t.title} ${t.description}'))
              .take(8)
              .toList();
    final requests = q.isEmpty
        ? <(RequestKind, Json)>[]
        : _requests
              .where(
                (r) => _match(
                  '${r.$1.singular} ${r.$1.heading(r.$2)} ${r.$1.subtitle(r.$2)} ${r.$2['name']} ${r.$2['employee_name'] ?? ''}',
                ),
              )
              .take(12)
              .toList();
    final destinations = _destinations
        .where((d) => q.isEmpty || _match(d.$1))
        .toList();

    return AppPage(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            CircleButton(
              icon: AppIcons.chevronLeft,
              label: 'Назад',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoSearchTextField(
                controller: _controller,
                autofocus: true,
                placeholder: 'Задачи, заявки, разделы',
                backgroundColor: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                style: AppText.body,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
          ],
        ),
      ),
      body: PageScroll(
        children: [
          if (q.isNotEmpty && _loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CupertinoActivityIndicator(),
            ),
          if (tasks.isNotEmpty) ...[
            const SectionHeader('Задачи', topGap: 4),
            for (final t in tasks)
              TaskCard(
                task: t,
                directory: const {},
                onTap: () => pushPage(context, TaskDetailScreen(name: t.name)),
              ),
          ],
          if (requests.isNotEmpty) ...[
            SectionHeader('Заявки', topGap: tasks.isEmpty ? 4 : 20),
            for (final (kind, data) in requests)
              RequestTile(kind: kind, data: data, showEmployee: true),
          ],
          if (q.isNotEmpty &&
              !_loading &&
              tasks.isEmpty &&
              requests.isEmpty &&
              destinations.isEmpty)
            EmptyState(
              icon: AppIcons.search,
              title: 'Ничего не найдено',
              message:
                  'По запросу «${_controller.text.trim()}» нет задач, заявок или разделов.',
            ),
          if (destinations.isNotEmpty) ...[
            SectionHeader(
              'Разделы',
              topGap: tasks.isEmpty && requests.isEmpty ? 4 : 20,
            ),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Divided(
                children: [
                  for (final (label, icon, page) in destinations)
                    Pressable(
                      onTap: () => pushPage(context, page()),
                      scale: 0.99,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            IconBadge(icon: icon, size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(label, style: AppText.bodyStrong),
                            ),
                            const Icon(
                              AppIcons.chevronRight,
                              size: 16,
                              color: AppColors.ink4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
