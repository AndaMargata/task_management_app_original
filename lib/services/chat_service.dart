import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_user.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';

class ChatService {
  static final _firestore = FirebaseFirestore.instance;

  /// Creates / updates the user profile doc at `users/{uid}`.
  /// Uses set-with-merge so it works even offline (Firestore queues the write)
  /// and is idempotent on every login.
  static Future<void> ensureUserProfile(
    String userId,
    String email, {
    String firstName = '',
    String lastName = '',
  }) async {
    try {
      // Check if user doc already has a role (don't overwrite admin)
      final doc = await _firestore.collection('users').doc(userId).get();
      final existingRole = (doc.exists && doc.data() != null) ? doc.data()!['role'] : null;

      final displayName = [firstName, lastName]
              .where((s) => s.trim().isNotEmpty)
              .join(' ')
              .trim();
      final fallbackName =
          displayName.isNotEmpty ? displayName : email.split('@').first;
      await _firestore.collection('users').doc(userId).set(
        {
          'email': email,
          'displayName': fallbackName,
          'firstName': firstName,
          'lastName': lastName,
          'searchName': fallbackName.toLowerCase(),
          'searchEmail': email.toLowerCase(),
          'role': existingRole ?? 'member',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
          'ensureUserProfile OK for $userId (role: ${existingRole ?? 'member'})');
    } catch (e) {
      debugPrint('ensureUserProfile error: $e');
    }
  }

  static Future<ChatUser?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return ChatUser.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  /// Update a user's role. Only callable by admins in practice.
  static Future<void> setUserRole(String userId, String role) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': role,
      });
    } catch (e) {
      debugPrint('setUserRole error: $e');
    }
  }

  /// Prefix-search by email or display name. Excludes current user.
  /// Throws on Firestore errors so callers can display them.
  static Future<List<ChatUser>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.trim().isEmpty) return [];
    final lowerQuery = query.trim().toLowerCase();

    final emailSnap = await _firestore
        .collection('users')
        .where('searchEmail', isGreaterThanOrEqualTo: lowerQuery)
        .where('searchEmail', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
        .limit(10)
        .get();

    final nameSnap = await _firestore
        .collection('users')
        .where('searchName', isGreaterThanOrEqualTo: lowerQuery)
        .where('searchName', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
        .limit(10)
        .get();

    final Map<String, ChatUser> users = {};
    for (final doc in [...emailSnap.docs, ...nameSnap.docs]) {
      if (doc.id != currentUserId) {
        users[doc.id] = ChatUser.fromMap(doc.id, doc.data());
      }
    }
    return users.values.toList();
  }

  /// Return ALL users (except [currentUserId]). Used to show a default list
  /// when the search field is empty.
  static Future<List<ChatUser>> listAllUsers(String currentUserId) async {
    final snap = await _firestore.collection('users').limit(50).get();
    debugPrint('listAllUsers: found ${snap.docs.length} docs in users collection');
    return snap.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => ChatUser.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Deterministic conversation ID for any two users.
  static String conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Real-time stream of conversations where [userId] is a participant.
  static Stream<List<Conversation>> conversationsStream(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => Conversation.fromMap(doc.id, doc.data()))
          .toList();
      // Sort client-side to avoid needing a Firestore composite index
      list.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime(2000);
        final bTime = b.lastMessageTime ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Creates a new conversation. Returns the local [Conversation] object.
  /// Assumes the caller has already checked that no existing conversation
  /// exists (e.g. from the local conversations list).
  static Future<Conversation?> createConversation({
    required String currentUserId,
    required String currentUserName,
    required String currentUserEmail,
    required String otherUserId,
    required String otherUserName,
    required String otherUserEmail,
  }) async {
    try {
      final id = conversationId(currentUserId, otherUserId);

      final conversation = Conversation(
        id: id,
        participants: [currentUserId, otherUserId],
        participantNames: {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        participantEmails: {
          currentUserId: currentUserEmail,
          otherUserId: otherUserEmail,
        },
        unread: {currentUserId: 0, otherUserId: 0},
      );

      await _firestore
          .collection('conversations')
          .doc(id)
          .set(conversation.toMap());
      return conversation;
    } catch (e) {
      debugPrint('createConversation error: $e');
      return null;
    }
  }

  /// Real-time ordered stream of messages in a conversation.
  static Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Sends a message and updates conversation metadata in a single batch.
  /// Supports text, image, video, and audio messages via [type] and [mediaUrl].
  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    required String recipientId,
    String type = 'text',
    String? mediaUrl,
    int? mediaDuration,
  }) async {
    try {
      final batch = _firestore.batch();

      final msgRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      final msgData = <String, dynamic>{
        'senderId': senderId,
        'text': text,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (mediaUrl != null) msgData['mediaUrl'] = mediaUrl;
      if (mediaDuration != null) msgData['mediaDuration'] = mediaDuration;

      batch.set(msgRef, msgData);

      String preview;
      switch (type) {
        case 'image':
          preview = '📷 Photo';
          break;
        case 'video':
          preview = '🎥 Video';
          break;
        case 'audio':
          preview = '🎤 Voice message';
          break;
        default:
          preview = text;
      }

      final convRef =
          _firestore.collection('conversations').doc(conversationId);
      batch.update(convRef, {
        'lastMessage': preview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unread.$recipientId': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
  }

  /// Resets unread counter for [userId] in [conversationId].
  static Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'unread.$userId': 0,
      });
    } catch (e) {
      debugPrint('markConversationAsRead error: $e');
    }
  }
}

