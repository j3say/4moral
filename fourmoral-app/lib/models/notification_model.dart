class NotificationModel {
  final String key;
  final String type;
  final String mobileNumber;
  final String comment;
  final String time;
  final String url;
  final String postId;
  final String profilePicture;
  final String username;
  final String message;
  final String status;

  NotificationModel(
    this.key,
    this.type,
    this.mobileNumber,
    this.comment,
    this.time,
    this.url,
    this.postId,
    this.profilePicture,
    this.username,
    this.message,
    this.status,
  );
}

var notificationFetched = false;
List<NotificationModel> notificationList = [];
