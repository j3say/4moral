import '../../models/search_users_model.dart';

SearchModel searchUserDataServices(value) {
  SearchModel temp;
  temp = SearchModel(
    '${value.get('mobileNumber')}'.toString() != "null"
        ? '${value.get('mobileNumber')}'.toString()
        : "",
    '${value.get('profilePicture')}'.toString() != "null"
        ? '${value.get('profilePicture')}'.toString()
        : "",
    '${value.get('username')}'.toString() != "null"
        ? '${value.get('username')}'.toString()
        : "",
    '${value.get('type')}'.toString() != "null"
        ? '${value.get('type')}'.toString()
        : "",
    '${value.get('uniqueId')}'.toString() != "null"
        ? '${value.get('uniqueId')}'.toString()
        : "",
  );
  return temp;
}
