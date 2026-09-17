import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/app_icons.dart';

import '../../core/files.dart';
import '../../core/forms.dart';
import '../../core/fmt.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/tasks.dart';
import 'task_card.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.name});

  final String name;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskItem? _task;
  Map<String, (String, String?)> _people = {};
  List<Attachment> _files = [];
  bool _loading = true;
  Object? _error;
  bool _uploading = false;
  final _subtaskController = TextEditingController();
  final _subtaskFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subtaskController.dispose();
    _subtaskFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        Tasks.get(widget.name),
        Tasks.people(),
        Files.list('ToDo', widget.name).catchError((_) => <Attachment>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _task = results[0] as TaskItem;
        _people = results[1] as Map<String, (String, String?)>;
        _files = results[2] as List<Attachment>;
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

  Future<void> _mutate(
    Future<void> Function() action, {
    VoidCallback? rollback,
    String? success,
  }) async {
    try {
      await action();
      Session.instance.notifyDataChanged();
      if (success != null && mounted) showToast(context, success);
    } catch (e) {
      rollback?.call();
      if (mounted) {
        setState(() {});
        showToast(context, errorText(e), error: true);
      }
    }
  }

  void _setStatus(TaskStatus status) {
    final task = _task!;
    if (task.status == status) return;
    final previous = task.status;
    setState(() => task.status = status);
    _mutate(
      () => Tasks.setStatus(task.name, status),
      rollback: () => task.status = previous,
    );
  }

  void _toggle(Subtask sub) {
    setState(() => sub.done = !sub.done);
    _mutate(
      () => Tasks.toggleSubtask(sub, sub.done),
      rollback: () => sub.done = !sub.done,
    );
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    _subtaskController.clear();
    await _mutate(() async {
      final sub = await Tasks.addSubtask(
        widget.name,
        title,
        allocatedTo: _task!.allocatedTo,
      );
      if (mounted) setState(() => _task!.subtasks.add(sub));
    });
    _subtaskFocus.requestFocus();
  }

  Future<void> _pickDue() async {
    final task = _task!;
    final d = await pickDate(context, initial: task.due);
    if (d == null) return;
    await _mutate(() => Tasks.setDue(task.name, d));
    _load();
  }

  Future<void> _reassign() async {
    final options = [
      for (final e in _people.entries)
        SelectOption(e.key, e.value.$1, subtitle: e.key),
    ];
    final picked = await showSelectSheet(
      context,
      title: 'Исполнитель',
      options: options,
      selected: _task!.allocatedTo,
    );
    if (picked == null || picked == _task!.allocatedTo) return;
    await _mutate(
      () => Tasks.setAssignee(widget.name, picked),
      success: 'Исполнитель изменён',
    );
    _load();
  }

  Future<void> _setPriority(String priority) async {
    final t = _task!;
    if (t.priority == priority) return;
    await _mutate(
      () => Tasks.update(
        t.name,
        title: t.title,
        description: t.description,
        due: t.due,
        priority: priority,
        allocatedTo: t.allocatedTo,
      ),
    );
    _load();
  }

  Future<void> _attach() async {
    setState(() => _uploading = true);
    try {
      final file = await Files.pickAndUpload('ToDo', widget.name);
      if (file != null && mounted) {
        setState(() => _files.add(file));
        showToast(context, 'Файл прикреплён');
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(Attachment a) async {
    try {
      await Files.open(a);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  Future<void> _removeFile(Attachment a) async {
    final ok = await confirmAction(
      context,
      title: 'Удалить вложение?',
      message: a.fileName,
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!ok) return;
    await _mutate(() async {
      await Files.delete(a);
      if (mounted) setState(() => _files.remove(a));
    });
  }

  Future<void> _more() async {
    final action = await pickAction(
      context,
      actions: const [
        SheetAction('edit', 'Редактировать'),
        SheetAction('delete', 'Удалить задачу', destructive: true),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      final saved = await pushPage<bool>(context, TaskFormScreen(task: _task));
      if (saved == true) _load();
    } else {
      final ok = await confirmAction(
        context,
        title: 'Удалить задачу?',
        message:
            'Задача и её история будут удалены без возможности восстановления.',
        confirmLabel: 'Удалить',
        destructive: true,
      );
      if (!ok || !mounted) return;
      try {
        await Tasks.delete(widget.name);
        Session.instance.notifyDataChanged();
        if (mounted) {
          showToast(context, 'Задача удалена');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) showToast(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: ScreenHeader(
        title: 'Детали задачи',
        actions: [
          CircleButton(
            icon: AppIcons.ellipsis,
            label: 'Действия',
            onTap: _task == null ? null : _more,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return PageScroll(
        children: const [
          Skeleton(height: 72, width: 260),
          SizedBox(height: 16),
          Skeleton(height: 18, width: 220),
          SizedBox(height: 24),
          Skeleton(height: 420, radius: 28),
        ],
      );
    }
    if (_error != null)
      return PageScroll(
        children: [ErrorState(error: _error!, onRetry: _load)],
      );
    final task = _task!;
    final people = taskPeople(task, _people);
    final assigneeName = _people[task.allocatedTo]?.$1 ?? task.allocatedTo;
    final done = task.subtasks.where((s) => s.done).length;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PageScroll(
        onRefresh: _load,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.boltFill,
                  color: taskTone(task.status).solid,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  task.title,
                  style: AppText.display.copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final s in [
                  TaskStatus.completed,
                  TaskStatus.inProgress,
                  TaskStatus.onHold,
                ])
                  Pressable(
                    onTap: () => _setStatus(s),
                    semanticLabel: 'Статус: ${s.label}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: LegendDot(
                        color: task.status == s
                            ? taskTone(s).solid
                            : AppColors.chipDot,
                        label: s.label,
                        bold: task.status == s,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SurfaceCard(
            radius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Divided(
              children: [
                DetailRow(
                  label: 'Исполнитель',
                  value: assigneeName.isEmpty ? 'Не назначен' : assigneeName,
                  trailing: AvatarStack(people: people, size: 34),
                  onTap: _reassign,
                ),
                DetailRow(
                  label: 'Срок выполнения',
                  value: task.due == null
                      ? 'Без срока'
                      : 'До ${Fmt.weekdayDate(task.due)}',
                  trailing: CircleButton(
                    icon: AppIcons.calendar,
                    label: 'Изменить срок',
                    background: AppColors.violet,
                    foreground: Colors.white,
                    iconSize: 20,
                    onTap: _pickDue,
                  ),
                ),
                DetailRow(
                  label: 'Приоритет',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final p in taskPriorities)
                          Pressable(
                            onTap: () => _setPriority(p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: task.priority == p
                                    ? (p == 'High'
                                          ? AppColors.red
                                          : AppColors.charcoal)
                                    : AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusLabel(p),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: task.priority == p
                                      ? Colors.white
                                      : AppColors.ink2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Подзадачи', style: AppText.caption),
                          ),
                          if (task.subtasks.isNotEmpty)
                            Text(
                              '$done из ${task.subtasks.length}',
                              style: AppText.caption,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final sub in task.subtasks)
                        Dismissible(
                          key: ValueKey(sub.name),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 12),
                            child: const Icon(
                              AppIcons.trash,
                              color: AppColors.red,
                              size: 20,
                            ),
                          ),
                          onDismissed: (_) {
                            setState(() => task.subtasks.remove(sub));
                            _mutate(
                              () => Tasks.removeSubtask(sub),
                              rollback: () => task.subtasks.add(sub),
                            );
                          },
                          child: Pressable(
                            onTap: () => _toggle(sub),
                            scale: 0.99,
                            semanticLabel:
                                '${sub.title}, ${sub.done ? 'выполнено' : 'не выполнено'}',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  _Check(checked: sub.done),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: sub.done
                                            ? AppColors.ink3
                                            : AppColors.ink,
                                        decoration: sub.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: AppColors.ink4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(
                            AppIcons.plus,
                            size: 18,
                            color: AppColors.violet,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _subtaskController,
                              focusNode: _subtaskFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addSubtask(),
                              style: AppText.body,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Добавить подзадачу',
                                hintStyle: AppText.body.copyWith(
                                  color: AppColors.ink3,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Описание задачи', style: AppText.caption),
                      const SizedBox(height: 6),
                      Text(
                        task.description.isEmpty
                            ? 'Описание не добавлено'
                            : task.description,
                        style: AppText.body.copyWith(
                          color: task.description.isEmpty
                              ? AppColors.ink3
                              : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Вложения', style: AppText.caption),
                      const SizedBox(height: 4),
                      for (final f in _files)
                        AttachmentTile(
                          name: f.fileName,
                          meta: f.meta,
                          onTap: () => _open(f),
                          onDelete: () => _removeFile(f),
                        ),
                      const SizedBox(height: 6),
                      Pressable(
                        onTap: _uploading ? null : _attach,
                        child: Row(
                          children: [
                            if (_uploading)
                              const CupertinoActivityIndicator()
                            else
                              const Icon(
                                AppIcons.paperclip,
                                size: 18,
                                color: AppColors.violet,
                              ),
                            const SizedBox(width: 10),
                            Text(
                              _uploading ? 'Загрузка…' : 'Прикрепить файл',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.violet,
                              ),
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
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutQuart,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? AppColors.violet : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? AppColors.violet : AppColors.chipDot,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}
