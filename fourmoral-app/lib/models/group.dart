import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/models/group_member.dart';

class Group {
  final String id;
  final String name;
  String? description;
  final String groupPicUrl;
  final String createdBy;
  final DateTime createdAt;
  final List<GroupMember> members;
  final List<String> memberIds;
  final bool isPublic;
  final String adminUid;
  final bool adminOnlyChat;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.groupPicUrl = '',
    required this.createdBy,
    required this.createdAt,
    this.members = const [],
    required this.memberIds,
    this.isPublic = true,
    required this.adminUid,
    this.adminOnlyChat = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'groupPicUrl': groupPicUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members.map((member) => member.toMap()).toList(),

      'isPublic': isPublic,
      'adminUid': adminUid,
      'adminOnlyChat': adminOnlyChat,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map, [String? id]) {
    // Handle DateTime parsing
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      try {
        if (value is String) return DateTime.parse(value);
      } catch (_) {}
      return DateTime.now();
    }

    // Handle members list parsing
    List<GroupMember> parseMembers(dynamic membersData) {
      if (membersData == null) return [];
      if (membersData is! List) return [];

      return membersData.map((member) {
        try {
          return member is Map<String, dynamic>
              ? GroupMember.fromMap(member)
              : GroupMember(
                userId: '',
                role: MemberRole.normal,
                joinedAt: DateTime.now(),
              );
        } catch (e) {
          return GroupMember(
            userId: '',
            role: MemberRole.normal,
            joinedAt: DateTime.now(),
          );
        }
      }).toList();
    }

    return Group(
      id: id ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      groupPicUrl: map['groupPicUrl']?.toString() ?? '',
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: parseDateTime(map['createdAt']),
      members: parseMembers(map['members']),
      memberIds: List<String>.from(map['memberIds'] ?? []),
      isPublic: map['isPublic'] == true,
      adminUid: map['adminUid']?.toString() ?? '',
      adminOnlyChat: map['adminOnlyChat'] == true,
    );
  }
}
