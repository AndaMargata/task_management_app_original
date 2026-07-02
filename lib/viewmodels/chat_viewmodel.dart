import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';

class ChatViewmodel extends ChangeNotifier {
  String? _currentUserId;
  List<Conversation> _conversations = [];
  List<ChatMessage> _currentMessages = [];
  String? _activeConversationId;

  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _messagesSubscription;

  /// Tracks last-known message timestamps so we only notify on *new* messages.
  final Map<String, DateTime> _lastKnownMessageTimes = {};

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  List<ChatMessage> get currentMessages => List.unmodifiable(_currentMessages);
  String? get activeConversationId => _activeConversationId;
  String? get currentUserId => _currentUserId;

  int get totalUnreadCount {
    if (_currentUserId == null) return 0;
    return _conversations.fold(
      0,
      (sum, c) => sum + c.unreadCountFor(_currentUserId!),
    );
  }

  Future<void> bindToUser(String userId) async {
    if (_currentUserId == userId && _conversationsSubscription != null) return;

    await unbindUser();
    _currentUserId = userId;

    _conversationsSubscription =
        ChatService.conversationsStream(userId).listen(
      (conversations) {
        for (final conv in conversations) {
          final lastKnown = _lastKnownMessageTimes[conv.id];
          if (lastKnown != null &&
              conv.lastMessageTime != null &&
              conv.lastMessageTime!.isAfter(lastKnown) &&
              conv.lastMessageSenderId != _currentUserId &&
              conv.id != _activeConversationId) {
            NotificationService.showMessageNotification(
              title: conv.otherParticipantName(_currentUserId!),
              body: conv.lastMessage,
              conversationId: conv.id,
            );
          }
          if (conv.lastMessageTime != null) {
            _lastKnownMessageTimes[conv.id] = conv.lastMessageTime!;
          }
        }

        _conversations = conversations;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Conversations stream error: $error');
      },
    );
  }

  Future<void> unbindUser() async {
    await _conversationsSubscription?.cancel();
    await _messagesSubscription?.cancel();
    _conversationsSubscription = null;
    _messagesSubscription = null;
    _currentUserId = null;
    _activeConversationId = null;
    _conversations = [];
    _currentMessages = [];
    _lastKnownMessageTimes.clear();
    notifyListeners();
  }

  /// Subscribe to the message stream for [conversationId] and mark it as read.
  void openConversation(String conversationId) {
    _activeConversationId = conversationId;
    NotificationService.setActiveConversation(conversationId);

    _messagesSubscription?.cancel();
    _messagesSubscription =
        ChatService.messagesStream(conversationId).listen(
      (messages) {
        _currentMessages = messages;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Messages stream error: $error');
      },
    );

    if (_currentUserId != null) {
      ChatService.markConversationAsRead(
        conversationId: conversationId,
        userId: _currentUserId!,
      );
    }
  }

  void closeConversation() {
    _activeConversationId = null;
    NotificationService.setActiveConversation(null);
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _currentMessages = [];
    // Defer notification — this is often called from dispose() during a
    // locked build phase, where notifyListeners() would throw.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> sendMessage(String text, {
    String type = 'text',
    String? mediaUrl,
    int? mediaDuration,
  }) async {
    if (_currentUserId == null || _activeConversationId == null) return;
    if (text.trim().isEmpty && mediaUrl == null) return;

    final conversation = _conversations.cast<Conversation?>().firstWhere(
      (c) => c!.id == _activeConversationId,
      orElse: () => null,
    );
    if (conversation == null) return;

    final recipientId = conversation.otherParticipantId(_currentUserId!);

    await ChatService.sendMessage(
      conversationId: _activeConversationId!,
      senderId: _currentUserId!,
      text: text.trim(),
      recipientId: recipientId,
      type: type,
      mediaUrl: mediaUrl,
      mediaDuration: mediaDuration,
    );
  }

  /// Opens (or creates) a 1-on-1 conversation with [otherUser].
  /// Returns the conversation ID.
  Future<String?> startConversation(ChatUser otherUser) async {
    if (_currentUserId == null) return null;

    final existingId = ChatService.conversationId(_currentUserId!, otherUser.uid);
    final existing = _conversations.cast<Conversation?>().firstWhere(
      (c) => c!.id == existingId,
      orElse: () => null,
    );
    if (existing != null) return existing.id;

    try {
      final currentProfile =
          await ChatService.getUserProfile(_currentUserId!);
      if (currentProfile == null) return null;

      final conversation = await ChatService.createConversation(
        currentUserId: _currentUserId!,
        currentUserName: currentProfile.displayName,
        currentUserEmail: currentProfile.email,
        otherUserId: otherUser.uid,
        otherUserName: otherUser.displayName,
        otherUserEmail: otherUser.email,
      );
      return conversation?.id;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      return null;
    }
  }

  Future<List<ChatUser>> searchUsers(String query) async {
    if (_currentUserId == null) return [];
    return await ChatService.searchUsers(query, _currentUserId!);
  }

  /// Lists all registered users except self.
  Future<List<ChatUser>> listAllUsers() async {
    if (_currentUserId == null) return [];
    return await ChatService.listAllUsers(_currentUserId!);
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
