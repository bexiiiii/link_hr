import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/premium.dart';
import '../../core/api.dart';
import '../../core/app_language.dart';
import '../../core/fmt.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/checklists.dart';
import '../../data/hr.dart';
import '../../data/notices.dart';
import '../../data/score.dart';
import '../../data/tasks.dart';
import '../../data/timesheet.dart';
import '../achievements/achievements_screens.dart';
import '../employees/team_attendance_screen.dart';
import '../notices/notices_screens.dart';
import '../shell.dart';
import '../checklists/checklists_screens.dart';
import '../tasks/task_sheet.dart';
import 'checkin_card.dart';
import 'summary_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _session = Session.instance;
  bool _loading = true;
  Object? _error;

  List<MonthSheet> _sheets = [];
  List<TaskItem> _tasks = [];
  List<ChecklistRun> _today = [];
  Json? _lastLog;
  List<Notice> _unread = [];
  Map<String, PersonInfo> _people = {};
  List<Achievement> _achievements = [];
  List<Json> _teamToday = [];
  final Set<String> _shownNotices = {};
  bool _popupOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
    _session.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    _session.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final me = _session.userId;
    try {
      final today = await Checklists.today().catchError(
        (_) => <ChecklistRun>[],
      );
      final r = await Future.wait<Object?>([
        MonthSheet.loadRange(
          DateTime(now.year, 1),
          DateTime(now.year, now.month),
        ),
        Tasks.list().then<Object?>((v) => v).catchError((_) => <TaskItem>[]),
        Checklists.runs(
          from: DateTime(now.year, 1, 1),
          to: now,
          user: me,
        ).then<Object?>((v) => v).catchError((_) => <ChecklistRun>[]),
        Hr.checkins(
          limit: 3,
        ).then<Object?>((v) => v).catchError((_) => <Json>[]),
        Notices.mine(
          unreadOnly: true,
        ).then<Object?>((v) => v).catchError((_) => <Notice>[]),
        People.byUser(),
        Hr.teamAttendanceForDay(
          now,
        ).then<Object?>((v) => v).catchError((_) => <Json>[]),
      ]);
      if (!mounted) return;
      final sheets = r[0] as List<MonthSheet>;
      final tasks = r[1] as List<TaskItem>;
      final runs = r[2] as List<ChecklistRun>;
      setState(() {
        _sheets = sheets;
        _tasks = tasks;
        _today = today;
        _lastLog = (r[3] as List<Json>).firstOrNull;
        _unread = r[4] as List<Notice>;
        _people = r[5] as Map<String, PersonInfo>;
        _teamToday = r[6] as List<Json>;
        _achievements = Achievements.compute(
          sheets: sheets,
          tasks: tasks,
          runs: runs,
          me: me,
        );
        _loading = false;
        _error = null;
      });
      _popups();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _popups() async {
    if (_popupOpen || !mounted) return;
    _popupOpen = true;
    try {
      final notice = _unread
          .where((n) => !_shownNotices.contains(n.name))
          .firstOrNull;
      if (notice != null) {
        _shownNotices.add(notice.name);
        await showNoticeDialog(context, notice, _people);
      }
      final seen = await Achievements.seen();
      final fresh = _achievements
          .where((a) => a.unlocked && !seen.contains(a.id))
          .toList();
      if (fresh.isNotEmpty && mounted) {
        await Achievements.markSeen(fresh.map((a) => a.id));
        if (mounted) await showAchievementDialog(context, fresh.first);
      }
    } finally {
      _popupOpen = false;
    }
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = _sheets.lastOrNull;
    final todayRecord = current?.days
        .where((d) => d.date == Fmt.dateOnly(now))
        .firstOrNull;
    final lastTime = Fmt.parse(_lastLog?['time']);
    final lastToday =
        lastTime != null && Fmt.dateOnly(lastTime) == Fmt.dateOnly(now);
    final onShift = lastToday && _lastLog?['log_type'] == 'IN';
    final finished = lastToday && _lastLog?['log_type'] == 'OUT';
    final canCheckin = _session.checkinAllowed;
    final tasks = _session.hasFeature('tasks')
        ? (_tasks
              .where(
                (t) =>
                    t.allocatedTo == _session.userId &&
                    t.status == TaskStatus.inProgress,
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)),
            ))
        : <TaskItem>[];
    final runs = _session.hasFeature('checklists') ? _today : <ChecklistRun>[];
    final upcoming = <(IconData, String, String, VoidCallback)>[
      for (final r in runs.take(2))
        (
          AppIcons.checkmarkSquare,
          r.meta.title,
          r.closed ? 'Выполнено' : r.meta.window,
          () => pushPage(context, ChecklistRunScreen(name: r.name)),
        ),
      for (final t in tasks.take(2 - runs.take(2).length))
        (
          t.hasVoice ? AppIcons.mic : AppIcons.docText,
          t.title,
          t.overdue
              ? 'Просрочено'
              : (t.due == null ? t.stage.label : 'До ${Fmt.long(t.due)}'),
          () => showTaskSheet(context, t, _people),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: _error != null && _sheets.isEmpty
            ? PageScroll(
                onRefresh: _load,
                children: [ErrorState(error: _error!, onRetry: _load)],
              )
            : PageScroll(
                onRefresh: _load,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  const PlanBanner(),
                  _Header(
                    dateLine: Fmt.todayLine(now),
                    greeting: '${_greeting(now)}, ${_session.firstName}',
                    unread: _unread.length,
                  ),
                  const SizedBox(height: 20),
                  const Text('Сегодня', style: AppText.display),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Skeleton(height: 76, radius: AppRadius.card)
                  else
                    ClockCard(
                      arrived: todayRecord?.firstIn,
                      left: finished ? lastTime : null,
                      actionLabel: !canCheckin
                          ? null
                          : (onShift
                                ? 'Уйти'
                                : (finished
                                      ? 'Снова на работу'
                                      : 'Отметиться')),
                      onAction: () =>
                          showCheckinSheet(context, onShift ? 'OUT' : 'IN'),
                    ),
                  if (_session.isHr) ...[
                    const SizedBox(height: 12),
                    _HrTodayCard(
                      rows: _teamToday,
                      onTap: () =>
                          pushPage(context, const TeamAttendanceScreen()),
                    ),
                  ],
                  SummarySection(
                    title: 'Ближайшие задачи',
                    onSeeAll: _session.hasFeature('tasks')
                        ? () =>
                              ShellScope.maybeOf(context)?.goTo(ShellTab.tasks)
                        : null,
                  ),
                  if (_loading)
                    const SkeletonCards(count: 1, height: 118)
                  else if (upcoming.isEmpty)
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.checkmarkSeal,
                            color: AppColors.blue,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'На сегодня задач нет',
                              style: AppText.body.copyWith(
                                color: AppColors.ink2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Divided(
                        children: [
                          for (final item in upcoming)
                            _UpcomingRow(
                              icon: item.$1,
                              title: item.$2,
                              subtitle: item.$3,
                              onTap: item.$4,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// The HR landing block is intentionally one calm, useful overview rather
/// than an extra list of technical dashboard tiles. Values come from the same
/// permission-protected feed as the team attendance screen.
class _HrTodayCard extends StatelessWidget {
  const _HrTodayCard({required this.rows, required this.onTap});

  final List<Json> rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final present = rows.where((row) => row['status'] == 'present').length;
    final left = rows.where((row) => row['status'] == 'left').length;
    final absent = rows.where((row) => row['status'] == 'absent').length;
    return Pressable(
      onTap: onTap,
      semanticLabel: tx('Команда сегодня', 'Команда бүгін'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tx('Команда сегодня', 'Команда бүгін'),
                style: AppText.heading,
              ),
              const Spacer(),
              Text(
                tx('Открыть', 'Ашу'),
                style: AppText.label.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                AppIcons.chevronRight,
                size: 16,
                color: AppColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HrMetric(
                  value: rows.length,
                  label: tx('Всего', 'Барлығы'),
                  icon: AppIcons.person3,
                  background: AppColors.violetSoft,
                  foreground: AppColors.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HrMetric(
                  value: present,
                  label: tx('На работе', 'Жұмыста'),
                  icon: AppIcons.building2Fill,
                  background: AppColors.successSoft,
                  foreground: AppColors.successDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HrMetric(
                  value: left,
                  label: tx('Ушли', 'Кетті'),
                  icon: AppIcons.arrowUpRight,
                  background: AppColors.amberSoft,
                  foreground: AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HrMetric(
                  value: absent,
                  label: tx('Нет отметки', 'Белгі жоқ'),
                  icon: AppIcons.personCropCircleBadgeExclam,
                  background: AppColors.redSoft,
                  foreground: AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrMetric extends StatelessWidget {
  const _HrMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.tile),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: foreground),
        const SizedBox(height: 12),
        Text('$value', style: AppText.title.copyWith(color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption.copyWith(color: AppColors.ink2)),
      ],
    ),
  );
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.chevronRight, size: 18, color: AppColors.ink4),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dateLine,
    required this.greeting,
    required this.unread,
  });

  final String dateLine;
  final String greeting;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLine,
                style: AppText.label.copyWith(color: AppColors.ink3),
              ),
              const SizedBox(height: 2),
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong,
              ),
            ],
          ),
        ),
        CircleButton(
          icon: AppIcons.bell,
          label: unread > 0 ? 'Оповещения, новых: $unread' : 'Оповещения',
          badge: unread > 0,
          size: 48,
          iconSize: 20,
          onTap: () => pushPage(context, const NoticesScreen()),
        ),
        const SizedBox(width: 10),
        Pressable(
          onTap: () => ShellScope.maybeOf(context)?.goTo(ShellTab.profile),
          scale: 0.92,
          semanticLabel: 'Профиль',
          child: AppAvatar(
            name: s.fullName,
            imageUrl: s.image,
            size: 48,
            border: false,
          ),
        ),
      ],
    );
  }
}
