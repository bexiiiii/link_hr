class TaskItem {
  final String id;
  final String title;
  final String description;
  final String date;
  String status; // 'Completed', 'In Progress', 'On Hold'
  final List<String> assignees;
  final List<SubtaskItem> subtasks;
  final List<AttachmentItem> attachments;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.status,
    required this.assignees,
    required this.subtasks,
    required this.attachments,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] ?? json['name'] ?? '',
      title: json['title'] ?? json['description'] ?? 'Задача',
      description: json['description'] ?? '',
      date: json['date'] ?? '11/08/2024',
      status: json['status'] ?? 'In Progress',
      assignees: (json['assignees'] as List?)?.cast<String>() ?? ['Dimas', 'Galih', 'Putra'],
      subtasks: (json['subtasks'] as List?)
              ?.map((e) => SubtaskItem.fromJson(e))
              .toList() ??
          [],
      attachments: (json['attachments'] as List?)
              ?.map((e) => AttachmentItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'status': status,
        'assignees': assignees,
        'subtasks': subtasks.map((e) => e.toJson()).toList(),
        'attachments': attachments.map((e) => e.toJson()).toList(),
      };
}

class SubtaskItem {
  final String title;
  bool isCompleted;

  SubtaskItem({required this.title, this.isCompleted = false});

  factory SubtaskItem.fromJson(Map<String, dynamic> json) => SubtaskItem(
        title: json['title'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'isCompleted': isCompleted,
      };
}

class AttachmentItem {
  final String name;
  final String type; // 'PDF', 'PNG', 'RAR', 'DOC'
  final String size;

  AttachmentItem({required this.name, required this.type, required this.size});

  factory AttachmentItem.fromJson(Map<String, dynamic> json) => AttachmentItem(
        name: json['name'] ?? '',
        type: json['type'] ?? 'PDF',
        size: json['size'] ?? '1.2 MB',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'size': size,
      };
}
