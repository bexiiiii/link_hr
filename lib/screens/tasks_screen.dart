import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:link_mobile/models/task_model.dart';
import 'package:link_mobile/services/api_service.dart';
import 'package:link_mobile/screens/task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final ApiService _api = ApiService();
  List<TaskItem> _tasks = [];
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'Completed', 'In Progress', 'On Hold'

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final list = await _api.getTasks();
    if (mounted) {
      setState(() {
        _tasks = list;
        _isLoading = false;
      });
    }
  }

  void _showCreateTaskModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedStatus = 'In Progress';
    final subtask1Controller = TextEditingController(text: 'Собрать исходные данные');
    final subtask2Controller = TextEditingController(text: 'Подготовить отчет');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Новая задача',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill,
                              color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Название задачи',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'Например: Подготовка кадрового отчета',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Описание / детали',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Подробное описание задачи и ожидаемый результат...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Статус',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'In Progress', child: Text('В работе (In Progress)')),
                        DropdownMenuItem(value: 'On Hold', child: Text('На паузе (On Hold)')),
                        DropdownMenuItem(value: 'Completed', child: Text('Выполнено (Completed)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Подзадачи',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subtask1Controller,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(CupertinoIcons.square, size: 18, color: Color(0xFF94A3B8)),
                        hintText: 'Подзадача 1',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: subtask2Controller,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(CupertinoIcons.square, size: 18, color: Color(0xFF94A3B8)),
                        hintText: 'Подзадача 2',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final subtasks = <String>[];
                        if (subtask1Controller.text.trim().isNotEmpty) {
                          subtasks.add(subtask1Controller.text.trim());
                        }
                        if (subtask2Controller.text.trim().isNotEmpty) {
                          subtasks.add(subtask2Controller.text.trim());
                        }

                        final now = DateTime.now();
                        final dateStr =
                            "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

                        await _api.createTask(
                          title: title,
                          description: descController.text.trim(),
                          dueDate: dateStr,
                          status: selectedStatus,
                          subtasks: subtasks,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        _loadTasks();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7052BA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Создать задачу',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((t) => t.status == 'Completed').length;
    final inProgressCount = _tasks.where((t) => t.status == 'In Progress').length;
    final onHoldCount = _tasks.where((t) => t.status == 'On Hold').length;

    final filteredTasks = _selectedFilter == 'All'
        ? _tasks
        : _tasks.where((t) => t.status == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF7052BA),
          onRefresh: _loadTasks,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top Bar (Task + Action Icons)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Task',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.8,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _showCreateTaskModal,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.plus,
                                color: Color(0xFF0F172A),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.slider_horizontal_3,
                              color: Color(0xFF0F172A),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Pills: (2) Completed | (5) In Progress | (8) On Hold
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          count: completedCount,
                          label: 'Completed',
                          color: const Color(0xFF4EBE71),
                          isSelected: _selectedFilter == 'Completed',
                          onTap: () {
                            setState(() {
                              _selectedFilter =
                                  _selectedFilter == 'Completed' ? 'All' : 'Completed';
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildFilterPill(
                          count: inProgressCount,
                          label: 'In Progress',
                          color: const Color(0xFF6558F5),
                          isSelected: _selectedFilter == 'In Progress',
                          onTap: () {
                            setState(() {
                              _selectedFilter =
                                  _selectedFilter == 'In Progress' ? 'All' : 'In Progress';
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildFilterPill(
                          count: onHoldCount,
                          label: 'On Hold',
                          color: const Color(0xFF7052BA),
                          isSelected: _selectedFilter == 'On Hold',
                          onTap: () {
                            setState(() {
                              _selectedFilter =
                                  _selectedFilter == 'On Hold' ? 'All' : 'On Hold';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 18)),

              // Task List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 14),
                  ),
                )
              else if (filteredTasks.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_seal,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Нет задач в этой категории',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = filteredTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: _buildTaskCard(task),
                        );
                      },
                      childCount: filteredTasks.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required int count,
    required String label,
    required Color color,
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
          color: isSelected ? color : const Color(0xFFE9ECF2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    Color statusBg;
    Color statusText;
    switch (task.status) {
      case 'Completed':
        statusBg = const Color(0xFF4EBE71);
        statusText = Colors.white;
        break;
      case 'In Progress':
        statusBg = const Color(0xFF6558F5);
        statusText = Colors.white;
        break;
      case 'On Hold':
        statusBg = const Color(0xFF7052BA);
        statusText = Colors.white;
        break;
      default:
        statusBg = const Color(0xFFE2E8F0);
        statusText = const Color(0xFF475569);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              task: task,
              onTaskUpdated: _loadTasks,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEFF2F6), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              task.date,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAssigneeAvatarsWithCount(task.assignees.length),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    task.status,
                    style: TextStyle(
                      color: statusText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatarsWithCount(int total) {
    return Row(
      children: [
        SizedBox(
          height: 26,
          width: 50,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: _avatarMini(const Color(0xFFFDE047), 'D'),
              ),
              Positioned(
                left: 14,
                child: _avatarMini(const Color(0xFFF472B6), 'G'),
              ),
              Positioned(
                left: 28,
                child: _avatarMini(const Color(0xFF60A5FA), 'P'),
              ),
            ],
          ),
        ),
        if (total > 2) ...[
          const SizedBox(width: 4),
          Text(
            '+$total',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatarMini(Color color, String text) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
