import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/fmt.dart';
import '../../core/media.dart';
import '../../core/motion.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/tasks.dart';
import 'task_card.dart';
import 'task_form_screen.dart';
import 'task_sheet.dart';

enum BoardColumn { week, today, backlog, done }

extension on BoardColumn {
  String get title => switch (this) {
        BoardColumn.week => 'Неделя',
        BoardColumn.today => 'Сегодня',
        BoardColumn.backlog => 'Бэклог',
        BoardColumn.done => 'Выполнено',
      };
}

BoardColumn columnOf(TaskItem t) {
  if (t.status == TaskStatus.completed) return BoardColumn.done;
  final due = t.due;
  if (due == null) return BoardColumn.backlog;
  final days = Fmt.dateOnly(due).difference(Fmt.dateOnly(DateTime.now())).inDays;
  if (days <= 0) return BoardColumn.today;
  if (days <= 7) return BoardColumn.week;
  return BoardColumn.backlog;
}

/// "Доска": four quadrants of people bubbles, one bubble per task.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  List<TaskItem> _tasks = [];
  Map<String, PersonInfo> _people = {};
  bool _loading = true;
  Object? _error;
  bool _mine = true;
  String? _person;

  final _recorder = VoiceRecorder();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    Session.instance.dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    Session.instance.dataVersion.removeListener(_load);
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([Tasks.list(), People.byUser()]);
      if (!mounted) return;
      setState(() {
        _tasks = (results[0] as List<TaskItem>).where((t) => t.status != TaskStatus.onHold).toList();
        _people = results[1] as Map<String, PersonInfo>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  String _counterpart(TaskItem t) {
    final me = Session.instance.userId;
    if (_mine) return t.owner.isNotEmpty && t.owner != me ? t.owner : (t.reviewer.isNotEmpty ? t.reviewer : t.allocatedTo);
    return t.allocatedTo;
  }

  List<TaskItem> get _visible {
    final me = Session.instance.userId;
    return _tasks.where((t) {
      final relevant = _mine ? t.allocatedTo == me : (t.owner == me || t.assignedBy == me) && t.allocatedTo != me;
      if (!relevant) return false;
      if (t.status == TaskStatus.completed &&
          t.modified != null &&
          DateTime.now().difference(t.modified!).inDays > 14) {
        return false;
      }
      return _person == null || _counterpart(t) == _person;
    }).toList();
  }

  Future<void> _startVoice() async {
    HapticFeedback.mediumImpact();
    final ok = await _recorder.start();
    if (!ok) {
      if (mounted) showToast(context, 'Разрешите доступ к микрофону в настройках iPhone', error: true);
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _sendVoice() async {
    _ticker?.cancel();
    final clip = await _recorder.stop();
    setState(() {});
    if (!mounted) return;
    if (clip == null) {
      showToast(context, 'Запись слишком короткая', error: true);
      return;
    }
    await pushPage(context, TaskFormScreen(voice: clip));
  }

  Future<void> _cancelVoice() async {
    _ticker?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() {});
  }

  Future<void> _moveTask(TaskItem t) async {
    final picked = await pickAction(context, title: t.title, actions: const [
      SheetAction('today', 'Перенести на сегодня'),
      SheetAction('week', 'Перенести на эту неделю'),
      SheetAction('backlog', 'Убрать в бэклог'),
    ]);
    if (picked == null) return;
    final due = switch (picked) {
      'today' => DateTime.now(),
      'week' => endOfWeek(DateTime.now()),
      _ => null,
    };
    try {
      await Tasks.setDue(t.name, due);
      Session.instance.notifyDataChanged();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final columns = {for (final c in BoardColumn.values) c: <TaskItem>[]};
    for (final t in visible) {
      columns[columnOf(t)]!.add(t);
    }
    final me = Session.instance.userId;
    final counterparts = <String>{
      for (final t in _tasks.where((t) => _mine ? t.allocatedTo == me : (t.owner == me || t.assignedBy == me) && t.allocatedTo != me))
        _counterpart(t),
    }.toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Доска', style: AppText.title.copyWith(fontSize: 22)),
                    Text(_mine ? 'Назначенные мне' : 'Поставленные мной', style: AppText.label.copyWith(color: AppColors.ink3)),
                  ]),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Мне', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    CupertinoSwitch(
                      value: _mine,
                      activeTrackColor: AppColors.violet,
                      onChanged: (v) => setState(() {
                        _mine = v;
                        _person = null;
                      }),
                    ),
                  ]),
                ),
              ]),
            ),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                children: [
                  for (final (i, id) in counterparts.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Reveal(
                        index: i,
                        scale: true,
                        child: Pressable(
                          onTap: () => setState(() => _person = _person == id ? null : id),
                          scale: 0.9,
                          semanticLabel: 'Фильтр: ${People.resolve(_people, id).name}',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _person == id ? AppColors.violet : Colors.transparent, width: 2),
                            ),
                            child: AppAvatar(
                              name: People.resolve(_people, id).name,
                              imageUrl: People.resolve(_people, id).image,
                              size: 38,
                              border: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(20), child: SkeletonCards(count: 3, height: 140))
                  : _error != null
                      ? PageScroll(onRefresh: _load, children: [ErrorState(error: _error!, onRetry: _load)])
                      : Column(children: [
                          Expanded(
                            child: Row(children: [
                              _quadrant(BoardColumn.week, columns),
                              _quadrant(BoardColumn.today, columns),
                            ]),
                          ),
                          Expanded(
                            child: Row(children: [
                              _quadrant(BoardColumn.backlog, columns),
                              _quadrant(BoardColumn.done, columns),
                            ]),
                          ),
                        ]),
            ),
          ]),
          if (_recorder.recording)
            Positioned(
              left: 20,
              right: 96,
              bottom: 26,
              child: Reveal(
                offset: 20,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Pulse(
                      child: Container(
                          width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 10),
                    Text(clockOf(_recorder.elapsed), style: AppText.number),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: _cancelVoice,
                      child: const Text('Отмена', style: TextStyle(color: AppColors.ink3, fontSize: 15)),
                    ),
                  ]),
                ),
              ),
            ),
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onLongPress: _recorder.recording ? null : _startVoice,
              child: Pressable(
                onTap: _recorder.recording ? _sendVoice : () => pushPage(context, const TaskFormScreen()),
                scale: 0.9,
                semanticLabel: _recorder.recording ? 'Отправить голосовую задачу' : 'Новая задача. Удерживайте, чтобы записать голосом',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutQuart,
                  width: _recorder.recording ? 60 : 54,
                  height: _recorder.recording ? 60 : 54,
                  decoration: const BoxDecoration(
                    color: AppColors.charcoal,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(
                      _recorder.recording ? CupertinoIcons.arrow_up : CupertinoIcons.add,
                      key: ValueKey(_recorder.recording),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _quadrant(BoardColumn column, Map<BoardColumn, List<TaskItem>> columns) {
    final items = columns[column]!;
    final done = column == BoardColumn.done;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: done ? AppColors.green : AppColors.line, width: done ? 1.2 : 1),
        ),
        child: Column(children: [
          SizedBox(
            height: 38,
            child: Row(children: [
              const SizedBox(width: 34),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: Text(column.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle.copyWith(color: done ? AppColors.greenDeep : AppColors.ink2)),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text('${items.length}', style: AppText.caption),
                  ],
                ]),
              ),
              SizedBox(
                width: 34,
                child: done
                    ? IconButton(
                        tooltip: 'Архив выполненных',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(CupertinoIcons.archivebox, color: AppColors.ink2),
                        onPressed: () => pushPage(context, _ArchiveScreen(people: _people)),
                      )
                    : null,
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 40)])
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(6, 2, 6, 90),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 74,
                        mainAxisExtent: 80,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => Reveal(
                        key: ValueKey(items[i].name),
                        index: i,
                        scale: true,
                        child: _Bubble(
                          task: items[i],
                          person: People.resolve(_people, _counterpart(items[i])),
                          onTap: () => showTaskSheet(context, items[i], _people),
                          onLongPress: done ? null : () => _moveTask(items[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.task, required this.person, required this.onTap, this.onLongPress});

  final TaskItem task;
  final PersonInfo person;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ring = switch (task.stage) {
      _ when task.overdue => AppColors.red,
      TaskStage.inWork => AppColors.green,
      TaskStage.review => AppColors.violet,
      _ => Colors.transparent,
    };
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      scale: 0.9,
      semanticLabel: '${task.title}, ${person.name}, ${task.stage.label}',
      child: Column(children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2.5)),
                child: AppAvatar(name: person.name, imageUrl: person.image, size: 46, border: false),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 1.4),
                ),
                child: Icon(
                  task.status == TaskStatus.completed
                      ? CupertinoIcons.checkmark
                      : task.hasVoice
                          ? CupertinoIcons.play_fill
                          : CupertinoIcons.text_bubble,
                  size: 10,
                  color: AppColors.ink,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text(person.shortName,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _ArchiveScreen extends StatefulWidget {
  const _ArchiveScreen({required this.people});

  final Map<String, PersonInfo> people;

  @override
  State<_ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<_ArchiveScreen> {
  List<TaskItem>? _tasks;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = Session.instance.userId;
      final all = await Tasks.list();
      if (mounted) {
        setState(() => _tasks = all
            .where((t) => t.status != TaskStatus.inProgress && (t.allocatedTo == me || t.owner == me || t.assignedBy == me))
            .toList());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = {for (final e in widget.people.entries) e.key: (e.value.name, e.value.image)};
    return AppPage(
      header: const ScreenHeader(title: 'Архив задач'),
      body: PageScroll(onRefresh: _load, children: [
        if (_error != null)
          ErrorState(error: _error!, onRetry: _load)
        else if (_tasks == null)
          const SkeletonCards(count: 4, height: 120)
        else if (_tasks!.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.archivebox,
            title: 'Архив пуст',
            message: 'Выполненные и отложенные задачи будут храниться здесь.',
          )
        else
          for (final (i, t) in _tasks!.indexed)
            Reveal(
              index: i,
              child: TaskCard(task: t, directory: directory, onTap: () => showTaskSheet(context, t, widget.people)),
            ),
      ]),
    );
  }
}
