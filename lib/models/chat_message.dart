import 'package:cloud_firestore/cloud_firestore.dart';

/// The kind of content a chat message carries.
class MessageType {
  static const String text = 'text';
  static const String image = 'image';
  static const String video = 'video';
  static const String audio = 'audio';
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? timestamp;

  /// One of [MessageType] constants: text, image, video, audio.
  final String type;

  /// Download URL for media (image / video / audio). Null for plain text.
  final String? mediaUrl;

  /// Duration in seconds for audio/video messages. Null for others.
  final int? mediaDuration;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.timestamp,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaDuration,
  });

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
      type: map['type'] as String? ?? MessageType.text,
      mediaUrl: map['mediaUrl'] as String?,
      mediaDuration: map['mediaDuration'] as int?,
    );
  }
}
