// If you don't already have this class defined, you need to add it
// Create a file called group_user.dart in your models directory

class GroupUser {
  final String id;
  final String name;
  final String profilePicture;
  final List<String> groups;
  final String emailAddress;
  final String mobileNumber;
  // Add other necessary user properties

  GroupUser({
    required this.id,
    required this.name,
    this.profilePicture = '',
    this.groups = const [],
    this.emailAddress = '',
    this.mobileNumber = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
      'groups': groups,
      'emailAddress': emailAddress,
      'mobileNumber': mobileNumber,
    };
  }

  factory GroupUser.fromMap(Map<String, dynamic> map) {
    // Handle the case where the ID might be in different locations
    String getUserId(Map<String, dynamic> map) {
      if (map.containsKey('id')) return map['id'].toString();
      if (map.containsKey('uid')) return map['uid'].toString();
      if (map.containsKey('userId')) return map['userId'].toString();
      return '';
    }

    // Handle the case where name might be in different fields
    String getUserName(Map<String, dynamic> map) {
      if (map.containsKey('name')) return map['name'].toString();
      if (map.containsKey('displayName')) return map['displayName'].toString();
      if (map.containsKey('fullName')) return map['fullName'].toString();
      return '';
    }

    // Handle the case where profile picture URL might be in different fields
    String getProfilePicUrl(Map<String, dynamic> map) {
      if (map.containsKey('profilePicture')) return map['profilePicture'].toString();
      if (map.containsKey('photoUrl')) return map['photoUrl'].toString();
      if (map.containsKey('avatar')) return map['avatar'].toString();
      if (map.containsKey('profilePic')) return map['profilePic'].toString();
      return '';
    }

    // Parse groups list
    List<String> parseGroups(dynamic groupsData) {
      if (groupsData == null) return [];
      if (groupsData is List) {
        return groupsData.map((group) => group.toString()).toList();
      }
      return [];
    }

    return GroupUser(
      id: getUserId(map),
      name: getUserName(map),
      profilePicture: getProfilePicUrl(map),
      groups: parseGroups(map['groups']),
      emailAddress: map['emailAddress']?.toString() ?? '',
      mobileNumber: map['mobileNumber']?.toString() ?? map['phoneNumber']?.toString() ?? '',
    );
  }
}