class UserProfileStoryModel {
  final String key;
  final String dateTime;
  final String thumbnail;
  final String type;

  UserProfileStoryModel(
    this.key,
    this.dateTime,
    this.thumbnail,
    this.type,
  );
}

var userProfileStoryDataFetched = false;
List<UserProfileStoryModel> userProfileStoryDataList = [];
