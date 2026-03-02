class PostModel {
  final String key;
  final String caption;
  final String dateTime;
  final String mobileNumber;
  final String profilePicture;
  final List<String> thumbnail;
  final String type;
  final String actype;
  final List<String> urls;
  final List<String> mediaTypes; // New field
  final String username;
  var numberOfLikes;
  String likesUsers;
  String postCategory;
  final bool hasLocation;
  final double? latitude;
  final double? longitude;

  PostModel({
    this.key = "",
    this.caption = "",
    this.dateTime = "",
    this.mobileNumber = "",
    this.profilePicture = "",
    required this.thumbnail,
    this.type = "",
    this.actype = "",
    required this.urls,
    required this.mediaTypes,
    this.username = "",
    this.numberOfLikes,
    this.likesUsers = "",
    this.postCategory = "",
    this.hasLocation = false,
    this.latitude,
    this.longitude,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      key: json['key'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      dateTime: json['dateTime'] ?? "",
      mobileNumber: json['mobileNumber'] as String? ?? '',
      profilePicture: json['profilePicture'] as String? ?? '',
      thumbnail: (json['thumbnails'] as List<dynamic>?)?.cast<String>() ?? [],
      type: json['type'] as String? ?? '',
      actype: json['actype'] as String? ?? '',
      urls: (json['urls'] as List<dynamic>?)?.cast<String>() ?? [],
      mediaTypes: (json['mediaTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      username: json['username'] as String? ?? '',
      numberOfLikes: (json['numberOfLikes'] as num?)?.toInt() ?? 0,
      likesUsers: json['likesUsers'] as String? ?? '',
      postCategory: json['postCategory'] as String? ?? '',
      hasLocation: json['hasLocation'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }


}
