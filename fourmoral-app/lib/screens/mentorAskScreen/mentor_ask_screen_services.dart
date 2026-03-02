import '../../models/ask_mentor_model.dart';

AskMentorModel askMentorServicesDataServices(key, value) {
  AskMentorModel temp;
  temp = AskMentorModel(
    '${value.get('username')}'.toString() != "null"
        ? '${value.get('username')}'.toString()
        : "",
    '${value.get('profilePicture')}'.toString() != "null"
        ? '${value.get('profilePicture')}'.toString()
        : "",
    key.toString() != "null" ? key.toString() : "",
  );
  return temp;
}
