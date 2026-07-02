import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String role; // 'admin' or 'member'
  final DateTime? createdAt;

  ChatUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.role = 'member',
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : displayName;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'searchName': displayName.toLowerCase(),
      'searchEmail': email.toLowerCase(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory ChatUser.fromMap(String uid, Map<String, dynamic> map) {
    return ChatUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
