import 'package:cloud_firestore/cloud_firestore.dart';

class TaskStatus {
  static const String todo = 'todo';
  static const String inProgress = 'in_progress';
  static const String testing = 'testing';
  static const String complete = 'complete';

  static const List<String> values = [todo, inProgress, testing, complete];

  static String label(String status) {
    switch (status) {
      case todo:
        return 'To Do';
      case inProgress:
        return 'In Progress';
      case testing:
        return 'Testing';
      case complete:
        return 'Complete';
      default:
        return status;
    }
  }
}

class TaskComment {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? imageUrl;

  TaskComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.imageUrl,
  });

  factory TaskComment.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['createdAt'];
    DateTime parsed;
    if (raw is Timestamp) {
      parsed = raw.toDate();
    } else {
      parsed = DateTime.now();
    }
    return TaskComment(
      id: id,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: parsed,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime dueDate;
  final DateTime? deadline;
  final int? estimatedMinutes;
  final String priority;
  final String difficulty;
  final String status;              
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedBy;
  final String? assignedByName;
  final String ownerUid;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    required this.dueDate,
    this.deadline,
    this.estimatedMinutes,
    this.priority = 'normal',
    this.difficulty = 'easy',
    this.status = 'todo',
    this.assignedTo,
    this.assignedToName,
    this.assignedBy,
    this.assignedByName,
    this.ownerUid = '',
  });

  bool get isAssigned => assignedTo != null && assignedTo!.isNotEmpty;
  bool get isOverdue =>
      deadline != null && !isCompleted && DateTime.now().isAfter(deadline!);

  String get estimatedDurationLabel {
    if (estimatedMinutes == null) return '';
    if (estimatedMinutes! < 60) return '${estimatedMinutes}m';
    final h = estimatedMinutes! ~/ 60;
    final m = estimatedMinutes! % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    DateTime? deadline,
    int? estimatedMinutes,
    String? priority,
    String? difficulty,
    String? status,
    String? assignedTo,
    String? assignedToName,
    String? assignedBy,
    String? assignedByName,
    String? ownerUid,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      deadline: deadline ?? this.deadline,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      priority: priority ?? this.priority,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedByName: assignedByName ?? this.assignedByName,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': Timestamp.fromDate(dueDate),
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      'priority': priority,
      'difficulty': difficulty,
      'status': status,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedToName != null) 'assignedToName': assignedToName,
      if (assignedBy != null) 'assignedBy': assignedBy,
      if (assignedByName != null) 'assignedByName': assignedByName,
      'ownerUid': ownerUid,
    };
  }

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    final rawDueDate = map['dueDate'];
    DateTime parsedDueDate;

    if (rawDueDate is Timestamp) {
      parsedDueDate = rawDueDate.toDate();
    } else if (rawDueDate is String) {
      parsedDueDate = DateTime.tryParse(rawDueDate) ?? DateTime.now();
    } else {
      parsedDueDate = DateTime.now();
    }

    final rawDeadline = map['deadline'];
    DateTime? parsedDeadline;
    if (rawDeadline is Timestamp) {
      parsedDeadline = rawDeadline.toDate();
    } else if (rawDeadline is String) {
      parsedDeadline = DateTime.tryParse(rawDeadline);
    }

    return Task(
      id: map['id'] as String? ?? id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      dueDate: parsedDueDate,
      deadline: parsedDeadline,
      estimatedMinutes: map['estimatedMinutes'] as int?,
      priority: map['priority'] as String? ?? 'normal',
      difficulty: map['difficulty'] as String? ?? 'easy',
      status: map['status'] as String? ?? 'todo',
      assignedTo: map['assignedTo'] as String?,
      assignedToName: map['assignedToName'] as String?,
      assignedBy: map['assignedBy'] as String?,
      assignedByName: map['assignedByName'] as String?,
      ownerUid: map['ownerUid'] as String? ?? '',
    );
  }
}