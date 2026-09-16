import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/premium.dart';
import '../../core/api.dart';
import '../../core/fmt.dart';
import '../../core/kit.dart';
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
import '../profile/profile_screen.dart';
import '../shell.dart';
import '../timesheet/timesheet_view.dart';
import 'home_panels.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _session = Session.instance;
  int _tab = 0;
  bool _loading = true;
  Object? _error;

  List<MonthSheet> _sheets = [];
  List<TaskItem> _tasks = [];
  List<ChecklistRun> _today = [];
  List<ChecklistRun> _yearRuns = [];
  Json? _lastLog;
  List<Json> _shifts = [];
  List<Notice> _unread = [];
  Map<String, PersonInfo> _people = {};
  Score? _score;
  List<Achievement> _achievements = [];
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
      final today = await Checklists.today().catchError((_) => <ChecklistRun>[]);
      final r = await Future.wait<Object?>([
        MonthSheet.loadRange(DateTime(now.year, 1), DateTime(now.year, now.month)),
        Tasks.list().then<Object?>((v) => v).catchError((_) => <TaskItem>[]),
        Checklists.runs(from: DateTime(now.year, 1, 1), to: now, user: me).then<Object?>((v) => v).catchError((_) => <ChecklistRun>[]),
        Hr.checkins(limit: 1).then<Object?>((v) => v).catchError((_) => <Json>[]),
        Hr.shiftAssignments().then<Object?>((v) => v).catchError((_) => <Json>[]),
        Notices.mine(unreadOnly: true).then<Object?>((v) => v).catchError((_) => <Notice>[]),
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
        _yearRuns = runs;
        _lastLog = (r[3] as List<Json>).firstOrNull;
        _shifts = r[4] as List<Json>;
        _unread = r[5] as List<Notice>;
        _people = r[6] as Map<String, PersonInfo>;
        _score = Score.compute(sheet: sheets.last, tasks: tasks, runs: runs, me: me);
        _achievements = Achievements.compute(sheets: sheets, tasks: tasks, runs: runs, me: me);
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
      final notice = _unread.where((n) => !_shownNotices.contains(n.name)).firstOrNull;
      if (notice != null) {
        _shownNotices.add(notice.name);
        await showNoticeDialog(context, notice, _people);
      }
      final seen = await Achievements.seen();
      final fresh = _achievements.where((a) => a.unlocked && !seen.contains(a.id)).toList()
        ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
      if (fresh.isNotEmpty && mounted) {
        await Achievements.markSeen(fresh.map((a) => a.id));
        if (mounted) await showAchievementDialog(context, fresh.first);
      }
    } finally {
      _popupOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _sheets.lastOrNull;
    final todayRecord = current?.days.where((d) => d.date == Fmt.dateOnly(DateTime.now())).firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PlanBanner(),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(children: [
              _Header(score: Session.instance.hasFeature('points') ? _score?.value : null, unread: _unread.length),
              const SizedBox(height: 16),
              KpiStrip(
                loading: current == null,
                items: [
                  ('Присутствие', '${current?.present ?? 0}'),
                  ('Отсутствие', '${current?.absent ?? 0}'),
                  ('Опоздание', (current?.lateMinutes ?? 0) < 60 ? '${current?.lateMinutes ?? 0} мин' : '${((current!.lateMinutes) / 60).toStringAsFixed(1)} ч'),
                ],
              ),
              UnderlineTabs(
                labels: const ['Link Time', 'Статистика', 'Табель', 'Баллы'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ]),
          ),
          Expanded(
            child: _error != null && _sheets.isEmpty
                ? PageScroll(onRefresh: _load, children: [ErrorState(error: _error!, onRetry: _load)])
                : _loading
                    ? PageScroll(children: const [SizedBox(height: 12), SkeletonCards(count: 3, height: 90)])
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutQuart,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_tab),
                          child: switch (_tab) {
                            0 => TimePanel(
                                lastLog: _lastLog,
                                today: todayRecord,
                                workStart: MonthSheet.workStartOf(_shifts),
                                workEnd: MonthSheet.workEndOf(_shifts),
                                runs: _today,
                                tasks: _tasks,
                                people: _people,
                                onRefresh: _load,
                              ),
                            1 => StatsPanel(yearSheets: _sheets, tasks: _tasks, runs: _yearRuns, onRefresh: _load),
                            2 => TimesheetGridPanel(yearSheets: _sheets, onRefresh: _load),
                            _ => Session.instance.hasFeature('points')
                                ? PointsPanel(
                                    score: _score,
                                    achievements: _achievements,
                                    month: current?.month ?? DateTime.now(),
                                    onRefresh: _load,
                                  )
                                : PageScroll(children: const [PremiumNotice(title: 'Баллы')]),
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.score, required this.unread});

  final int? score;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    return Row(children: [
      Pressable(
        onTap: () => pushPage(context, const ProfileScreen()),
        scale: 0.92,
        semanticLabel: 'Профиль',
        child: AppAvatar(name: s.fullName, imageUrl: s.image, size: 54, border: false),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
          Text.rich(
            TextSpan(children: [
              if (s.department.isNotEmpty)
                TextSpan(text: s.department, style: AppText.label.copyWith(color: AppColors.ink2, fontWeight: FontWeight.w600)),
              if (s.department.isNotEmpty && s.designation.isNotEmpty) const TextSpan(text: ' | '),
              TextSpan(text: s.designation.isNotEmpty ? s.designation : (s.department.isEmpty ? 'Сотрудник' : '')),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(color: AppColors.ink3),
          ),
          const SizedBox(height: 8),
          _PointsBar(score: score),
        ]),
      ),
      const SizedBox(width: 12),
      Align(
        alignment: Alignment.topCenter,
        child: CircleButton(
          icon: CupertinoIcons.bell_fill,
          label: unread > 0 ? 'Оповещения, новых: $unread' : 'Оповещения',
          badge: unread > 0,
          background: AppColors.charcoal,
          foreground: Colors.white,
          size: 36,
          iconSize: 16,
          onTap: () => ShellScope.maybeOf(context)?.goTo(ShellTab.inbox),
        ),
      ),
    ]);
  }
}

class _PointsBar extends StatelessWidget {
  const _PointsBar({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: score == null ? 'Баллы загружаются' : 'Баллы: $score из 100',
      child: LayoutBuilder(builder: (context, c) {
        return Container(
          height: 14,
          decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(7)),
          child: Stack(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (score ?? 0) / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
              builder: (_, v, _) => Container(
                width: c.maxWidth * v,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(colors: [Color(0xFFE9D24A), Color(0xFF8BC34A), AppColors.green]),
                ),
              ),
            ),
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.circle_fill, size: 7, color: (score ?? 0) >= 55 ? Colors.white : AppColors.ink2),
                const SizedBox(width: 4),
                Text(score == null ? '—' : '$score',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (score ?? 0) >= 55 ? Colors.white : AppColors.ink,
                    )),
              ]),
            ),
          ]),
        );
      }),
    );
  }
}
