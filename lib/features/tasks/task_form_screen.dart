import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/api.dart';
import '../../core/files.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/media.dart';
import '../../core/motion.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/tasks.dart';

enum DueMode {
  today('Сегодня'),
  week('Неделя'),
  backlog('Бэклог'),
  other('Другое');

  const DueMode(this.label);

  final String label;
}

DateTime endOfWeek(DateTime now) {
  final d = Fmt.dateOnly(now);
  final toSunday = DateTime.sunday - d.weekday;
  return d.add(Duration(days: toSunday == 0 ? 7 : toSunday));
}

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task, this.initialDue, this.voice});

  final TaskItem? task;
  final DateTime? initialDue;
  final VoiceClip? voice;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final _text = TextEditingController(
    text: widget.task == null
        ? ''
        : [
            widget.task!.title,
            widget.task!.description,
          ].where((s) => s.isNotEmpty).join('\n'),
  );
  late VoiceClip? _voice = widget.voice;
  Attachment? _remoteVoice;
  final List<PendingFile> _files = [];
  final List<TextEditingController> _subtasks = [];
  late DueMode _mode;
  DateTime? _other;
  late List<String> _executors = widget.task == null
      ? [Session.instance.userId]
      : [widget.task!.allocatedTo];
  late String _reviewer = widget.task?.reviewer ?? '';
  Map<String, PersonInfo> _people = {};
  List<String> _frequent = [];
  bool _busy = false;
  String? _error;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final due = widget.task?.due ?? widget.initialDue;
    final today = Fmt.dateOnly(DateTime.now());
    if (due == null) {
      _mode = widget.task == null ? DueMode.today : DueMode.backlog;
    } else if (!Fmt.dateOnly(due).isAfter(today)) {
      _mode = DueMode.today;
    } else if (!Fmt.dateOnly(due).isAfter(endOfWeek(today)) &&
        widget.initialDue == null) {
      _mode = DueMode.week;
    } else {
      _mode = DueMode.other;
      _other = due;
    }
    _loadSide();
  }

  Future<void> _loadSide() async {
    final people = await People.byUser();
    var frequent = <String>[];
    try {
      frequent = Tasks.frequentPeople(await Tasks.list());
    } catch (_) {}
    Attachment? voice;
    if (widget.task?.hasVoice ?? false) {
      try {
        voice = await Tasks.voiceOf(widget.task!.name);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _people = people;
      _frequent = frequent;
      _remoteVoice = voice;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    for (final c in _subtasks) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? get _due => switch (_mode) {
    DueMode.today => Fmt.dateOnly(DateTime.now()),
    DueMode.week => endOfWeek(DateTime.now()),
    DueMode.backlog => null,
    DueMode.other => _other,
  };

  Future<void> _pickMode(DueMode m) async {
    if (m == DueMode.other) {
      final d = await pickDate(
        context,
        initial: _other ?? DateTime.now().add(const Duration(days: 1)),
        minimum: DateTime.now(),
      );
      if (d == null) return;
      setState(() {
        _mode = m;
        _other = d;
      });
    } else {
      setState(() => _mode = m);
    }
  }

  Future<void> _pickExecutors() async {
    final picked = await pickPeople(
      context,
      title: 'Исполнители',
      multi: !_editing,
      selected: _executors,
      frequent: _frequent,
    );
    if (picked != null && picked.isNotEmpty)
      setState(() => _executors = picked);
  }

  Future<void> _pickReviewer() async {
    final picked = await pickPeople(
      context,
      title: 'Проверяющий',
      multi: false,
      selected: [if (_reviewer.isNotEmpty) _reviewer],
      frequent: _frequent,
    );
    if (picked != null && picked.isNotEmpty)
      setState(() => _reviewer = picked.first);
  }

  Future<void> _attach() async {
    final f = await pickAttachment(context);
    if (f != null) setState(() => _files.add(f));
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty && _voice == null && _remoteVoice == null) {
      setState(() => _error = 'Опишите задачу текстом или запишите голосом');
      return;
    }
    if (_mode == DueMode.other && _other == null) {
      setState(() => _error = 'Выберите дату завершения');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        final t = widget.task!;
        final lines = text.split('\n');
        await Tasks.update(
          t.name,
          title: lines.first.isEmpty ? t.title : lines.first,
          description: lines.skip(1).join('\n'),
          due: _due,
          priority: t.priority,
          allocatedTo: _executors.first,
          reviewer: _reviewer,
        );
        if (_voice != null) {
          await (await _voice!.toPending()).upload('ToDo', t.name);
          if (!t.hasVoice)
            await Api.instance.addTag('ToDo', t.name, TaskTags.voice);
        }
        for (final f in _files) {
          await f.upload('ToDo', t.name);
        }
        Session.instance.notifyDataChanged();
        if (mounted) {
          showToast(context, 'Изменения сохранены');
          Navigator.pop(context, true);
        }
      } else {
        final names = await Tasks.create(
          text: text,
          due: _due,
          executors: _executors,
          reviewer: _reviewer,
          voice: _voice,
          files: _files,
          subtasks: _subtasks.map((c) => c.text).toList(),
        );
        Session.instance.notifyDataChanged();
        if (mounted) {
          showToast(
            context,
            names.length > 1
                ? 'Создано задач: ${names.length}'
                : 'Задача создана',
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final executors = [
      for (final id in _executors) People.resolve(_people, id),
    ];
    final reviewer = _reviewer.isEmpty
        ? null
        : People.resolve(_people, _reviewer);
    var i = 0;
    return AppPage(
      header: ScreenHeader(title: _editing ? 'Редактирование' : 'Новая задача'),
      bottom: PrimaryButton(
        label: _editing ? 'Сохранить изменения' : 'Создать задачу',
        loading: _busy,
        onTap: _submit,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageScroll(
          children: [
            Reveal(
              index: i++,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Описание задачи'),
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    radius: AppRadius.field,
                    child: VoiceField(
                      clip: _voice,
                      remote: _voice == null ? _remoteVoice : null,
                      onChanged: (c) => setState(() => _voice = c),
                    ),
                  ),
                ],
              ),
            ),
            const FormGap(),
            Reveal(
              index: i++,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Текст'),
                  TextField(
                    controller: _text,
                    minLines: 2,
                    maxLines: 6,
                    style: AppText.body,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: fieldDecoration(hint: 'Введите текст'),
                  ),
                ],
              ),
            ),
            const FormGap(),
            Reveal(
              index: i++,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Прикрепить'),
                  for (final f in _files)
                    AttachmentTile(
                      name: f.name,
                      meta: f.meta,
                      onDelete: () => setState(() => _files.remove(f)),
                    ),
                  DashedBox(
                    onTap: _attach,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.cloudUpload,
                          size: 20,
                          color: AppColors.ink3,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Файл или фото',
                          style: TextStyle(fontSize: 15, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 12),
              for (var s = 0; s < _subtasks.length; s++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _subtasks[s],
                    autofocus: s == _subtasks.length - 1,
                    style: AppText.body,
                    decoration: fieldDecoration(
                      hint: 'Подзадача ${s + 1}',
                      suffix: IconButton(
                        tooltip: 'Удалить подзадачу',
                        icon: const Icon(
                          AppIcons.xmarkCircleFill,
                          size: 20,
                          color: AppColors.ink4,
                        ),
                        onPressed: () =>
                            setState(() => _subtasks.removeAt(s).dispose()),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 210,
                  child: DashedBox(
                    height: 42,
                    radius: 10,
                    onTap: () =>
                        setState(() => _subtasks.add(TextEditingController())),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Добавить подзадачу',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          AppIcons.addCircledSolid,
                          size: 20,
                          color: AppColors.chipDot,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const FormGap(),
            Reveal(
              index: i++,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Срок завершения задачи'),
                  Row(
                    children: [
                      for (final m in DueMode.values) ...[
                        Expanded(
                          child: Pressable(
                            onTap: () => _pickMode(m),
                            semanticLabel: 'Срок: ${m.label}',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutQuart,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _mode == m
                                    ? AppColors.chip
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _mode == m
                                      ? AppColors.chipDot
                                      : AppColors.line,
                                ),
                              ),
                              child: Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (m != DueMode.other) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutQuart,
                    child: _due == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8, left: 2),
                            child: Text(
                              'Выполнить до ${Fmt.weekdayDate(_due)}',
                              style: AppText.caption,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              index: i++,
              child: SurfaceCard(
                onTap: _pickExecutors,
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Исполнители', style: AppText.heading),
                          const SizedBox(height: 2),
                          Text(
                            executors
                                .map(
                                  (p) => p.userId == Session.instance.userId
                                      ? 'Вы'
                                      : p.shortName,
                                )
                                .join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    AvatarStack(
                      people: [
                        for (final p in executors) Person(p.name, p.image),
                      ],
                      size: 34,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              index: i++,
              child: SurfaceCard(
                onTap: _pickReviewer,
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Проверяющий', style: AppText.heading),
                          Text(
                            reviewer?.name ?? 'Не назначен',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    if (reviewer == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.add, size: 18, color: AppColors.ink),
                            SizedBox(width: 6),
                            Text(
                              'Добавить',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      AppAvatar(
                        name: reviewer.name,
                        imageUrl: reviewer.image,
                        size: 40,
                      ),
                      IconButton(
                        tooltip: 'Убрать проверяющего',
                        onPressed: () => setState(() => _reviewer = ''),
                        icon: const Icon(
                          AppIcons.xmarkCircleFill,
                          color: AppColors.ink4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null) InlineError(_error!),
          ],
        ),
      ),
    );
  }
}
