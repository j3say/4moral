
class UserProfilePostModel {
  final String key;
  final String dateTime;
  final String thumbnail;
  final String type;
  final String postCount;

  UserProfilePostModel(
    this.key,
    this.dateTime,
    this.thumbnail,
    this.type,
      this.postCount,
  );
}

// State variables
var userLikePostDataFetched = false;
var userSavedPostDataFetched = false;
var userWatchLaterDataFetched = false;
List<UserProfilePostModel> userProfilePostDataVideoList = [];
List<UserProfilePostModel> userLikePostDataPhotoList = [];
List<UserProfilePostModel> userLikePostDataVideoList = [];
List<UserProfilePostModel> userSavedPostDataPhotoList = [];
List<UserProfilePostModel> userSavedPostDataVideoList = [];
List<UserProfilePostModel> userWatchLaterDataPhotoList = [];
List<UserProfilePostModel> userWatchLaterDataVideoList = [];