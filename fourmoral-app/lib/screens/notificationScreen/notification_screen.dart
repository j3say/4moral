// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/notificationScreen/notification_services.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';
import '../../models/notification_model.dart';
import '../../widgets/box_shadow.dart';
import '../homePageScreen/home_page_widgets.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  _NotificationScreenState();

  DatabaseReference refNotification = FirebaseDatabase.instance
      .ref()
      .child('Users/')
      .child(profileDataModel?.mobileNumber ?? "")
      .child('Notifications');

  getNotifications() {
    if (!notificationFetched) {
      refNotification.onValue.listen((event) {
        notificationList.clear();
        Map<dynamic, dynamic>? notificationValues =
            event.snapshot.value as Map?;
        if (notificationValues != null) {
          notificationValues.forEach((notificationKey, notificationValues) {
            notificationList.add(
              notificationServices(notificationKey, notificationValues)!,
            );
          });
        }

        notificationList.sort((a, b) {
          return DateTime.parse(b.time).compareTo(DateTime.parse(a.time));
        });

        if (mounted) {
          setState(() {
            notificationFetched = true;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getNotifications();
  }

  bool _announcementsExpanded = true;
  bool _prayersExpanded = true;
  bool _showAllNotifications = true;

  void _handleFollowRequest(
    NotificationModel notification,
    bool isAccepted,
  ) async {
    try {
      // Get the current user's document
      final currentUserDoc =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('mobileNumber', isEqualTo: profileDataModel?.mobileNumber)
              .limit(1)
              .get();

      if (currentUserDoc.docs.isEmpty) return;

      // Update requestList by removing the requester's mobile number
      await currentUserDoc.docs.first.reference.update({
        'requestList': FieldValue.arrayRemove([notification.mobileNumber]),
      });

      if (isAccepted) {
        // Add to followers list if accepted
        String currentFollowMentors =
            currentUserDoc.docs.first.get('followMentors') ?? "";
        String updatedFollowMentors =
            "$currentFollowMentors${notification.mobileNumber}//";

        await currentUserDoc.docs.first.reference.update({
          'followMentors': updatedFollowMentors,
        });

        // Also update the requester's following list
        final requesterDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .where('mobileNumber', isEqualTo: notification.mobileNumber)
                .limit(1)
                .get();

        if (requesterDoc.docs.isNotEmpty) {
          String currentFollowing =
              requesterDoc.docs.first.get('followMentors') ?? "";
          String updatedFollowing =
              "$currentFollowing${profileDataModel?.mobileNumber}//";

          await requesterDoc.docs.first.reference.update({
            'followMentors': updatedFollowing,
          });
        }
      }

      // Update the notification status in Realtime Database
      await refNotification.child(notification.key).update({
        'status': isAccepted ? 'accepted' : 'rejected',
      });

      // Send a notification back to the requester
      FirebaseDatabase.instance
          .ref()
          .child('Users/')
          .child('${notification.mobileNumber}/Notifications/')
          .push()
          .set({
            "type":
                isAccepted ? "followRequestAccepted" : "followRequestRejected",
            "mobileNumber": profileDataModel?.mobileNumber,
            "time": DateTime.now().toString(),
            "profilePicture": profileDataModel?.profilePicture,
            "username": profileDataModel?.username,
          });

      setState(() {
        notificationList.removeWhere((n) => n.key == notification.key);
      });
    } catch (e) {
      print("Error handling follow request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    final announcements =
        notificationList.where((n) => n.type == "announcement").toList();
    final prayers = notificationList.where((n) => n.type == "prayer").toList();
    final followRequests =
        notificationList.where((n) => n.type == "followRequest").toList();
    final otherNotifications =
        notificationList
            .where((n) => n.type != "announcement" && n.type != "prayer")
            .toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showAllNotifications ? Icons.filter_list : Icons.list),
            onPressed: () {
              setState(() {
                _showAllNotifications = !_showAllNotifications;
              });
            },
            tooltip: _showAllNotifications ? 'Filter' : 'Show all',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await getNotifications();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              if (_showAllNotifications) ...[
                if (announcements.isNotEmpty)
                  _buildSectionHeader(
                    context,
                    'Announcements',
                    announcements.length,
                    Icons.announcement,
                    _announcementsExpanded,
                    () {
                      setState(() {
                        _announcementsExpanded = !_announcementsExpanded;
                      });
                    },
                  ),
                if (announcements.isNotEmpty && _announcementsExpanded)
                  _buildNotificationList(height, width, announcements),

                if (prayers.isNotEmpty)
                  _buildSectionHeader(
                    context,
                    'Prayers',
                    prayers.length,
                    Icons.person_pin,
                    _prayersExpanded,
                    () {
                      setState(() {
                        _prayersExpanded = !_prayersExpanded;
                      });
                    },
                  ),
                if (prayers.isNotEmpty && _prayersExpanded)
                  _buildNotificationList(height, width, prayers),

                if (followRequests.isNotEmpty)
                  _buildSectionHeader(
                    context,
                    'Follow Requests',
                    followRequests.length,
                    Icons.person_add,
                    true,
                    null,
                  ),
                if (followRequests.isNotEmpty)
                  _buildNotificationList(height, width, followRequests),

                if (otherNotifications.isNotEmpty)
                  _buildSectionHeader(
                    context,
                    'Other Notifications',
                    otherNotifications.length,
                    Icons.notifications,
                    true,
                    null,
                  ),
                if (otherNotifications.isNotEmpty)
                  _buildNotificationList(height, width, otherNotifications),
              ] else ...[
                // Filtered view
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Wrap(
                    spacing: 8.0,
                    children: [
                      _buildFilterChip('All', Icons.all_inclusive, () {
                        setState(() {
                          _showAllNotifications = true;
                        });
                      }),
                      _buildFilterChip('Announcements', Icons.announcement, () {
                        setState(() {
                          _showAllNotifications = false;
                          _announcementsExpanded = true;
                        });
                      }),
                      _buildFilterChip('Prayers', Icons.person_pin, () {
                        setState(() {
                          _showAllNotifications = false;
                          _prayersExpanded = true;
                        });
                      }),
                      _buildFilterChip('Requests', Icons.person_add, () {
                        setState(() {
                          _showAllNotifications = false;
                        });
                      }),
                    ],
                  ),
                ),
                if (!_showAllNotifications) ...[
                  if (_announcementsExpanded && announcements.isNotEmpty)
                    _buildNotificationList(height, width, announcements),
                  if (_prayersExpanded && prayers.isNotEmpty)
                    _buildNotificationList(height, width, prayers),
                  if (followRequests.isNotEmpty)
                    _buildNotificationList(height, width, followRequests),
                ],
              ],
              if (notificationList.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: height * 0.3),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When you get notifications, they\'ll appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    bool isExpanded,
    VoidCallback? onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$title ($count)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  Widget _buildNotificationList(
    double height,
    double width,
    List<NotificationModel> notifications,
  ) {
    return Column(
      children:
          notifications.map((notification) {
            return _buildNotificationItem(height, width, notification);
          }).toList(),
    );
  }

  Widget _buildNotificationItem(
    double height,
    double width,
    NotificationModel notification,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationAvatar(height, width, notification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNotificationContent(notification),
                        const SizedBox(height: 8),
                        _buildNotificationTime(notification.time),
                        if (notification.type == "followRequest" &&
                            notification.status == "pending")
                          _buildFollowRequestActions(notification),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationAvatar(
    double height,
    double width,
    NotificationModel notification,
  ) {
    if (notification.profilePicture.isNotEmpty) {
      return profileImageWidget(height, width, notification.profilePicture);
    } else {
      IconData icon;
      Color bgColor;

      switch (notification.type) {
        case "announcement":
          icon = Icons.announcement;
          bgColor = Colors.orange[100]!;
          break;
        case "prayer":
          icon = Icons.person_pin;
          bgColor = Colors.purple[100]!;
          break;
        case "followRequest":
          icon = Icons.person_add;
          bgColor = Colors.blue[100]!;
          break;
        case "postLike":
          icon = Icons.favorite;
          bgColor = Colors.red[100]!;
          break;
        case "postComment":
          icon = Icons.comment;
          bgColor = Colors.green[100]!;
          break;
        default:
          icon = Icons.notifications;
          bgColor = Colors.grey[200]!;
      }

      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.grey[800], size: 24),
      );
    }
  }

  Widget _buildNotificationContent(NotificationModel notification) {
    switch (notification.type) {
      case "postAsk":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' asked on your post'),
            ],
          ),
        );
      case "postAskReply":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' replied on your question'),
            ],
          ),
        );
      case "postComment":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' commented on your post: '),
              TextSpan(
                text: '"${notification.comment}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      case "postLike":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' liked your post'),
            ],
          ),
        );
      case "followRequest":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' wants to follow you'),
            ],
          ),
        );
      case "followMentor":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' started following you'),
            ],
          ),
        );
      case "announcement":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.username,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              notification.message.isNotEmpty
                  ? notification.message
                  : 'New announcement posted',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        );
      case "message":
        return RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: notification.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' messaged you: '),
              TextSpan(
                text: notification.message,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      default:
        return Text(notification.message, style: const TextStyle(fontSize: 14));
    }
  }

  Widget _buildNotificationTime(String timeString) {
    final dateTime = DateTime.parse(timeString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String timeText;
    if (difference.inDays > 7) {
      timeText = DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 0) {
      timeText = '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      timeText = '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      timeText = '${difference.inMinutes}m ago';
    } else {
      timeText = 'Just now';
    }

    return Text(
      timeText,
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );
  }

  Widget _buildFollowRequestActions(NotificationModel notification) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              _handleFollowRequest(notification, true);
            },
            child: const Text('Accept'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              _handleFollowRequest(notification, false);
            },
            child: const Text('Decline'),
          ),
        ),
      ],
    );
  }
}
