import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/premium.dart';
import '../../core/api.dart';
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
import '../notices/notices_screens.dart';
import '../shell.dart';
import '../attendance/checkin_history_screen.dart';
import '../checklists/checklists_screens.dart';
import '../requests/requests_screen.dart';
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
  List<Json> _shifts = [];
  List<Notice> _unread = [];
  Map<String, PersonInfo> _people = {};
  List<Achievement> _achievements = [];
  List<Json> _recent = [];
  (int, int, int)? _requests;
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
        Hr.shiftAssignments()
            .then<Object?>((v) => v)
            .catchError((_) => <Json>[]),
        Notices.mine(
          unreadOnly: true,
        ).then<Object?>((v) => v).catchError((_) => <Notice>[]),
        People.byUser(),
      ]);
      if (!mounted) return;
      final sheets = r[0] as List<MonthSheet>;
      final tasks = r[1] as List<TaskItem>;
      final runs = r[2] as List<ChecklistRun>;
      setState(() {
        _sheets = sheets;
        _tasks = tasks;
        _today = today;
        _recent = r[3] as List<Json>;
        _lastLog = _recent.firstOrNull;
        _shifts = r[4] as List<Json>;
        _unread = r[5] as List<Notice>;
        _people = r[6] as Map<String, PersonInfo>;
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
      _loadRequests();
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
      final fresh =
          _achievements
              .where((a) => a.unlocked && !seen.contains(a.id))
              .toList()
            ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
      if (fresh.isNotEmpty && mounted) {
        await Achievements.markSeen(fresh.map((a) => a.id));
        if (mounted) await showAchievementDialog(context, fresh.first);
      }
    } finally {
      _popupOpen = false;
    }
  }

  /// My requests of every kind: leave, shift, attendance correction, expenses.
  Future<void> _loadRequests() async {
    final lists = await Future.wait([
      Hr.leaves(limit: 200).catchError((_) => <Json>[]),
      Hr.shiftRequests(limit: 200).catchError((_) => <Json>[]),
      Hr.attendanceRequests(limit: 200).catchError((_) => <Json>[]),
      Hr.expenseClaims(limit: 200).catchError((_) => <Json>[]),
    ]);
    var total = 0, approved = 0, declined = 0;
    for (final row in lists.expand((l) => l)) {
      total++;
      final status = (row['approval_status'] ?? row['status'] ?? '').toString();
      final docstatus = int.tryParse('${row['docstatus'] ?? 0}') ?? 0;
      if (status == 'Approved' || (status.isEmpty && docstatus == 1))
        approved++;
      if (status == 'Rejected' || docstatus == 2) declined++;
    }
    if (mounted) setState(() => _requests = (total, approved, declined));
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
    final workStart = MonthSheet.workStartOf(_shifts);
    final onTime = current == null
        ? 0
        : current.count(DayMark.onTime) + current.count(DayMark.remote);
    final late = current?.count(DayMark.late) ?? 0;
    final onTimePct = onTime + late == 0
        ? null
        : (onTime * 100 / (onTime + late)).round();

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
    final cards = <Widget>[
      for (final r in runs.take(4))
        SummaryTaskCard(
          icon: AppIcons.checkmarkSquare,
          title: r.meta.title,
          pill: r.closed ? 'Выполнено' : 'Чеклист',
          pillTone: r.closed ? Tone.green : Tone.neutral,
          subtitle: r.meta.window,
          progress: r.items.isEmpty ? null : r.doneCount / r.items.length,
          onTap: () => pushPage(context, ChecklistRunScreen(name: r.name)),
        ),
      for (final t in tasks.take(6 - runs.take(4).length))
        SummaryTaskCard(
          icon: t.hasVoice ? AppIcons.mic : AppIcons.docText,
          title: t.title,
          pill: t.overdue ? 'Просрочено' : t.stage.label,
          pillTone: t.overdue
              ? Tone.red
              : (t.stage == TaskStage.review ? Tone.violet : Tone.amber),
          subtitle: t.due == null ? null : 'До ${Fmt.long(t.due)}',
          progress: t.subtaskTotal == 0 ? null : t.subtaskDone / t.subtaskTotal,
          onTap: () => showTaskSheet(context, t, _people),
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
                  const SizedBox(height: 18),
                  const Text('Сводка\nза сегодня', style: AppText.display),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Skeleton(height: 76, radius: AppRadius.card)
                  else
                    ClockCard(
                      arrived: todayRecord?.firstIn,
                      left: finished ? lastTime : null,
                      actionLabel: !canCheckin
                          ? null
                          : onShift
                          ? 'Уйти'
                          : finished
                          ? 'Снова на работу'
                          : 'Отметиться',
                      onAction: () =>
                          showCheckinSheet(context, onShift ? 'OUT' : 'IN'),
                    ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const SkeletonCards(count: 2, height: 84)
                  else
                    TileGrid(
                      children: [
                        StatTile(
                          value: todayRecord?.firstIn == null
                              ? '– –'
                              : Fmt.time(todayRecord!.firstIn),
                          label:
                              todayRecord?.lateMinutes != null &&
                                  todayRecord!.lateMinutes > 0
                              ? 'Пришёл · опоздание ${formatLate(todayRecord.lateMinutes)}'
                              : 'Пришёл',
                          icon: AppIcons.arrowDownLeftSquare,
                          muted: todayRecord?.firstIn == null,
                        ),
                        StatTile(
                          value: finished ? Fmt.time(lastTime) : '– –',
                          label: onShift ? 'На работе' : 'Ушёл',
                          icon: AppIcons.arrowUpRightSquare,
                          muted: !finished,
                        ),
                        StatTile(
                          value: onTimePct == null ? '– –' : '$onTimePct%',
                          label: 'Вовремя в этом месяце',
                          icon: AppIcons.checkmarkSquare,
                          muted: onTimePct == null,
                        ),
                        StatTile(
                          value: '${current?.present ?? 0}',
                          unit: Fmt.plural(
                            current?.present ?? 0,
                            'день',
                            'дня',
                            'дней',
                          ),
                          label: 'На работе в этом месяце',
                          icon: AppIcons.calendar,
                        ),
                      ],
                    ),
                  SummarySection(
                    title: 'Статус заявок',
                    onSeeAll: () => pushPage(context, const RequestsScreen()),
                  ),
                  RequestCounters(
                    loading: _requests == null,
                    total: _requests?.$1 ?? 0,
                    approved: _requests?.$2 ?? 0,
                    declined: _requests?.$3 ?? 0,
                    onTap: () => pushPage(context, const RequestsScreen()),
                  ),
                  SummarySection(
                    title: 'Задачи',
                    onSeeAll: _session.hasFeature('tasks')
                        ? () =>
                              ShellScope.maybeOf(context)?.goTo(ShellTab.tasks)
                        : null,
                  ),
                  if (_loading)
                    const SkeletonCards(count: 2, height: 120)
                  else if (cards.isEmpty)
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.checkmarkSeal,
                            color: AppColors.green,
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
                    TileGrid(children: cards),
                  SummarySection(
                    title: 'Последние отметки',
                    onSeeAll: () =>
                        pushPage(context, const CheckinHistoryScreen()),
                  ),
                  if (_loading)
                    const SkeletonCards(count: 1, height: 140)
                  else if (_recent.isEmpty)
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Text(
                        'Отметок пока нет. Нажмите «Отметиться», когда придёте на работу.',
                        style: AppText.body.copyWith(color: AppColors.ink2),
                      ),
                    )
                  else
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: Divided(
                        children: [
                          for (final l in _recent)
                            CheckinLogTile(log: l, workStart: workStart),
                        ],
                      ),
                    ),
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
