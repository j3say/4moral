class SearchModel {
  final String mobileNumber;
  final String profilePicture;
  final String username;
  final String type;
  final String uniqueId;

  SearchModel(
    this.mobileNumber,
    this.profilePicture,
    this.username,
    this.type,
    this.uniqueId,
  );
}

var searchUserDataFetched = false;
List<SearchModel> searchUserDataList = [];
