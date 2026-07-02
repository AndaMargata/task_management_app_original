import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/chat_user.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

class TaskViewmodel extends ChangeNotifier {
  List<Task> _ownTasks = [];
  List<Task> _assignedTasks = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assignedSub;
  String? _currentUserId;
  ChatUser? _currentUserProfile;

  /// All tasks: own + assigned to me (de-duped)
  List<Task> get tasks {
    final map = <String, Task>{};
    for (final t in _ownTasks) {
      map[t.id] = t;
    }
    for (final t in _assignedTasks) {
      map[t.id] = t;
    }
    return map.values.toList();
  }

  String? get currentUserId => _currentUserId;
  ChatUser? get currentUserProfile => _currentUserProfile;
  bool get isAdmin => _currentUserProfile?.isAdmin ?? false;

  Future<void> bindToUser(String userId) async {
    if (_currentUserId == userId && _ownSub != null) return;

    await _ownSub?.cancel();
    await _assignedSub?.cancel();
    _currentUserId = userId;
    _ownTasks = [];
    _assignedTasks = [];
    notifyListeners();

    _currentUserProfile = await ChatService.getUserProfile(userId);
    notifyListeners();

    final tasksCol = FirebaseFirestore.instance.collection('tasks');

    _ownSub = tasksCol
        .where('ownerUid', isEqualTo: userId)
        .snapshots()
        .listen(
      (snap) {
        _ownTasks = snap.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList();
        _ownTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Own tasks stream error: $error');
      },
    );

    _assignedSub = tasksCol
        .where('assignedTo', isEqualTo: userId)
        .snapshots()
        .listen(
      (snap) {
        _assignedTasks = snap.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList();
        _assignedTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Assigned tasks stream error: $error');
      },
    );
  }

  Future<void> unbindUser() async {
    await _ownSub?.cancel();
    await _assignedSub?.cancel();
    _ownSub = null;
    _assignedSub = null;
    _currentUserId = null;
    _currentUserProfile = null;
    _ownTasks = [];
    _assignedTasks = [];
    notifyListeners();
  }

  Future<void> addTask(
    String title,
    String description, {
    DateTime? deadline,
    int? estimatedMinutes,
    String priority = 'normal',
    String difficulty = 'easy',
  }) async {
    if (_currentUserId == null) return;

    final docRef = FirebaseFirestore.instance.collection('tasks').doc();
    final newTask = Task(
      id: docRef.id,
      title: title,
      description: description,
      dueDate: DateTime.now(),
      ownerUid: _currentUserId!,
      deadline: deadline,
      estimatedMinutes: estimatedMinutes,
      priority: priority,
      difficulty: difficulty,
    );

    try {
      await docRef.set({
        ...newTask.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('addTask error: $e');
    }
  }

  Future<void> updateTask({
    required String id,
    required String title,
    required String description,
    DateTime? deadline,
    int? estimatedMinutes,
    String? priority,
    String? difficulty,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'description': description,
      };
      if (priority != null) data['priority'] = priority;
      if (difficulty != null) data['difficulty'] = difficulty;
      // Allow clearing deadline/duration by passing null explicitly
      data['deadline'] = deadline != null
          ? Timestamp.fromDate(deadline)
          : FieldValue.delete();
      data['estimatedMinutes'] =
          estimatedMinutes ?? FieldValue.delete();

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(id)
          .update(data);
    } catch (e) {
      debugPrint('updateTask error: $e');
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(id).delete();
    } catch (e) {
      debugPrint('deleteTask error: $e');
    }
  }

  Future<void> toggleTaskStatus(String id) async {
    final task = tasks.firstWhere((t) => t.id == id,
        orElse: () => Task(
            id: '', title: '', description: '', dueDate: DateTime.now()));
    if (task.id.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(id)
          .update({'isCompleted': !task.isCompleted});
    } catch (e) {
      debugPrint('toggleTaskStatus error: $e');
    }
  }

  /// Update the workflow status of a task.
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    try {
      // Get the task title before updating for the notification
      final task = tasks.firstWhere((t) => t.id == taskId,
          orElse: () => Task(
              id: '', title: '', description: '', dueDate: DateTime.now()));

      final updates = <String, dynamic>{'status': newStatus};
      if (newStatus == 'complete') {
        updates['isCompleted'] = true;
      } else {
        updates['isCompleted'] = false;
      }
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .update(updates);

      if (task.id.isNotEmpty) {
        final statusLabel = TaskStatus.label(newStatus);
        NotificationService.showTaskNotification(
          title: 'Task Status Updated',
          body: '"${task.title}" moved to $statusLabel',
          taskId: taskId,
        );
      }
    } catch (e) {
      debugPrint('updateTaskStatus error: $e');
    }
  }

  /// Add a comment to a task (sub-collection: tasks/{taskId}/comments).
  /// Optionally attach a photo via [imageUrl].
  Future<void> addComment(String taskId, String text, {String? imageUrl}) async {
    if (_currentUserId == null || _currentUserProfile == null) return;
    if (text.trim().isEmpty && imageUrl == null) return;

    try {
      final data = <String, dynamic>{
        'authorUid': _currentUserId,
        'authorName': _currentUserProfile!.fullName,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (imageUrl != null) data['imageUrl'] = imageUrl;

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .add(data);
    } catch (e) {
      debugPrint('addComment error: $e');
    }
  }

  /// Delete all comments for a task.
  Future<void> clearComments(String taskId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('clearComments error: $e');
    }
  }

  /// Stream of comments for a task, newest last.
  Stream<List<TaskComment>> commentsStream(String taskId) {
    return FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TaskComment.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Assign a task to another user. Only admins should call this.
  Future<void> assignTask({
    required String taskTitle,
    required String taskDescription,
    required ChatUser assignee,
    DateTime? deadline,
    int? estimatedMinutes,
    String priority = 'normal',
    String difficulty = 'easy',
  }) async {
    if (_currentUserId == null || _currentUserProfile == null) return;

    final docRef = FirebaseFirestore.instance.collection('tasks').doc();
    try {
      await docRef.set({
        'id': docRef.id,
        'title': taskTitle,
        'description': taskDescription,
        'isCompleted': false,
        'status': 'todo',
        'dueDate': Timestamp.fromDate(DateTime.now()),
        'ownerUid': _currentUserId,
        'assignedTo': assignee.uid,
        'assignedToName': assignee.fullName,
        'assignedBy': _currentUserId,
        'assignedByName': _currentUserProfile!.fullName,
        'priority': priority,
        'difficulty': difficulty,
        if (deadline != null) 'deadline': Timestamp.fromDate(deadline), // ignore: use_null_aware_elements
        if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes, // ignore: use_null_aware_elements
        'createdAt': FieldValue.serverTimestamp(),
      });

      NotificationService.showTaskNotification(
        title: 'New Task Assigned',
        body: 'You\'ve been assigned to "$taskTitle" by ${_currentUserProfile!.fullName}',
        taskId: docRef.id,
      );
    } catch (e) {
      debugPrint('assignTask error: $e');
    }
  }

  /// Refresh user profile (e.g. after role change)
  Future<void> refreshProfile() async {
    if (_currentUserId == null) return;
    _currentUserProfile = await ChatService.getUserProfile(_currentUserId!);
    notifyListeners();
  }

  void clearTasks() {
    _ownTasks.clear();
    _assignedTasks.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _ownSub?.cancel();
    _assignedSub?.cancel();
    super.dispose();
  }
}
