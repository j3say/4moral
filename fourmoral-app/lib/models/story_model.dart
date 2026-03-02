class HomePageStoryModel {
  final String mobileNumber;
  final String profilePicture;
  final String username;

  HomePageStoryModel(
    this.mobileNumber,
    this.profilePicture,
    this.username,
  );
}

class ProfilePageStoryModel {
  final String key;
  final String thumbnail;
  final String caption;

  ProfilePageStoryModel(
    this.key,
    this.thumbnail,
    this.caption,
  );
}

class StoryModel {
  final String keyDatabase;
  final String key;
  final String dateTime;
  final String caption;
  final String mobileNumber;
  final String profilePicture;
  final String thumbnail;
  final String type;
  final String actype;
  final String url;
  final String username;
  final String category;

  StoryModel(
    this.keyDatabase,
    this.key,
    this.dateTime,
    this.caption,
    this.mobileNumber,
    this.profilePicture,
    this.thumbnail,
    this.type,
    this.actype,
    this.url,
    this.username,
    this.category,
  );
}

List<HomePageStoryModel> homepageStoryDataList = [];
Map? valuesStory;
