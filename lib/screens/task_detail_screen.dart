import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:link_mobile/models/task_model.dart';
import 'package:link_mobile/services/api_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final VoidCallback? onTaskUpdated;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TaskItem _task;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  void _changeStatus(String newStatus) async {
    setState(() {
      _task.status = newStatus;
    });
    await _api.updateTaskStatus(_task.id, newStatus);
    widget.onTaskUpdated?.call();
  }

  void _toggleSubtask(int index) async {
    final current = _task.subtasks[index].isCompleted;
    setState(() {
      _task.subtasks[index].isCompleted = !current;
      final allDone = _task.subtasks.every((s) => s.isCompleted);
      if (allDone) {
        _task.status = 'Completed';
      }
    });
    await _api.toggleSubtask(_task.id, index, !current);
    widget.onTaskUpdated?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.chevron_back,
                  color: Color(0xFF1E1E2D),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Task Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F4F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: Color(0xFF1E1E2D),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task Icon + Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7052BA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.square_grid_2x2_fill,
                        color: Color(0xFF7052BA),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Radios / Badges (Completed, In Progress, On Hold)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusPill(
                      label: 'Completed',
                      dotColor: const Color(0xFF4EBE71),
                      isSelected: _task.status == 'Completed',
                      onTap: () => _changeStatus('Completed'),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusPill(
                      label: 'In Progress',
                      dotColor: const Color(0xFF6558F5),
                      isSelected: _task.status == 'In Progress',
                      onTap: () => _changeStatus('In Progress'),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusPill(
                      label: 'On Hold',
                      dotColor: const Color(0xFF7052BA),
                      isSelected: _task.status == 'On Hold',
                      onTap: () => _changeStatus('On Hold'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFF1F4F9), height: 1),
              const SizedBox(height: 18),

              // Assigned for
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned for',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _task.assignees.join(', '),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  _buildAssigneeAvatars(),
                ],
              ),
              const SizedBox(height: 20),

              // To be done on
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To be done on',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Before ${_task.date}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7052BA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.calendar,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Subtasks
              const Text(
                'Subtasks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              if (_task.subtasks.isEmpty)
                const Text(
                  'Нет подзадач',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _task.subtasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final subtask = _task.subtasks[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _toggleSubtask(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: subtask.isCompleted
                                    ? const Color(0xFF7052BA)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: subtask.isCompleted
                                      ? const Color(0xFF7052BA)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.8,
                                ),
                              ),
                              child: subtask.isCompleted
                                  ? const Icon(
                                      CupertinoIcons.checkmark,
                                      color: Colors.white,
                                      size: 13,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                subtask.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: subtask.isCompleted
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF0F172A),
                                  decoration: subtask.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Task Description
              const Text(
                'Task Description',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _task.description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF334155),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Attachments
              const Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              if (_task.attachments.isEmpty)
                const Text(
                  'Нет вложений',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                )
              else
                Column(
                  children: _task.attachments.map((att) {
                    return _buildAttachmentCard(att);
                  }).toList(),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color dotColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? dotColor.withValues(alpha: 0.12)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? dotColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatars() {
    return SizedBox(
      height: 32,
      width: 76,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _avatarCircle(const Color(0xFFFDE047), 'D'),
          ),
          Positioned(
            left: 20,
            child: _avatarCircle(const Color(0xFFF472B6), 'G'),
          ),
          Positioned(
            left: 40,
            child: _avatarCircle(const Color(0xFF60A5FA), 'P'),
          ),
        ],
      ),
    );
  }

  Widget _avatarCircle(Color color, String text) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(AttachmentItem att) {
    Color badgeColor;
    switch (att.type.toUpperCase()) {
      case 'PDF':
        badgeColor = const Color(0xFF7052BA);
        break;
      case 'PNG':
      case 'JPG':
        badgeColor = const Color(0xFFEC4899);
        break;
      case 'RAR':
      case 'ZIP':
        badgeColor = const Color(0xFF4F46E5);
        break;
      default:
        badgeColor = const Color(0xFF0EA5E9);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                att.type.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${att.size} • ${att.type}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.arrow_down_to_line,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}
