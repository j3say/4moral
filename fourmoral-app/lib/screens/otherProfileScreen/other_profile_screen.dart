import 'package:audioplayers/audioplayers.dart';
import 'package:auto_size_text/auto_size_text.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/announcement.dart';
import 'package:fourmoral/models/prayer.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/screens/messageScreen/message_screen.dart';
import 'package:fourmoral/screens/otherProfileScreen/other_profile_controller.dart';
import 'package:fourmoral/screens/postViewScreen/post_view_screen.dart';
import 'package:fourmoral/screens/profileScreen/profile_widgets.dart';
import 'package:fourmoral/screens/reportScreen/report_screen.dart';
import 'package:fourmoral/services/announcement_service.dart';
import 'package:fourmoral/services/prayer_service.dart';
import 'package:get/get.dart';

import '../../constants/colors.dart';
import '../../services/set_or_remove_like.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../../widgets/profile_image_widget.dart';

class OtherProfileScreen extends StatefulWidget {
  const OtherProfileScreen({
    super.key,
    this.mobileNumber,
    this.currentUsername,
  });

  final String? mobileNumber;
  final String? currentUsername;

  @override
  _OtherProfileScreenState createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  final otherProfileCnt = Get.put(OtherProfileCnt());
  final _announcementService = AnnouncementService();
  final _prayerService = PrayerService();
  String? _currentlyPlayingId;
  late Stream<List<Announcement>> _announcementsStream;
  late Stream<List<Prayer>> _prayersStream;
  final audioPlayer = AudioPlayer();
  ProfileModel? profileDataModel; // Define profileDataModel

