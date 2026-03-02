String contactsString = "";

class ContactsModel {
  final String name;
  final String username;
  final String profilePicture;
  final String mobileNumber;
  final String uniqueId;
  final bool isSelected;

  ContactsModel(
    this.name,
    this.username,
    this.profilePicture,
    this.mobileNumber,
    this.uniqueId, {
    this.isSelected = false,
  });

  ContactsModel copyWith({
    String? name,
    String? username,
    String? profilePicture,
    String? mobileNumber,
    String? uniqueId,
    bool? isSelected,
    String? contactsString,
  }) {
    return ContactsModel(
      name ?? this.name,
      username ?? this.username,
      profilePicture ?? this.profilePicture,
      mobileNumber ?? this.mobileNumber,
      uniqueId ?? this.uniqueId,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'profilePicture': profilePicture,
      'mobileNumber': mobileNumber,
      'uniqueId': uniqueId,
      'isSelected': isSelected,
    };
  }

  factory ContactsModel.fromJson(Map<String, dynamic> json) {
    return ContactsModel(
      json['name'] ?? '',
      json['username'] ?? '',
      json['profilePicture'] ?? '',
      json['mobileNumber'] ?? '',
      json['uniqueId'] ?? '',
      isSelected: json['isSelected'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactsModel &&
          runtimeType == other.runtimeType &&
          mobileNumber == other.mobileNumber;

  @override
  int get hashCode => mobileNumber.hashCode;
}
