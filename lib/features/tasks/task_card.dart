import 'package:flutter/cupertino.dart';
import '../../core/app_icons.dart';

import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/tasks.dart';

Tone taskTone(TaskStatus s) => switch (s) {
  TaskStatus.completed => Tone.green,
  TaskStatus.inProgress => Tone.violet,
  TaskStatus.onHold => Tone.dark,
};

List<Person> taskPeople(
  TaskItem task,
  Map<String, (String, String?)> directory,
) => [
  for (final id in task.people)
    Person(directory[id]?.$1 ?? id, directory[id]?.$2),
];

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.directory,
    required this.onTap,
  });

  final TaskItem task;
  final Map<String, (String, String?)> directory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue =
        task.status == TaskStatus.inProgress &&
        task.due != null &&
        Fmt.dateOnly(task.due!).isBefore(Fmt.dateOnly(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.cardTitle.copyWith(
                fontSize: 16,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  Fmt.date(task.due ?? task.created),
                  style: AppText.caption.copyWith(
                    color: overdue ? AppColors.red : AppColors.ink3,
                  ),
                ),
                if (overdue) ...[
                  const SizedBox(width: 6),
                  Text(
                    'просрочено',
                    style: AppText.caption.copyWith(color: AppColors.red),
                  ),
                ],
                if (task.priority == 'High') ...[
                  const SizedBox(width: 10),
                  const Icon(AppIcons.flagFill, size: 12, color: AppColors.red),
                  const SizedBox(width: 3),
                  Text(
                    'Высокий',
                    style: AppText.caption.copyWith(
                      color: const Color(0xFFA9362D),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AvatarStack(people: taskPeople(task, directory)),
                if (task.subtaskTotal > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    AppIcons.checkmarkSquare,
                    size: 15,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${task.subtaskDone}/${task.subtaskTotal}',
                    style: AppText.caption,
                  ),
                ],
                const Spacer(),
                StatusPill(
                  null,
                  label: task.status.label,
                  tone: taskTone(task.status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
