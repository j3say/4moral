class UserModel {
  final String id;
  final String mobileNumber;
  String? username;
  String? bio;
  int? age;
  String? accountType;
  bool profileCompleted;

  UserModel({
    required this.id,
    required this.mobileNumber,
    this.username,
    this.bio,
    this.age,
    this.accountType,
    this.profileCompleted = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['_id'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      username: map['username'],
      bio: map['bio'],
      age: map['age'],
      accountType: map['accountType'],
      profileCompleted: map['profileCompleted'] ?? false,
    );
  }
}