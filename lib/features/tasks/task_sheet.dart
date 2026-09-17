import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/files.dart';
import '../../core/fmt.dart';
import '../../core/media.dart';
import '../../core/people.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/tasks.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

Tone stageTone(TaskStage s) => switch (s) {
  TaskStage.todo => Tone.neutral,
  TaskStage.inWork => Tone.green,
  TaskStage.review => Tone.violet,
  TaskStage.done => Tone.green,
  TaskStage.archived => Tone.dark,
};

Future<void> showTaskSheet(
  BuildContext context,
  TaskItem task,
  Map<String, PersonInfo> people,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _TaskSheet(task: task, people: people),
  );
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.task, required this.people});

  final TaskItem task;
  final Map<String, PersonInfo> people;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  Attachment? _voice;
  bool _voiceLoading = false;
  bool _busy = false;

  TaskItem get t => widget.task;
  String get me => Session.instance.userId;

  @override
  void initState() {
    super.initState();
    if (t.hasVoice) {
      _voiceLoading = true;
      Tasks.voiceOf(t.name)
          .then((v) {
            if (mounted) setState(() => _voice = v);
          })
          .whenComplete(() {
            if (mounted) setState(() => _voiceLoading = false);
          });
    }
  }

  Future<void> _move(TaskStage stage, String success) async {
    setState(() => _busy = true);
    try {
      await Tasks.setStage(t, stage);
      Session.instance.notifyDataChanged();
      if (mounted) {
        Navigator.pop(context);
        showToast(context, success);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _actions() {
    final isExecutor = t.allocatedTo == me;
    final isReviewer =
        t.reviewer == me ||
        (t.reviewer.isEmpty && t.owner == me && !isExecutor);
    final hasReviewer = t.reviewer.isNotEmpty && t.reviewer != t.allocatedTo;
    switch (t.stage) {
      case TaskStage.todo when isExecutor:
        return [
          PrimaryButton(
            label: 'Взять в работу',
            loading: _busy,
            onTap: () => _move(TaskStage.inWork, 'Задача в работе'),
          ),
        ];
      case TaskStage.inWork when isExecutor:
        return [
          PrimaryButton(
            label: hasReviewer ? 'Отправить на проверку' : 'Завершить задачу',
            kind: hasReviewer ? ButtonKind.dark : ButtonKind.green,
            loading: _busy,
            onTap: () => hasReviewer
                ? _move(TaskStage.review, 'Отправлено на проверку')
                : _move(TaskStage.done, 'Задача выполнена'),
          ),
        ];
      case TaskStage.review when isReviewer:
        return [
          PrimaryButton(
            label: 'Принять работу',
            kind: ButtonKind.green,
            loading: _busy,
            onTap: () => _move(TaskStage.done, 'Задача принята'),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Вернуть на доработку',
            kind: ButtonKind.outline,
            onTap: _busy
                ? null
                : () => _move(TaskStage.inWork, 'Задача возвращена в работу'),
          ),
        ];
      case TaskStage.review:
        return [
          const PrimaryButton(
            label: 'Ожидает проверки',
            kind: ButtonKind.outline,
          ),
        ];
      case TaskStage.done || TaskStage.archived
          when isExecutor || isReviewer || t.owner == me:
        return [
          PrimaryButton(
            label: 'Вернуть в работу',
            kind: ButtonKind.outline,
            loading: _busy,
            onTap: () => _move(TaskStage.inWork, 'Задача снова в работе'),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = People.resolve(
      widget.people,
      t.owner.isEmpty ? t.allocatedTo : t.owner,
    );
    final executor = People.resolve(widget.people, t.allocatedTo);
    final reviewer = t.reviewer.isEmpty
        ? null
        : People.resolve(widget.people, t.reviewer);
    final tone = stageTone(t.stage);
    final canEdit = t.owner == me || t.reviewer == me || t.allocatedTo == me;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title,
                    ),
                  ),
                  if (canEdit)
                    CircleButton(
                      icon: AppIcons.squarePencil,
                      label: 'Редактировать задачу',
                      background: AppColors.surface,
                      size: 42,
                      iconSize: 20,
                      onTap: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        nav.push(
                          CupertinoPageRoute(
                            builder: (_) => TaskFormScreen(task: t),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: tone.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.arrowRight, size: 16, color: tone.ink),
                    const SizedBox(width: 8),
                    Text(
                      t.stage.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tone.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (reviewer != null) ...[
                const _Label('Проверяющий'),
                PersonRow(
                  person: reviewer,
                  caption: reviewer.userId == me ? 'Вы' : null,
                ),
              ],
              if (t.hasVoice) ...[
                const _Label('Описание задачи'),
                _voiceLoading
                    ? const Skeleton(height: 46, radius: 23)
                    : _voice == null
                    ? Text(
                        'Голосовое описание недоступно',
                        style: AppText.caption,
                      )
                    : VoicePlayer(remote: _voice),
              ],
              const _Label('Текст'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  [
                    t.title,
                    t.description,
                  ].where((s) => s.isNotEmpty).join('\n\n'),
                  style: AppText.body,
                ),
              ),
              const SizedBox(height: 18),
              const Divider(),
              const _Label('Автор / выполняющий'),
              PersonRow(
                person: author,
                caption: author.userId == me ? 'Вы' : 'Автор',
              ),
              if (executor.userId != author.userId) ...[
                const SizedBox(height: 12),
                PersonRow(
                  person: executor,
                  caption: executor.userId == me
                      ? 'Вы · исполнитель'
                      : 'Исполнитель',
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const IconBadge(
                    icon: AppIcons.calendar,
                    tone: Tone.neutral,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Выполнить до', style: AppText.caption),
                      Text(
                        t.due == null ? 'Без срока (бэклог)' : Fmt.date(t.due),
                        style: AppText.bodyStrong.copyWith(
                          color: t.overdue ? AppColors.red : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        CupertinoPageRoute(
                          builder: (_) => TaskDetailScreen(name: t.name),
                        ),
                      );
                    },
                    child: Text(
                      t.subtaskTotal > 0
                          ? 'Подзадачи ${t.subtaskDone}/${t.subtaskTotal}'
                          : 'Подробнее',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.violet,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._actions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: AppText.caption.copyWith(letterSpacing: 0.3),
    ),
  );
}
