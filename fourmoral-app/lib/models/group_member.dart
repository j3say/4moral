// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

enum MemberRole { admin, normal }

class GroupMember {
  final String userId;
  final MemberRole role;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role.toString().split('.').last,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    // Handle the case where joinedAt might be different types
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is DateTime) {
        return value;
      } else {
        return DateTime.now(); // Fallback
      }
    }

    // Parse role from string
    MemberRole parseRole(dynamic roleValue) {
      if (roleValue is String && roleValue == 'admin') {
        return MemberRole.admin;
      }
      return MemberRole.normal;
    }

    return GroupMember(
      userId: map['userId'] ?? '',
      role: parseRole(map['role']),
      joinedAt: map['joinedAt'] != null 
          ? parseDateTime(map['joinedAt'])
          : DateTime.now(),
    );
  }
}