import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// The conversation currently being viewed (suppress notifications for it).
  static String? _activeConversationId;

  /// Callback invoked when user taps a notification. Payload = conversationId.
  static void Function(String? conversationId)? onNotificationTap;

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleTap,
    );

    // Request POST_NOTIFICATIONS permission on Android 13+
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  static void _handleTap(NotificationResponse response) {
    onNotificationTap?.call(response.payload);
  }

  /// Call when the user opens / closes a conversation to suppress duplicates.
  static void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  /// Shows a local notification for a new chat message.
  /// Skipped if the message's conversation is currently being viewed.
  static Future<void> showMessageNotification({
    required String title,
    required String body,
    String? conversationId,
  }) async {
    if (conversationId != null && conversationId == _activeConversationId) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: conversationId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: details,
      payload: conversationId,
    );
  }

  /// Shows a local notification for task events (assignment, status changes).
  static Future<void> showTaskNotification({
    required String title,
    required String body,
    String? taskId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_updates',
      'Task Updates',
      channelDescription: 'Notifications for task assignments and status changes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: taskId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'task:$taskId',
    );
  }
}
