class ProfileModel {
  final String mobileNumber;
  final String profilePicture;
  final String username;
  final String type;
  final String bio;
  final String uniqueId;
  final String name;
  final String age;
  final String gender;
  final String address;
  final String emailAddress;
  final String religion;
  String followMentors;
  String likePosts;
  String savedPosts;
  String watchLater;
  String block;
  final bool verified;
  final bool privateAccount;
  final bool contactAccount;
  final List recording;
  final String uId;

  ProfileModel(
    this.mobileNumber,
    this.profilePicture,
    this.username,
    this.type,
    this.bio,
    this.uniqueId,
    this.name,
    this.age,
    this.gender,
    this.address,
    this.emailAddress,
    this.religion,
    this.followMentors,
    this.likePosts,
    this.savedPosts,
    this.watchLater,
    this.block,
    this.verified,
    this.privateAccount,
    this.recording,
    this.uId,
    this.contactAccount,
  );

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      map['mobileNumber'] ?? '',
      map['profilePicture'] ?? '',
      map['username'] ?? '',
      map['accountType'] ?? map['type'] ?? 'Standard', 
      map['bio'] ?? '',
      map['uniqueId'] ?? '',
      map['name'] ?? '',
      map['age']?.toString() ?? '',
      map['gender'] ?? '',
      map['address'] ?? '',
      map['emailAddress'] ?? '',
      map['religion'] ?? '',
      '', '', '', '', '', 
      map['isVerified'] ?? false,
      map['isPrivateAccount'] ?? false,
      map['recording'] ?? [],
      map['_id'] ?? '',
      map['contactOnlyMode'] ?? false,
    );
  }

  String get accountType => type;
}

ProfileModel? profileDataModel;
