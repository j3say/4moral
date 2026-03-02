import '../../models/notification_model.dart';

NotificationModel? notificationServices(notificationKey, notificationValue) {
  NotificationModel? temp;

  if (notificationValue['type'] == "postAsk") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      notificationValue['comment'],
      notificationValue['time'],
      notificationValue['url'],
      notificationValue['postId'],
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      "",
    );
  } else if (notificationValue['type'] == "postAskReply") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      notificationValue['comment'],
      notificationValue['time'],
      notificationValue['url'],
      notificationValue['postId'],
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      "",
    );
  } else if (notificationValue['type'] == "postComment") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      notificationValue['comment'],
      notificationValue['time'],
      notificationValue['url'],
      notificationValue['postId'],
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",

      "",
    );
  } else if (notificationValue['type'] == "postLike") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      notificationValue['url'],
      notificationValue['postId'],
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      "",
    );
  } else if (notificationValue['type'] == "followMentor") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      "",
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      "",
    );
  } else if (notificationValue['type'] == "message") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      "",
      "",
      "",
      notificationValue['message'],
      "",
    );
  } else if (notificationValue['type'] == "announcement") {
    // New announcement notification type
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      notificationValue['announcementId'], // Store the announcement ID
      notificationValue['profilePicture'],
      notificationValue['title'], // Announcement title in username field
      notificationValue['message'],
      "",
    );
  } else if (notificationValue['type'] == "prayer") {
    // New announcement notification type
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      notificationValue['prayerId'], // Store the announcement ID
      notificationValue['profilePicture'],
      notificationValue['title'], // Announcement title in username field
      notificationValue['message'],
      "",
    );
  } else if (notificationValue['type'] == "followRequest") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      "",
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      notificationValue['status'] ?? "pending",
    );
  } else if (notificationValue['type'] == "followRequestAccepted") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      "",
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      "Your follow request was accepted",
    );
  } else if (notificationValue['type'] == "followRequestRejected") {
    temp = NotificationModel(
      notificationKey,
      notificationValue['type'],
      notificationValue['mobileNumber'],
      "",
      notificationValue['time'],
      "",
      "",
      notificationValue['profilePicture'],
      notificationValue['username'],
      "",
      "Your follow request was declined",
    );
  }

  return temp;
}
