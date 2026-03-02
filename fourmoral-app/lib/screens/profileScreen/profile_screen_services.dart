import '../../models/user_profile_post_model.dart';

UserProfilePostModel userProfilePostPhotoDataServices(value) {
  return UserProfilePostModel(
    value.get('key')?.toString() ?? "",
    value.get('dateTime')?.toString() ?? "",
    value.get('thumbnails').toList().first ?? "",
    value.get('mediaTypes')?.toList().first ?? "",
    value.get('urls')?.toList().length.toString() ?? "",
  );
}

UserProfilePostModel userProfilePostVideoDataServices(value) {
  String thumbnail = "";
  try {
    thumbnail = value.get('thumbnails').toList().first ?? "";
  } catch (e) {
    thumbnail = "";
  }
  return UserProfilePostModel(
    value.get('key')?.toString() ?? "",
    value.get('dateTime')?.toString() ?? "",
    thumbnail,
    value.get('type')?.toString() ?? "",
    value.get('urls')?.toList().length.toString() ?? "",
  );
}
