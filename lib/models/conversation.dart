import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantEmails;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unread;

  Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantEmails,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.unread = const {},
  });

  int unreadCountFor(String userId) => unread[userId] ?? 0;

  String otherParticipantName(String currentUserId) {
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return participantNames[otherId] ?? 'Unknown';
  }

  String otherParticipantEmail(String currentUserId) {
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return participantEmails[otherId] ?? '';
  }

  String otherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantEmails': participantEmails,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unread': unread,
    };
  }

  factory Conversation.fromMap(String id, Map<String, dynamic> map) {
    return Conversation(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      participantNames:
          Map<String, String>.from(map['participantNames'] ?? {}),
      participantEmails:
          Map<String, String>.from(map['participantEmails'] ?? {}),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: map['lastMessageSenderId'] as String? ?? '',
      unread: (map['unread'] is Map)
          ? (map['unread'] as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
            )
          : {},
    );
  }
}
