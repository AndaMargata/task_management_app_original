import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_management_app/models/task.dart';
import 'package:task_management_app/models/conversation.dart';
import 'package:task_management_app/models/chat_message.dart';

void main() {
  // ─── Task model tests ───────────────────────────────────────────────

  group('Task model', () {
    test('TaskStatus.label maps every known status', () {
      expect(TaskStatus.label(TaskStatus.todo), 'To Do');
      expect(TaskStatus.label(TaskStatus.inProgress), 'In Progress');
      expect(TaskStatus.label(TaskStatus.testing), 'Testing');
      expect(TaskStatus.label(TaskStatus.complete), 'Complete');
      expect(TaskStatus.label('custom'), 'custom');
    });

    test('estimatedDurationLabel formats correctly', () {
      final base = DateTime(2026, 1, 1);

      expect(
        Task(id: '1', title: '', description: '', dueDate: base,
             estimatedMinutes: 45).estimatedDurationLabel,
        '45m',
      );
      expect(
        Task(id: '2', title: '', description: '', dueDate: base,
             estimatedMinutes: 60).estimatedDurationLabel,
        '1h',
      );
      expect(
        Task(id: '3', title: '', description: '', dueDate: base,
             estimatedMinutes: 95).estimatedDurationLabel,
        '1h 35m',
      );
      expect(
        Task(id: '4', title: '', description: '', dueDate: base)
            .estimatedDurationLabel,
        '',
      );
    });

    test('isOverdue is true when deadline has passed', () {
      final overdue = Task(
        id: '1', title: 'Late', description: '',
        dueDate: DateTime(2025, 1, 1),
        deadline: DateTime(2025, 1, 1),
      );
      expect(overdue.isOverdue, isTrue);

      final completed = Task(
        id: '2', title: 'Done', description: '',
        dueDate: DateTime(2025, 1, 1),
        deadline: DateTime(2025, 1, 1),
        isCompleted: true,
      );
      expect(completed.isOverdue, isFalse);
    });

    test('toMap / fromMap roundtrip preserves fields', () {
      final due = DateTime(2026, 2, 27, 10, 30);
      final deadline = DateTime(2026, 3, 1);
      final task = Task(
        id: 'abc', title: 'Report', description: 'Write it',
        dueDate: due, deadline: deadline,
        estimatedMinutes: 120, priority: 'high', difficulty: 'medium',
        status: TaskStatus.inProgress, ownerUid: 'u1',
        assignedTo: 'u2', assignedToName: 'Alex',
      );

      final restored = Task.fromMap('ignored', task.toMap());

      expect(restored.id, 'abc');
      expect(restored.title, 'Report');
      expect(restored.priority, 'high');
      expect(restored.status, TaskStatus.inProgress);
      expect(restored.estimatedMinutes, 120);
      expect(restored.dueDate, due);
      expect(restored.deadline, deadline);
      expect(restored.assignedTo, 'u2');
    });

    test('copyWith overrides selected fields', () {
      final task = Task(
        id: '1', title: 'A', description: 'B',
        dueDate: DateTime(2026, 1, 1),
      );
      final copy = task.copyWith(title: 'C', isCompleted: true);

      expect(copy.title, 'C');
      expect(copy.isCompleted, isTrue);
      expect(copy.description, 'B'); // unchanged
    });
  });

  // ─── Conversation model tests ───────────────────────────────────────

  group('Conversation model', () {
    test('helpers return correct other-participant info', () {
      final c = Conversation(
        id: 'c1',
        participants: const ['u1', 'u2'],
        participantNames: const {'u1': 'Me', 'u2': 'Sam'},
        participantEmails: const {
          'u1': 'me@x.com', 'u2': 'sam@x.com',
        },
        unread: const {'u1': 3, 'u2': 0},
      );

      expect(c.unreadCountFor('u1'), 3);
      expect(c.unreadCountFor('u2'), 0);
      expect(c.unreadCountFor('missing'), 0);
      expect(c.otherParticipantName('u1'), 'Sam');
      expect(c.otherParticipantEmail('u1'), 'sam@x.com');
    });

    test('fromMap parses Firestore document', () {
      final c = Conversation.fromMap('c1', {
        'participants': ['u1', 'u2'],
        'participantNames': {'u1': 'Me', 'u2': 'Sam'},
        'participantEmails': {'u1': 'me@x.com', 'u2': 'sam@x.com'},
        'lastMessage': 'hello',
        'lastMessageTime': Timestamp.fromDate(DateTime(2026, 2, 27)),
        'lastMessageSenderId': 'u2',
        'unread': {'u1': 2},
      });

      expect(c.lastMessage, 'hello');
      expect(c.lastMessageTime, DateTime(2026, 2, 27));
      expect(c.unreadCountFor('u1'), 2);
    });
  });

  // ─── ChatMessage model tests ────────────────────────────────────────

  group('ChatMessage model', () {
    test('type helpers work for media messages', () {
      final img = ChatMessage.fromMap('m1', {
        'senderId': 'u1', 'text': '', 'type': 'image',
        'mediaUrl': 'https://example.com/a.jpg',
      });
      expect(img.isImage, isTrue);
      expect(img.isText, isFalse);
      expect(img.hasMedia, isTrue);

      final txt = ChatMessage.fromMap('m2', {
        'senderId': 'u1', 'text': 'hi', 'type': 'text',
      });
      expect(txt.isText, isTrue);
      expect(txt.hasMedia, isFalse);
    });
  });
}
