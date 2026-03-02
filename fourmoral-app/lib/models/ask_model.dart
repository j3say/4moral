class AskModel {
  final String username;
  final String profilePicture;
  final String mobileNumber;
  final String dateTime;
  final String comment;

  AskModel(
    this.username,
    this.profilePicture,
    this.mobileNumber,
    this.dateTime,
    this.comment,
  );
}

class RecordingModel {
  bool? isRecording;
  String? name;
  String? url;
  bool isPlay;
  int recordDuration;

  RecordingModel({this.isRecording, this.name, required this.isPlay, this.url,required this.recordDuration});

  Map<String, dynamic> toMap() {
    return {
      'isRecording': isRecording,
      'name': name,
      'url': url,
      'isPlay': isPlay,
      'recordDuration' : recordDuration
    };
  }
}
