import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

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
      backgroundColor: AppColors.hero,
      body: SafeArea(
        bottom: false,
        child: _error != null && _sheets.isEmpty
            ? PageScroll(
                onRefresh: _load,
                children: [ErrorState(error: _error!, onRetry: _load)],
              )
            : PageScroll(
                onRefresh: _load,
                padding: EdgeInsets.zero,
                children: [
                  _HomeHero(
                    dateLine: Fmt.todayLine(now),
                    greeting: '${_greeting(now)}, ${_session.firstName}',
                    unread: _unread.length,
                    now: now,
                    onShift: onShift,
                    finished: finished,
                    arrived: todayRecord?.firstIn,
                    left: finished ? lastTime : null,
                    team: _teamToday,
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 128),
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _session.isHr
                                    ? tx(
                                        'Посещаемость сегодня',
                                        'Бүгінгі қатысу',
                                      )
                                    : tx('Рабочая неделя', 'Жұмыс аптасы'),
                                style: AppText.heading,
                              ),
                            ),
                            if (_session.isHr)
                              Pressable(
                                onTap: () => pushPage(
                                  context,
                                  const TeamAttendanceScreen(),
                                ),
                                child: Text(
                                  tx('Все отчёты ›', 'Барлық есептер ›'),
                                  style: AppText.label.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _HomeBars(
                          team: _teamToday,
                          sheet: current,
                          isHr: _session.isHr,
                        ),
                        const SizedBox(height: 18),
                        if (_loading)
                          const Skeleton(height: 92, radius: AppRadius.card)
                        else
                          ClockCard(
                            arrived: todayRecord?.firstIn,
                            left: finished ? lastTime : null,
                            actionLabel: !canCheckin
                                ? null
                                : (onShift
                                      ? tx('Завершить день', 'Күнді аяқтау')
                                      : (finished
                                            ? tx('Вернуться', 'Қайта оралу')
                                            : tx(
                                                'Начать день',
                                                'Күнді бастау',
                                              ))),
                            onAction: () => showCheckinSheet(
                              context,
                              onShift ? 'OUT' : 'IN',
                            ),
                          ),
                        SummarySection(
                          title: tx('Ближайшие задачи', 'Жақын тапсырмалар'),
                          onSeeAll: _session.hasFeature('tasks')
                              ? () => ShellScope.maybeOf(
                                  context,
                                )?.goTo(ShellTab.tasks)
                              : null,
                        ),
                        if (_loading)
                          const SkeletonCards(count: 1, height: 118)
                        else if (upcoming.isEmpty)
                          SurfaceCard(
                            child: Row(
                              children: [
                                const Icon(
                                  AppIcons.checkmarkSeal,
                                  color: AppColors.greenDeep,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tx(
                                    'На сегодня задач нет',
                                    'Бүгін тапсырма жоқ',
                                  ),
                                  style: AppText.body,
                                ),
                              ],
                            ),
                          )
                        else
                          SurfaceCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                ],
              ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.dateLine,
    required this.greeting,
    required this.unread,
    required this.now,
    required this.onShift,
    required this.finished,
    required this.arrived,
    required this.left,
    required this.team,
  });

  final String dateLine;
  final String greeting;
  final int unread;
  final DateTime now;
  final bool onShift;
  final bool finished;
  final DateTime? arrived;
  final DateTime? left;
  final List<Json> team;

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    final present = team.where((row) => row['status'] == 'present').length;
    final leftCount = team.where((row) => row['status'] == 'left').length;
    final missing = team.where((row) => row['status'] == 'absent').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.hero, AppColors.hero2],
        ),
      ),
      child: Column(
        children: [
          _Header(
            dateLine: dateLine,
            greeting: greeting,
            unread: unread,
            light: true,
          ),
          const SizedBox(height: 30),
          Text(
            session.isHr
                ? tx('Сейчас на работе', 'Қазір жұмыста')
                : onShift
                ? tx('Рабочий день идёт', 'Жұмыс күні жүріп жатыр')
                : finished
                ? tx('Рабочий день завершён', 'Жұмыс күні аяқталды')
                : tx('Сегодня', 'Бүгін'),
            style: AppText.label.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            session.isHr ? '$present' : Fmt.time(now),
            style: AppText.display.copyWith(
              color: Colors.white,
              fontSize: 48,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: session.isHr
                ? [
                    Expanded(
                      child: _HeroStat(
                        label: tx('Всего', 'Барлығы'),
                        value: '${team.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroStat(
                        label: tx('Ушли', 'Кетті'),
                        value: '$leftCount',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroStat(
                        label: tx('Без отметки', 'Белгі жоқ'),
                        value: '$missing',
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: _HeroStat(
                        label: tx('Приход', 'Келу'),
                        value: arrived == null ? '—' : Fmt.time(arrived),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroStat(
                        label: tx('Уход', 'Кету'),
                        value: left == null ? '—' : Fmt.time(left),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          style: AppText.caption.copyWith(color: Colors.white60),
        ),
        const SizedBox(height: 8),
        Text(value, style: AppText.heading.copyWith(color: Colors.white)),
      ],
    ),
  );
}

class _HomeBars extends StatelessWidget {
  const _HomeBars({
    required this.team,
    required this.sheet,
    required this.isHr,
  });
  final List<Json> team;
  final MonthSheet? sheet;
  final bool isHr;

  @override
  Widget build(BuildContext context) {
    final today = Fmt.dateOnly(DateTime.now());
    final values = isHr
        ? <(String, double, Color)>[
            (
              tx('В офисе', 'Кеңседе'),
              team.where((r) => r['status'] == 'present').length.toDouble(),
              AppColors.green,
            ),
            (
              tx('Ушли', 'Кетті'),
              team.where((r) => r['status'] == 'left').length.toDouble(),
              AppColors.amber,
            ),
            (
              tx('Нет', 'Жоқ'),
              team.where((r) => r['status'] == 'absent').length.toDouble(),
              AppColors.red,
            ),
          ]
        : <(String, double, Color)>[
            for (var i = 6; i >= 0; i--)
              () {
                final day = today.subtract(Duration(days: i));
                final record = sheet?.days
                    .where((r) => r.date == day)
                    .firstOrNull;
                return (Fmt.dayMonth(day), record?.hours ?? 0, AppColors.green);
              }(),
          ];
    final maxValue = values.fold<double>(
      1,
      (max, item) => item.$2 > max ? item.$2 : max,
    );
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: SizedBox(
        height: 146,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.decimal(item.$2),
                        style: AppText.caption.copyWith(color: AppColors.ink2),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        height: 18 + 76 * (item.$2 / maxValue),
                        decoration: BoxDecoration(
                          color: item.$2 == maxValue
                              ? item.$3
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    this.light = false,
  });

  final String dateLine;
  final String greeting;
  final int unread;
  final bool light;

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
                style: AppText.label.copyWith(
                  color: light ? Colors.white60 : AppColors.ink3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(
                  color: light ? Colors.white : AppColors.ink,
                ),
                // The dark analytical hero carries the identity of the home.
                // Other contexts keep the standard ink colour.
                textAlign: TextAlign.left,
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
          background: light
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.surface,
          foreground: light ? Colors.white : AppColors.ink,
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