  @override
  void initState() {
    super.initState();
    // Initialize profile data and streams
    otherProfileCnt.getOtherProfileData(mobileNumber: widget.mobileNumber);
    _loadUserProfile(widget.mobileNumber ?? '');
    _announcementService.setupExpirationTask();
    _announcementsStream = _announcementService.getActiveAnnouncementsForUser(
      widget.mobileNumber ?? '',
    );
    _prayerService.setupExpirationTask();
    _prayersStream = _prayerService.getActivePrayersForUser(
      widget.mobileNumber ?? '',
    );
    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentlyPlayingId = null;
      });
    });
  }

  Future<void> _loadUserProfile(String phoneNumber) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('mobileNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          profileDataModel = profileDataServices(snapshot.docs.first);
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _playAudio(
    String id,
    String audioUrl, {
    required bool isRecording,
  }) async {
    try {
      if (_currentlyPlayingId == id) {
        await audioPlayer.stop();
        setState(() {
          _currentlyPlayingId = null;
          if (isRecording) {
            otherProfileCnt.otherProfileDataModel?.recording.forEach(
              (recording) => recording['isPlay'] = false,
            );
          }
        });
      } else {
        await audioPlayer.stop();
        await audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _currentlyPlayingId = id;
          if (isRecording) {
            otherProfileCnt.otherProfileDataModel?.recording.forEach(
              (recording) => recording['isPlay'] = false,
            );
            otherProfileCnt.otherProfileDataModel?.recording.firstWhere(
                  (recording) => recording['url'] == audioUrl,
                )['isPlay'] =
                true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  String _getExpiryText(DateTime expiresAt) {
    final duration = expiresAt.difference(DateTime.now());
    if (duration.inHours > 0) {
      return 'Expires in ${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return 'Expires in ${duration.inMinutes}m';
    } else {
      return 'Expiring soon';
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Obx(() {
      // Check if profile data is fetched
      if (!otherProfileCnt.otherProfileFetched.value ||
          profileDataModel == null) {
        return Scaffold(
          backgroundColor: const Color(0xfff9f6ed),
          appBar: AppBar(title: const Text('Profile'), backgroundColor: blue),
          body: Center(child: buildCPIWidget(height * 0.5, width)),
        );
      }

      final user = otherProfileCnt.otherProfileDataModel;
      final isPrivate = profileDataModel?.privateAccount ?? false;
      final isFollowing =
          profileDataModel?.followMentors.contains(
            otherProfileCnt.otherProfileDataModel?.mobileNumber ?? "",
          ) ??
          false;
      final isBlocked =
          profileDataModel?.block.contains(widget.mobileNumber ?? '') ?? false;

      if (isBlocked) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: blue,
            actions: [
              IconButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isDismissible: true,
                    builder: (BuildContext context) {
                      return SizedBox(
                        height: height * 0.075,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sheetOptions(
                              isBlocked ? "Unblock User" : "Block User",
                              true,
                              () {
                                setBlock(
                                  widget.mobileNumber,
                                  profileDataModel!,
                                  otherProfileCnt.collectionUserReference,
                                  setState,
                                );
                                Navigator.pop(context);
                              },
                              Icons.block,
                              height,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          body: SizedBox(
            height: height,
            width: width,
            child: const Center(
              child: Text("User Blocked", style: TextStyle(fontSize: 16)),
            ),
          ),
        );
      }

      final shouldShowPrivate = (isPrivate && !isFollowing);

      return DefaultTabController(
        length: 3, // Updated to include Stories, Photos, Videos
        child: Scaffold(
          backgroundColor: const Color(0xfff9f6ed),
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: blue,
            actions: [
              IconButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isDismissible: true,
                    builder: (BuildContext context) {
                      return SizedBox(
                        height: height * 0.15,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sheetOptions(
                              isBlocked ? "Unblock User" : "Block User",
                              false,
                              () {
                                setBlock(
                                  widget.mobileNumber,
                                  profileDataModel!,
                                  otherProfileCnt.collectionUserReference,
                                  setState,
                                );
                                Navigator.pop(context);
                              },
                              Icons.block,
                              height,
                            ),
                            sheetOptions(
                              "Report this User",
                              true,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ReportScreen(
                                          postObject: null,
                                          profileObject:
                                              otherProfileCnt
                                                  .otherProfileDataModel,
                                          type: "User",
                                        ),
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              Icons.report,
                              height,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  color: blue,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  user?.name ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 21,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff5cbecf),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    user?.type ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              profileScreenImageWidget(
                                height,
                                width,
                                user?.profilePicture,
                                0.05,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '@${user?.username ?? ''}',
                                style: const TextStyle(
                                  color: Color(0xff568bc4),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: [
                                if (!shouldShowPrivate)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      iconButton(
                                        context,
                                        width,
                                        () {},
                                        Image.asset('assets/videoCall.png'),
                                        0.07,
                                        null,
                                      ),
                                      iconButton(
                                        context,
                                        width,
                                        () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => Message(
                                                    profileuserphone:
                                                        user?.mobileNumber,
                                                    userimg:
                                                        user?.profilePicture,
                                                    username: user?.username,
                                                  ),
                                            ),
                                          );
                                        },
                                        Image.asset('assets/chat-2.png'),
                                        0.07,
                                        null,
                                      ),
                                      iconButton(
                                        context,
                                        width,
                                        () {},
                                        Image.asset('assets/call-2.png'),
                                        0.07,
                                        null,
                                      ),
                                    ],
                                  ),
                                // if (!shouldShowPrivate)
                                //   Row(
                                //     mainAxisAlignment:
                                //         MainAxisAlignment.spaceBetween,
                                //     children: [
                                //       TextButton(
                                //         onPressed: () {
                                //           Navigator.push(
                                //             context,
                                //             MaterialPageRoute(
                                //               builder:
                                //                   (context) =>
                                //                       const FollowingScreen(),
                                //             ),
                                //           );
                                //         },
                                //         style: TextButton.styleFrom(
                                //           padding: EdgeInsets.zero,
                                //           textStyle: const TextStyle(
                                //             color: Colors.black,
                                //             decoration:
                                //                 TextDecoration.underline,
                                //           ),
                                //         ),
                                //         child: const Text(
                                //           'Following',
                                //           style: TextStyle(
                                //             fontSize: 12,
                                //             color: Colors.black,
                                //             fontWeight: FontWeight.w500,
                                //           ),
                                //         ),
                                //       ),
                                //       TextButton(
                                //         onPressed: () {
                                //           Navigator.push(
                                //             context,
                                //             MaterialPageRoute(
                                //               builder:
                                //                   (context) =>
                                //                       const ContactsScreen(
                                //                         cameFrom: "Profile",
                                //                       ),
                                //             ),
                                //           );
                                //         },
                                //         style: TextButton.styleFrom(
                                //           padding: EdgeInsets.zero,
                                //           textStyle: const TextStyle(
                                //             color: Colors.black,
                                //             decoration:
                                //                 TextDecoration.underline,
                                //           ),
                                //         ),
                                //         child: const Text(
                                //           'Contact',
                                //           style: TextStyle(
                                //             fontSize: 12,
                                //             color: Colors.black,
                                //             fontWeight: FontWeight.w500,
                                //           ),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        user?.bio ?? '',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (shouldShowPrivate)
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_outline,
                              size: 40,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "This Account is Private",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 48.0),
                          child: Text(
                            "Follow this account to see their photos and videos.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final currentUserDoc =
                                  await FirebaseFirestore.instance
                                      .collection('Users')
                                      .where(
                                        'mobileNumber',
                                        isEqualTo:
                                            profileDataModel?.mobileNumber,
                                      )
                                      .limit(1)
                                      .get();

                              if (currentUserDoc.docs.isEmpty) return;

                              final targetUserDoc =
                                  await FirebaseFirestore.instance
                                      .collection('Users')
                                      .where(
                                        'mobileNumber',
                                        isEqualTo: user?.mobileNumber,
                                      )
                                      .limit(1)
                                      .get();

                              if (targetUserDoc.docs.isEmpty) return;

                              final isTargetPrivate =
                                  targetUserDoc.docs.first.get(
                                    'privateAccount',
                                  ) ??
                                  false;
                              List<String> requestList = [];
                              final docRef = targetUserDoc.docs.first.reference;
                              final docData = targetUserDoc.docs.first.data();
                              if (docData.containsKey('requestList')) {
                                requestList = List<String>.from(
                                  targetUserDoc.docs.first.get('requestList') ??
                                      [],
                                );
                                setState(() {});
                              } else {
                                await docRef.set({
                                  "requestList": [],
                                }, SetOptions(merge: true));
                                setState(() {});
                              }

                              if (isFollowing) {
                                // Unfollow
                                String currentFollowMentors =
                                    currentUserDoc.docs.first.get(
                                      'followMentors',
                                    ) ??
                                    "";
                                String updatedFollowMentors =
                                    currentFollowMentors.replaceAll(
                                      "${user?.mobileNumber}//",
                                      "",
                                    );

                                await currentUserDoc.docs.first.reference
                                    .update({
                                      'followMentors': updatedFollowMentors,
                                    });

                                if (requestList.contains(
                                  profileDataModel?.mobileNumber,
                                )) {
                                  await targetUserDoc.docs.first.reference
                                      .update({
                                        'requestList': FieldValue.arrayRemove([
                                          profileDataModel?.mobileNumber,
                                        ]),
                                      });
                                }
                              } else {
                                if (isTargetPrivate) {
                                  // Send follow request
                                  await targetUserDoc.docs.first.reference
                                      .update({
                                        'requestList': FieldValue.arrayUnion([
                                          profileDataModel?.mobileNumber,
                                        ]),
                                      });

                                  FirebaseDatabase.instance
                                      .ref()
                                      .child('Users/')
                                      .child(
                                        '${user?.mobileNumber}/Notifications/',
                                      )
                                      .push()
                                      .set({
                                        "type": "followRequest",
                                        "mobileNumber":
                                            profileDataModel?.mobileNumber,
                                        "time": DateTime.now().toString(),
                                        "profilePicture":
                                            profileDataModel?.profilePicture,
                                        "username": profileDataModel?.username,
                                        "status": "pending",
                                      });
                                } else {
                                  // Follow directly
                                  String currentFollowMentors =
                                      currentUserDoc.docs.first.get(
                                        'followMentors',
                                      ) ??
                                      "";
                                  String updatedFollowMentors =
                                      "$currentFollowMentors${user?.mobileNumber}//";

                                  await currentUserDoc.docs.first.reference
                                      .update({
                                        'followMentors': updatedFollowMentors,
                                      });

                                  FirebaseDatabase.instance
                                      .ref()
                                      .child('Users/')
                                      .child(
                                        '${user?.mobileNumber}/Notifications/',
                                      )
                                      .push()
                                      .set({
                                        "type": "followMentor",
                                        "mobileNumber":
                                            profileDataModel?.mobileNumber,
                                        "time": DateTime.now().toString(),
                                        "profilePicture":
                                            profileDataModel?.profilePicture,
                                        "username": profileDataModel?.username,
                                      });
                                }
                              }

                              await _loadUserProfile(
                                profileDataModel!.mobileNumber,
                              );
                              await otherProfileCnt.getOtherProfileData(
                                mobileNumber: widget.mobileNumber,
                              );
                              setState(() {});
                            } catch (e) {
                              debugPrint("Error in follow/unfollow: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to update follow status',
                                  ),
                                ),
                              );
                            }
                          },
                          child: FutureBuilder<QuerySnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('Users')
                                    .where(
                                      'mobileNumber',
                                      isEqualTo: user?.mobileNumber,
                                    )
                                    .limit(1)
                                    .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Text('Follow');
                              }

                              final targetUserData = snapshot.data!.docs.first;
                              var requestList = [];
                              var isRequested = false;

                              if (targetUserData.data() != null &&
                                  (targetUserData.data()
                                          as Map<String, dynamic>)
                                      .containsKey("requestList")) {
                                requestList = List<String>.from(
                                  targetUserData.get('requestList') ?? [],
                                );

                                isRequested = requestList.contains(
                                  profileDataModel?.mobileNumber,
                                );
                              }
                              return Text(
                                isFollowing
                                    ? 'Unfollow'
                                    : isRequested
                                    ? 'Requested'
                                    : 'Follow',
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!shouldShowPrivate)
                  Column(
                    children: [
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        child: const Center(
                          child: Text(
                            'Announcements',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 20,
                        ),
                        color: const Color(0xfff9f6ed),
                        child: StreamBuilder<List<Announcement>>(
                          stream: _announcementsStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final announcements = snapshot.data ?? [];

                            if (announcements.isEmpty) {
                              return const Center(
                                child: Text('No active announcements'),
                              );
                            }

                            return Column(
                              children:
                                  announcements.map((announcement) {
                                    final isPlaying =
                                        _currentlyPlayingId == announcement.id;
                                    final isSubscribed = announcement
                                        .subscribers
                                        .contains(widget.currentUsername);
                                    return Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_filled,
                                            size: 27,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                          onPressed:
                                              () => _playAudio(
                                                announcement.id,
                                                announcement.audioUrl,
                                                isRecording: false,
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: announcement.title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const TextSpan(text: " • "),
                                                TextSpan(
                                                  text: _getExpiryText(
                                                    announcement.expiresAt,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.orange[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Switch(
                                          value: isSubscribed,
                                          activeColor: Colors.green,
                                          onChanged: (bool value) async {
                                            try {
                                              await AnnouncementService()
                                                  .toggleAnnouncementNotification(
                                                    announcement.id,
                                                    value,
                                                    widget.currentUsername,
                                                  );
                                              setState(() {});
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Failed to update subscription',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                if (profileDataModel?.type == "Holy" && !shouldShowPrivate)
                  Column(
                    children: [
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        child: const Center(
                          child: Text(
                            'Prayers',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 20,
                        ),
                        color: const Color(0xfff9f6ed),
                        child: StreamBuilder<List<Prayer>>(
                          stream: _prayersStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final prayers = snapshot.data ?? [];

                            if (prayers.isEmpty) {
                              return const Center(
                                child: Text('No active prayers'),
                              );
                            }

                            return Column(
                              children:
                                  prayers.map((prayer) {
                                    final isPlaying =
                                        _currentlyPlayingId == prayer.id;
                                    final isSubscribed = prayer.subscribers
                                        .contains(widget.currentUsername);
                                    return Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_filled,
                                            size: 27,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                          onPressed:
                                              () => _playAudio(
                                                prayer.id,
                                                prayer.audioUrl,
                                                isRecording: false,
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: prayer.title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Switch(
                                          value: isSubscribed,
                                          activeColor: Colors.green,
                                          onChanged: (bool value) async {
                                            try {
                                              await PrayerService()
                                                  .togglePrayerNotification(
                                                    prayer.id,
                                                    value,
                                                    widget.currentUsername,
                                                  );
                                              setState(() {});
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Failed to update subscription',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                if (user?.recording.isNotEmpty ?? false)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder:
                        (context, index) => const Divider(
                          height: 10,
                          color: Colors.black,
                          thickness: 1,
                        ),
                    itemCount: user!.recording.length,
                    itemBuilder: (context, index) {
                      final recording = user.recording[index];
                      final isPlaying = recording['isPlay'] ?? false;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${recording['name']}",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap:
                                () => _playAudio(
                                  recording['url'],
                                  recording['url'],
                                  isRecording: true,
                                ),
                            child: Container(
                              height: 35,
                              width: 35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black),
                              ),
                              child: Center(
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_outlined
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black),
                            ),
                            child: const Center(
                              child: Icon(Icons.volume_up_rounded),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black),
                            ),
                            child: const Center(
                              child: Icon(Icons.volume_off_rounded),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black),
                            ),
                            child: const Center(
                              child: Icon(Icons.vibration_rounded),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                if (!shouldShowPrivate)
                  Column(
                    children: [
                      const SizedBox(height: 15),
                      TabBar(
                        labelStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        labelColor: Colors.black,
                        dividerColor: Colors.transparent,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        unselectedLabelColor: vreyDarkGrayishBlue,
                        indicator: BoxDecoration(
                          color: const Color(0xffd9d9d9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tabs: [
                          Tab(
                            child: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(140, 217, 217, 217),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Obx(
                                () => Text(
                                  "Stories ${otherProfileCnt.totalStories}",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          Tab(
                            child: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(140, 217, 217, 217),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Obx(
                                () => Text(
                                  "Photos ${otherProfileCnt.totalPhotos}",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          Tab(
                            child: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(140, 217, 217, 217),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Obx(
                                () => Text(
                                  "Videos ${otherProfileCnt.totalVideos}",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: height * 0.68,
                        child: TabBarView(
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: 10),
                                Obx(
                                  () => SizedBox(
                                    height: height * 0.66,
                                    child:
                                        otherProfileCnt
                                                .otherProfilePostDataPhotoList
                                                .isNotEmpty
                                            ? GridView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              padding: const EdgeInsets.all(4),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 2,
                                                    crossAxisSpacing: 5,
                                                    mainAxisSpacing: 5,
                                                  ),
                                              itemCount:
                                                  otherProfileCnt
                                                      .otherProfilePostDataPhotoList
                                                      .length,
                                              itemBuilder: (context, index) {
                                                return PostCard(
                                                  image:
                                                      otherProfileCnt
                                                          .otherProfilePostDataPhotoList[index]
                                                          .thumbnail,
                                                  press: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => PostViewScreen(
                                                              postId:
                                                                  otherProfileCnt
                                                                      .otherProfilePostDataPhotoList[index]
                                                                      .key,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            )
                                            : Center(
                                              child: Text(
                                                !shouldShowPrivate
                                                    ? 'No Photos'
                                                    : 'This Account Is Private Please Follow',
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const SizedBox(height: 10),
                                Obx(
                                  () => SizedBox(
                                    height: height * 0.66,
                                    child:
                                        otherProfileCnt
                                                .otherProfilePostDataVideoList
                                                .isNotEmpty
                                            ? GridView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              padding: const EdgeInsets.all(4),
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 2,
                                                    crossAxisSpacing: 5,
                                                    mainAxisSpacing: 5,
                                                  ),
                                              itemCount:
                                                  otherProfileCnt
                                                      .otherProfilePostDataVideoList
                                                      .length,
                                              itemBuilder: (context, index) {
                                                return PostCard(
                                                  image:
                                                      otherProfileCnt
                                                          .otherProfilePostDataVideoList[index]
                                                          .thumbnail,
                                                  press: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => PostViewScreen(
                                                              postId:
                                                                  otherProfileCnt
                                                                      .otherProfilePostDataVideoList[index]
                                                                      .key,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            )
                                            : Center(
                                              child: Text(
                                                !shouldShowPrivate
                                                    ? 'No Videos'
                                                    : 'This Account Is Private Please Follow',
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(), // Placeholder for Stories tab
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
    });
  }
}
