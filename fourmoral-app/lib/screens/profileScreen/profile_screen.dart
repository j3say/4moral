import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cloud;
import 'package:file_picker/file_picker.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/announcement.dart';
import 'package:fourmoral/models/prayer.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/editProfileScreen/edit_profile_screen.dart';
import 'package:fourmoral/screens/followingScreen/following_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/add_post_story_product_screen.dart';
import 'package:fourmoral/screens/profileScreen/badge_widget.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/screens/profileScreen/profile_widgets.dart';
import 'package:fourmoral/screens/profileScreen/schedule_selection_modal.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:fourmoral/screens/story/story_view_page.dart';
import 'package:fourmoral/services/announcement_service.dart';
import 'package:fourmoral/services/prayer_service.dart';
import 'package:get/get.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../constants/colors.dart';
import '../../widgets/app_bar_custom.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../../widgets/profile_image_widget.dart';
import '../contactsScreen/contacts_screen.dart';
import '../postViewScreen/post_view_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.profileModel});

  final ProfileModel? profileModel;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final profileCnt = Get.put(ProfileController());
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final Story2Controller story2Controller = Get.put(Story2Controller());

  late Stream<List<Announcement>> _announcementsStream;
  late Stream<List<Prayer>> _prayersStream;
  final Map<String, bool> _editTextStates = {};
  cloud.CollectionReference collectionUserReference = cloud
      .FirebaseFirestore
      .instance
      .collection('Users');
  bool privateAccount = false;
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _formKeyPrayer = GlobalKey<FormState>();
  final Map<String, TextEditingController> _titleControllers = {};
  final _announcementService = AnnouncementService();

  final _prayerService = PrayerService();
  final _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  final _audioRecorder = AudioRecorder();
  final FocusNode _focusNode = FocusNode();
  bool _isFormVisible = false;
  bool _isFormVisiblePrayer = false;
  bool _isRecording = false;
  String? _recordingPath;
  bool _isLoading = false;
  String? _audioFileName;
  Map<String, dynamic>? scheduleData;

  @override
  void initState() {
    super.initState();
    _announcementService.setupExpirationTask();
    _announcementsStream = _announcementService.getUserAnnouncements(
      widget.profileModel?.username ?? "",
    );
    _prayerService.setupExpirationTask();
    _prayersStream = _prayerService.getActivePrayersForUser(
      widget.profileModel?.username ?? "",
    );

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentlyPlayingId = null;
      });
    });
    init();
    // profileCnt.getUserProfilePostData();
    // profileCnt.getMemoriesList();
    profileCnt.contactsScreenCnt.updateProfileCnt();
  }

  init() async {
    await profileCnt.initialize(
      widget.profileModel,
      widget.profileModel?.mobileNumber,
    );
  }

  @override
  void dispose() {
    _titleControllers.forEach((_, controller) => controller.dispose());
    _audioPlayer.dispose();
    _titleController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void showSchedule() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => ScheduleSelectionModal(
            onScheduleSelected: (selectedData) {
              setState(() {
                scheduleData = selectedData;
              });
              print("Received in parent: $selectedData");
            },
          ),
    );
  }

  String _formatDates(List<DateTime> dates) {
    return dates.map((date) => DateFormat('MMM d').format(date)).join(', ');
  }

  // Helper to convert day indices to names (0=Sun, 1=Mon, etc.)
  String _formatDays(List<int> dayIndices) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return dayIndices.map((index) => days[index]).join(', ');
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/announcement_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = filePath;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error while starting recording: $e')),
      );
    }
  }

  Future<void> _submitAnnouncement() async {
    if (_formKey.currentState!.validate() && _recordingPath != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final announcement = await _announcementService.createAnnouncement(
          title: _titleController.text.trim(),
          username: widget.profileModel!.username,
          audioFile: File(_recordingPath!),
          schedule: scheduleData, // Pass the schedule data here
          // schedule: scheduleData,
        );

        // if (widget.profileModel?.privateAccount ?? false) {
        //   List<String> numbers =
        //       (widget.profileModel?.followMentors ?? '')
        //           .split("//")
        //           .where((e) => e.isNotEmpty)
        //           .toList();
        //   for (var element in numbers) {
        //     final senderDoc =
        //         await FirebaseFirestore.instance
        //             .collection('users')
        //             .doc(element)
        //             .get();
        //     final senderFcmToken = senderDoc.data()?['fcmToken'] as String;
        //     await sendFCMNotification(
        //       receiverFcmToken: senderFcmToken,
        //       title: widget.profileModel?.username ?? "New Announcement",
        //       body: 'New Announcement scheduled',
        //       type: 'Announcement',
        //     );
        //   }
        // } else {}

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement scheduled successfully!')),
        );

        // Reset form
        _formKey.currentState?.reset();
        _titleController.clear();
        setState(() {
          _recordingPath = null;
          scheduleData = null; // Clear schedule after submission
          _isFormVisible = false; // Hide the form after submission
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else if (_recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record an audio first')),
      );
    }
  }

  Future<void> _updateAnnouncementTitle(
    String announcementId,
    String newTitle,
  ) async {
    try {
      await _announcementService.updateAnnouncementTitle(
        announcementId,
        newTitle,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement title updated successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update title: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error while stopping recording: $e')),
      );
    }
  }

  Future<void> w_submitAnnouncement() async {
    if (_formKey.currentState!.validate() && _recordingPath != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final announcement = await _announcementService.createAnnouncement(
          title: _titleController.text.trim(),
          username: widget.profileModel!.username,
          audioFile: File(_recordingPath!),
          // schedule: scheduleData,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement scheduled successfully!')),
        );

        // Reset form
        _formKey.currentState?.reset();
        _titleController.clear();
        setState(() {
          _recordingPath = null;
          scheduleData = null; // Clear schedule after submission
          _isFormVisible = false; // Hide the form after submission
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else if (_recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record an audio first')),
      );
    }
  }

  Future<void> _uploadAudio() async {
    try {
      // Use file_picker package to select audio files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null) {
        File file = File(result.files.single.path!);

        // Use the selected file path as the recording path to maintain compatibility
        setState(() {
          _isRecording = false; // Ensure recording state is off
          _recordingPath = file.path; // Set the path to the uploaded file
          _audioFileName = result.files.single.name;
        });

        // Optional: Show a snackbar to confirm the upload
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio uploaded: $_audioFileName')),
        );
      }
    } catch (e) {
      print('Error picking audio file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload audio file')));
    }
  }

  void _toggleFormVisibility() {
    setState(() {
      _isFormVisible = !_isFormVisible;
    });
  }

  void _playAudio(String announcementId, String audioUrl) async {
    if (_currentlyPlayingId == announcementId) {
      // Stop playing
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingId = null;
      });
    } else {
      // Start playing
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
      setState(() {
        _currentlyPlayingId = announcementId;
      });
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

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await _announcementService.deleteAnnouncement(id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting announcement: ${e.toString()}')),
      );
    }
  }

  Future<void> _updatePrayerTitle(String prayerId, String newTitle) async {
    try {
      await _prayerService.updatePrayerTitle(prayerId, newTitle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prayer title updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update title: $e')));
    }
  }

  Future<void> _submitPrayer() async {
    if (_formKeyPrayer.currentState!.validate() && _recordingPath != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _prayerService.createPrayer(
          title: _titleController.text.trim(),
          audioFile: File(_recordingPath!),
          username: widget.profileModel!.username,
        );

        // Remove the Navigator.pop() line to avoid going back
        // Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prayer created successfully!')),
        );

        // Optionally, you can reset the form or clear the input fields
        _formKeyPrayer.currentState?.reset();
        _titleController.clear();
        setState(() {
          _recordingPath = null; // Clear the recording path if needed
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating prayer: $e')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else if (_recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record an audio first')),
      );
    }
  }

  void _toggleFormVisibilityPrayer() {
    setState(() {
      _isFormVisiblePrayer = !_isFormVisiblePrayer;
    });
  }

  Future<void> _deletePrayer(String prayerId) async {
    try {
      await _prayerService.deletePrayer(prayerId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prayer deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete prayer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Color(0xfff9f6ed),
        resizeToAvoidBottomInset: false,
        appBar: appBarCustomProfileScreen(
          "Profile",
          context,
          widget.profileModel,
          widget.profileModel?.mobileNumber,
          height,
        ),
        body: Obx(
          () =>
              !profileCnt.userProfilePostDataFetched.value
                  ? Center(child: CircularProgressIndicator())
                  : SafeArea(
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                Container(
                                  color: blue,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      top: 20,
                                      bottom: 20,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                AutoSizeText(
                                                  widget.profileModel?.name ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 21,
                                                  ),
                                                  textAlign: TextAlign.start,
                                                ),
                                                SizedBox(height: 5),
                                                BadgeWidget(
                                                  badge:
                                                      widget
                                                          .profileModel
                                                          ?.type ??
                                                      '',
                                                ),
                                              ],
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  profileScreenImageWidget(
                                                    height,
                                                    width,
                                                    widget
                                                        .profileModel
                                                        ?.profilePicture,
                                                    0.05,
                                                  ),
                                                  SizedBox(height: 7),
                                                  Text(
                                                    '@${widget.profileModel?.username ?? ''}',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 02),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Column(
                                                  children: [
                                                    Text(
                                                      '${profileCnt.followingCount.value}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(height: 10),
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (context) =>
                                                                    const FollowingScreen(),
                                                          ),
                                                        );
                                                      },
                                                      child: Icon(
                                                        Icons.group,
                                                        color: Colors.black,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    SizedBox(height: 5),
                                                    Text(
                                                      'Following',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(width: 10),
                                                Column(
                                                  children: [
                                                    Text(
                                                      '${profileCnt.contactsCount.value}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(height: 10),
                                                    InkWell(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => const ContactsScreen(
                                                                  cameFrom:
                                                                      "Profile",
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                      child: Icon(
                                                        Icons.contacts,
                                                        color: Colors.black,
                                                        size: 20,
                                                      ),
                                                    ),
                                                    SizedBox(height: 5),
                                                    Text(
                                                      'Contact',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 7),
                                        widget.profileModel?.bio != null
                                            ? Text(
                                              widget.profileModel!.bio,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )
                                            : const SizedBox.shrink(),
                                      ],
                                    ),
                                  ),
                                ),
                                if (widget.profileModel?.type != 'Standard')
                                  Column(
                                    children: [
                                      Container(
                                        color: Colors.black,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 10,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned(
                                              left: 0,
                                              child: TextButton(
                                                onPressed:
                                                    _toggleFormVisibility,
                                                child: Text(
                                                  _isFormVisible
                                                      ? 'Cancel'
                                                      : 'Add',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12.0,
                                                    ),
                                                child: InkWell(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,

                                                      builder:
                                                          (
                                                            context,
                                                          ) => AlertDialog(
                                                            scrollable: true,
                                                            title: const Text(
                                                              'Note',
                                                            ),
                                                            content: const Text(
                                                              'The announcement feature helps you send important alerts to your followers and contacts in the form of audio.\nWith this feature, you can either record an audio message or send a saved audio file.\n You can also set a schedule for your announcement based on time, day, and date.\nAccording to the schedule, the announcement can be sent once or multiple times.\nIf you create an announcement but don’t set a schedule, the audio will automatically be removed after 24 hours. However, the announcement title will always remain visible on your profile page until you delete it permanently. Your followers and contacts can select it to receive the next update.\nYou can edit the audio, title, and time of the announcement at any time.\n For your followers and contacts, there are 3–4 alert options to choose from:\nSpeaker 🔊 – The announcement audio will automatically play through the speakers.\n Mute 🔇 – Only shows a notification inside the app when opened.\n Pop-up Notifications 🔔 – A pop-up notification will appear.\n Vibration + Pop-up Notification – Vibrates along with a pop-up notification.                                                            \n Announcements can be sent one-time or on a scheduled basis.\nOnce an audio announcement is updated, it will remain on the profile page for 24 hours, and users can play it multiple times before it is removed.\nIf the announcement is set with a repeat schedule, the audio will not be deleted, and alerts will be sent repeatedly according to the schedule.',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Okay',
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                  },
                                                  child: Center(
                                                    child: Image.asset(
                                                      'assets/info.png',
                                                      color: Colors.white,
                                                      height: 20,
                                                      fit: BoxFit.fill,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            Center(
                                              child: Text(
                                                'Announcement',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 20,
                                        ),
                                        color: Color(0xfff9f6ed),
                                        child: Column(
                                          children: [
                                            StreamBuilder<List<Announcement>>(
                                              stream: _announcementsStream,
                                              builder: (context, snapshot) {
                                                if (snapshot.hasError) {
                                                  return Center(
                                                    child: Text(
                                                      'Error: ${snapshot.error}',
                                                    ),
                                                  );
                                                }

                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                }

                                                final announcements =
                                                    snapshot.data ?? [];

                                                if (announcements.isEmpty) {
                                                  return Center(
                                                    child: GestureDetector(
                                                      onTap:
                                                          _toggleFormVisibility,
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            _isFormVisible
                                                                ? Icons
                                                                    .close_outlined
                                                                : Icons
                                                                    .add_circle_outline,
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            _isFormVisible
                                                                ? 'Close Form'
                                                                : 'Add Announcement',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }

                                                // Initialize edit states and controllers
                                                for (var announcement
                                                    in announcements) {
                                                  _editTextStates.putIfAbsent(
                                                    announcement.id,
                                                    () => false,
                                                  );
                                                  _titleControllers.putIfAbsent(
                                                    announcement.id,
                                                    () => TextEditingController(
                                                      text: announcement.title,
                                                    ),
                                                  );
                                                }

                                                return ListView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  itemCount:
                                                      announcements.length,
                                                  itemBuilder: (
                                                    context,
                                                    index,
                                                  ) {
                                                    final announcement =
                                                        announcements[index];
                                                    final isPlaying =
                                                        _currentlyPlayingId ==
                                                        announcement.id;
                                                    final isEditing =
                                                        _editTextStates[announcement
                                                            .id] ??
                                                        false;
                                                    final controller =
                                                        _titleControllers[announcement
                                                            .id]!;

                                                    return Card(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 8,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            // Schedule indicator
                                                            if (announcement
                                                                    .schedule !=
                                                                null)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      bottom: 8,
                                                                    ),
                                                                child: _buildScheduleIndicator(
                                                                  announcement
                                                                      .schedule!,
                                                                ),
                                                              ),

                                                            Row(
                                                              children: [
                                                                // Audio controls
                                                                _buildAudioControl(
                                                                  announcement,
                                                                  isPlaying,
                                                                ),
                                                                const SizedBox(
                                                                  width: 10,
                                                                ),

                                                                // Title field
                                                                Expanded(
                                                                  child:
                                                                      isEditing
                                                                          ? TextField(
                                                                            controller:
                                                                                controller,
                                                                            style: const TextStyle(
                                                                              fontSize:
                                                                                  14,
                                                                            ),
                                                                            decoration: const InputDecoration(
                                                                              hintText:
                                                                                  'Enter title',
                                                                              border:
                                                                                  InputBorder.none,
                                                                            ),
                                                                          )
                                                                          : Text(
                                                                            announcement.title,
                                                                            style: const TextStyle(
                                                                              fontSize:
                                                                                  14,
                                                                            ),
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                          ),
                                                                ),

                                                                // Action buttons
                                                                _buildActionButtons(
                                                                  announcement,
                                                                  isEditing,
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 14),
                                            AnimatedContainer(
                                              duration: Duration(
                                                milliseconds: 300,
                                              ),
                                              height:
                                                  _isFormVisible
                                                      ? 300
                                                      : 0, // Adjust height based on visibility
                                              curve: Curves.easeInOut,
                                              child: Visibility(
                                                visible: _isFormVisible,
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child:
                                                            _isRecording
                                                                ? Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons.mic,
                                                                      color:
                                                                          Colors
                                                                              .red,
                                                                      size: 30,
                                                                    ),
                                                                    Text(
                                                                      'Recording',
                                                                    ),
                                                                  ],
                                                                )
                                                                : _recordingPath !=
                                                                    null
                                                                ? Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .audio_file,
                                                                      color:
                                                                          Colors
                                                                              .green,
                                                                      size: 30,
                                                                    ),
                                                                    Text(
                                                                      'Audio Added',
                                                                    ),
                                                                  ],
                                                                )
                                                                : Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .mic_none,
                                                                      color:
                                                                          Colors
                                                                              .grey,
                                                                      size: 30,
                                                                    ),
                                                                    Text(
                                                                      'Muted',
                                                                    ),
                                                                  ],
                                                                ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 7),
                                                    Form(
                                                      key: _formKey,
                                                      child: Row(
                                                        children: [
                                                          // Audio options menu with three dots
                                                          PopupMenuButton<
                                                            String
                                                          >(
                                                            icon: Icon(
                                                              Icons.more_vert,
                                                            ),
                                                            onSelected: (
                                                              String choice,
                                                            ) {
                                                              if (choice ==
                                                                  'record') {
                                                                _startRecording();
                                                              } else if (choice ==
                                                                  'upload') {
                                                                _uploadAudio();
                                                              }
                                                            },
                                                            itemBuilder: (
                                                              BuildContext
                                                              context,
                                                            ) {
                                                              return [
                                                                PopupMenuItem<
                                                                  String
                                                                >(
                                                                  value:
                                                                      'record',
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .mic,
                                                                        color:
                                                                            Colors.grey.shade700,
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Text(
                                                                        'Record Audio',
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                PopupMenuItem<
                                                                  String
                                                                >(
                                                                  value:
                                                                      'upload',
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .upload_file,
                                                                        color:
                                                                            Colors.grey.shade700,
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Text(
                                                                        'Upload Audio',
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ];
                                                            },
                                                          ),
                                                          // Record button (existing implementation)
                                                          if (_isRecording)
                                                            GestureDetector(
                                                              onTap:
                                                                  _stopRecording,
                                                              child: Container(
                                                                width: 34,
                                                                height: 34,
                                                                decoration: const BoxDecoration(
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons.stop,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          else
                                                            GestureDetector(
                                                              onTap:
                                                                  _startRecording,
                                                              child: Container(
                                                                width: 34,
                                                                height: 34,
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      Colors
                                                                          .grey
                                                                          .shade300,
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons.mic,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          scheduleData != null
                                                              ? Container(
                                                                width: 34,
                                                                height: 34,
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      Colors
                                                                          .green
                                                                          .shade300,
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .alarm_on,
                                                                  ),
                                                                ),
                                                              )
                                                              : GestureDetector(
                                                                onTap:
                                                                    showSchedule,
                                                                child: Container(
                                                                  width: 34,
                                                                  height: 34,
                                                                  decoration: BoxDecoration(
                                                                    color: Color(
                                                                      0xFFE0E0E0,
                                                                    ),
                                                                    shape:
                                                                        BoxShape
                                                                            .circle,
                                                                  ),
                                                                  child: const Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .alarm_add_outlined,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: InkWell(
                                                              onTap: () {
                                                                // FocusScope.of(
                                                                //   context,
                                                                // ).requestFocus(
                                                                //   _focusNode,
                                                                // );
                                                              },
                                                              child: TextField(
                                                                controller:
                                                                    _titleController,
                                                                focusNode:
                                                                    _focusNode,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .black,
                                                                ),
                                                                decoration: InputDecoration(
                                                                  hintText:
                                                                      'Enter announcement title',
                                                                  border:
                                                                      InputBorder
                                                                          .none,
                                                                  contentPadding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          GestureDetector(
                                                            onTap:
                                                                _isLoading
                                                                    ? null
                                                                    : _submitAnnouncement,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    Colors
                                                                        .green
                                                                        .shade300,
                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                              ),
                                                              width: 34,
                                                              height: 34,
                                                              child: Center(
                                                                child:
                                                                    _isLoading
                                                                        ? const CircularProgressIndicator(
                                                                          color:
                                                                              Colors.black,
                                                                        )
                                                                        : Icon(
                                                                          Icons
                                                                              .check,
                                                                        ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(height: 7),
                                                    Stack(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                16,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .grey
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                                spreadRadius: 1,
                                                                blurRadius: 3,
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      1,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          width:
                                                              double.infinity,
                                                          child: SingleChildScrollView(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                if (scheduleData !=
                                                                    null) ...[
                                                                  const Text(
                                                                    'Current Schedule:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 15,
                                                                  ),

                                                                  Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          left:
                                                                              8,
                                                                        ),
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Row(
                                                                          children: [
                                                                            const Icon(
                                                                              Icons.access_time,
                                                                              size:
                                                                                  18,
                                                                              color:
                                                                                  Colors.blue,
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  12,
                                                                            ),
                                                                            Expanded(
                                                                              child: Text(
                                                                                'Time: ${scheduleData!['time']}',
                                                                                style: const TextStyle(
                                                                                  fontSize:
                                                                                      14,
                                                                                ),
                                                                                overflow:
                                                                                    TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              14,
                                                                        ),

                                                                        // Display either dates or days
                                                                        if (scheduleData!['type'] ==
                                                                            'dates')
                                                                          Row(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              const Icon(
                                                                                Icons.calendar_today,
                                                                                size:
                                                                                    18,
                                                                                color:
                                                                                    Colors.blue,
                                                                              ),
                                                                              const SizedBox(
                                                                                width:
                                                                                    12,
                                                                              ),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  'Dates: ${_formatDates(scheduleData!['dates'])}',
                                                                                  style: const TextStyle(
                                                                                    fontSize:
                                                                                        14,
                                                                                  ),
                                                                                  overflow:
                                                                                      TextOverflow.visible,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )
                                                                        else
                                                                          Row(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              const Icon(
                                                                                Icons.repeat,
                                                                                size:
                                                                                    18,
                                                                                color:
                                                                                    Colors.blue,
                                                                              ),
                                                                              const SizedBox(
                                                                                width:
                                                                                    12,
                                                                              ),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  'Repeat: ${_formatDays(scheduleData!['days'])}',
                                                                                  style: const TextStyle(
                                                                                    fontSize:
                                                                                        14,
                                                                                  ),
                                                                                  overflow:
                                                                                      TextOverflow.visible,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ] else
                                                                  const Center(
                                                                    child: Padding(
                                                                      padding: EdgeInsets.symmetric(
                                                                        vertical:
                                                                            16,
                                                                      ),
                                                                      child: Text(
                                                                        'No schedule set. This will be removed automatically in 24 hours',
                                                                        style: TextStyle(
                                                                          color:
                                                                              Colors.grey,
                                                                          fontSize:
                                                                              13,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        scheduleData != null
                                                            ? Positioned(
                                                              top: 0,
                                                              right: 0,
                                                              child: IconButton(
                                                                icon: const Icon(
                                                                  Icons.edit,
                                                                  color:
                                                                      Colors
                                                                          .blue,
                                                                ),
                                                                onPressed: () {
                                                                  showSchedule();
                                                                },
                                                              ),
                                                            )
                                                            : SizedBox(),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                if (profileDataModel!.type == 'Holy places')
                                  Column(
                                    children: [
                                      Container(
                                        color: Colors.black,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 10,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned(
                                              left: 0,
                                              child: TextButton(
                                                onPressed:
                                                    _toggleFormVisibilityPrayer,
                                                child: Text(
                                                  _isFormVisiblePrayer
                                                      ? 'Cancel'
                                                      : 'Add',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Center(
                                              child: Text(
                                                'Prayer',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 20,
                                        ),
                                        color: Color(0xfff9f6ed),
                                        child: Column(
                                          children: [
                                            StreamBuilder<List<Prayer>>(
                                              stream: _prayersStream,
                                              builder: (context, snapshot) {
                                                if (snapshot.hasError) {
                                                  return Center(
                                                    child: Text(
                                                      'Error: ${snapshot.error}',
                                                    ),
                                                  );
                                                }

                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center();
                                                }

                                                final prayers =
                                                    snapshot.data ?? [];

                                                if (prayers.isEmpty) {
                                                  return const Center(
                                                    child: Text(
                                                      'No active prayers',
                                                    ),
                                                  );
                                                }

                                                // Initialize edit states and controllers for new prayers
                                                for (var prayer in prayers) {
                                                  _editTextStates.putIfAbsent(
                                                    prayer.id,
                                                    () => false,
                                                  );
                                                  _titleControllers.putIfAbsent(
                                                    prayer.id,
                                                    () => TextEditingController(
                                                      text: prayer.title,
                                                    ),
                                                  );
                                                }
                                                return Column(
                                                  children: [
                                                    SizedBox(
                                                      child: SingleChildScrollView(
                                                        child: Column(
                                                          children:
                                                              prayers.map((
                                                                prayer,
                                                              ) {
                                                                final isPlaying =
                                                                    _currentlyPlayingId ==
                                                                    prayer.id;
                                                                final isEditing =
                                                                    _editTextStates[prayer
                                                                        .id] ??
                                                                    false;
                                                                final controller =
                                                                    _titleControllers[prayer
                                                                        .id]!;

                                                                return Row(
                                                                  children: [
                                                                    prayer
                                                                            .audioUrl
                                                                            .isNotEmpty
                                                                        ? IconButton(
                                                                          icon: Icon(
                                                                            isPlaying
                                                                                ? Icons.pause_circle_filled
                                                                                : Icons.play_circle_filled,
                                                                            size:
                                                                                27,
                                                                            color:
                                                                                Theme.of(
                                                                                  context,
                                                                                ).primaryColor,
                                                                          ),
                                                                          onPressed:
                                                                              () => _playAudio(
                                                                                prayer.id,
                                                                                prayer.audioUrl,
                                                                              ),
                                                                        )
                                                                        : PopupMenuButton<
                                                                          String
                                                                        >(
                                                                          icon: Icon(
                                                                            Icons.volume_off,
                                                                            size:
                                                                                27,
                                                                            color:
                                                                                Colors.grey,
                                                                          ),
                                                                          onSelected: (
                                                                            String
                                                                            choice,
                                                                          ) {
                                                                            if (choice ==
                                                                                'record') {
                                                                              _startRecording();
                                                                            } else if (choice ==
                                                                                'upload') {
                                                                              _uploadAudio();
                                                                            }
                                                                          },
                                                                          itemBuilder: (
                                                                            BuildContext
                                                                            context,
                                                                          ) {
                                                                            return [
                                                                              PopupMenuItem<
                                                                                String
                                                                              >(
                                                                                value:
                                                                                    'record',
                                                                                child: Row(
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.mic,
                                                                                      color:
                                                                                          Colors.grey.shade700,
                                                                                    ),
                                                                                    SizedBox(
                                                                                      width:
                                                                                          8,
                                                                                    ),
                                                                                    Text(
                                                                                      'Record Audio',
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                              PopupMenuItem<
                                                                                String
                                                                              >(
                                                                                value:
                                                                                    'upload',
                                                                                child: Row(
                                                                                  children: [
                                                                                    Icon(
                                                                                      Icons.upload_file,
                                                                                      color:
                                                                                          Colors.grey.shade700,
                                                                                    ),
                                                                                    SizedBox(
                                                                                      width:
                                                                                          8,
                                                                                    ),
                                                                                    Text(
                                                                                      'Upload Audio',
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ];
                                                                          },
                                                                        ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          isEditing
                                                                              ? TextField(
                                                                                controller:
                                                                                    controller,

                                                                                style: TextStyle(
                                                                                  fontSize:
                                                                                      14,
                                                                                  color:
                                                                                      Colors.black,
                                                                                ),
                                                                                decoration: InputDecoration(
                                                                                  hintText:
                                                                                      'Enter title',
                                                                                  border:
                                                                                      InputBorder.none,
                                                                                  contentPadding:
                                                                                      EdgeInsets.zero,
                                                                                ),
                                                                              )
                                                                              : Text.rich(
                                                                                TextSpan(
                                                                                  children: [
                                                                                    TextSpan(
                                                                                      text:
                                                                                          prayer.title,
                                                                                      style: TextStyle(
                                                                                        fontSize:
                                                                                            14,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                maxLines:
                                                                                    1,
                                                                                overflow:
                                                                                    TextOverflow.ellipsis,
                                                                              ),
                                                                    ),
                                                                    SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    isEditing
                                                                        ? GestureDetector(
                                                                          onTap: () async {
                                                                            await _updatePrayerTitle(
                                                                              prayer.id,
                                                                              controller.text,
                                                                            );
                                                                            setState(() {
                                                                              _editTextStates[prayer.id] =
                                                                                  false;
                                                                            });
                                                                          },
                                                                          child: Container(
                                                                            width:
                                                                                34,
                                                                            height:
                                                                                34,
                                                                            decoration: const BoxDecoration(
                                                                              color:
                                                                                  Colors.green,
                                                                              shape:
                                                                                  BoxShape.circle,
                                                                            ),
                                                                            child: const Center(
                                                                              child: Icon(
                                                                                Icons.check,
                                                                                color:
                                                                                    Colors.white,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        )
                                                                        : PopupMenuButton(
                                                                          icon: const Icon(
                                                                            Icons.more_vert,
                                                                          ),
                                                                          itemBuilder:
                                                                              (
                                                                                context,
                                                                              ) => [
                                                                                const PopupMenuItem(
                                                                                  value:
                                                                                      'edit_text',
                                                                                  child: Text(
                                                                                    'Edit Text',
                                                                                  ),
                                                                                ),
                                                                                const PopupMenuItem(
                                                                                  value:
                                                                                      'delete',
                                                                                  child: Text(
                                                                                    'Delete',
                                                                                  ),
                                                                                ),
                                                                                const PopupMenuItem(
                                                                                  value:
                                                                                      'delete_audio',
                                                                                  child: Text(
                                                                                    'Delete Audio',
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                          onSelected: (
                                                                            value,
                                                                          ) async {
                                                                            if (value ==
                                                                                'edit_text') {
                                                                              setState(
                                                                                () {
                                                                                  _editTextStates[prayer.id] =
                                                                                      true;
                                                                                },
                                                                              );
                                                                            } else if (value ==
                                                                                'delete') {
                                                                              _deletePrayer(
                                                                                prayer.id,
                                                                              );
                                                                              // Clean up controller when deleting
                                                                              _titleControllers[prayer.id]?.dispose();
                                                                              _titleControllers.remove(
                                                                                prayer.id,
                                                                              );
                                                                              _editTextStates.remove(
                                                                                prayer.id,
                                                                              );
                                                                            } else if (value ==
                                                                                'delete_audio') {
                                                                              try {
                                                                                // Show loading indicator

                                                                                await _prayerService.deletePrayerAudio(
                                                                                  prayer.id,
                                                                                );

                                                                                // Success message
                                                                                if (mounted) {
                                                                                  ScaffoldMessenger.of(
                                                                                    context,
                                                                                  ).showSnackBar(
                                                                                    const SnackBar(
                                                                                      content: Text(
                                                                                        'Audio successfully deleted',
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                }
                                                                              } catch (
                                                                                e
                                                                              ) {
                                                                                // Error handling
                                                                                if (mounted) {
                                                                                  ScaffoldMessenger.of(
                                                                                    context,
                                                                                  ).showSnackBar(
                                                                                    SnackBar(
                                                                                      content: Text(
                                                                                        'Failed to delete audio: ${e.toString()}',
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                }
                                                                              } finally {
                                                                                // Hide loading indicator
                                                                                if (mounted) {}
                                                                              }
                                                                            }
                                                                          },
                                                                        ),
                                                                  ],
                                                                );
                                                              }).toList(),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 14),
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  height:
                                      _isFormVisiblePrayer
                                          ? 150
                                          : 0, // Adjust height based on visibility
                                  curve: Curves.easeInOut,
                                  child: Visibility(
                                    visible: _isFormVisiblePrayer,
                                    child: Column(
                                      children: [
                                        Container(
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Center(
                                            child:
                                                _isRecording
                                                    ? Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons.mic,
                                                          color: Colors.red,
                                                          size: 30,
                                                        ),
                                                        Text('Recording'),
                                                      ],
                                                    )
                                                    : _recordingPath != null
                                                    ? Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons.audio_file,
                                                          color: Colors.green,
                                                          size: 30,
                                                        ),
                                                        Text('Audio Added'),
                                                      ],
                                                    )
                                                    : Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        const Icon(
                                                          Icons.mic_none,
                                                          color: Colors.grey,
                                                          size: 30,
                                                        ),
                                                        Text('Muted'),
                                                      ],
                                                    ),
                                          ),
                                        ),
                                        SizedBox(height: 7),
                                        Form(
                                          key: _formKeyPrayer,
                                          child: Row(
                                            children: [
                                              // Audio options menu with three dots
                                              PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert),
                                                onSelected: (String choice) {
                                                  if (choice == 'record') {
                                                    _startRecording();
                                                  } else if (choice ==
                                                      'upload') {
                                                    _uploadAudio();
                                                  }
                                                },
                                                itemBuilder: (
                                                  BuildContext context,
                                                ) {
                                                  return [
                                                    PopupMenuItem<String>(
                                                      value: 'record',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.mic,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade700,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Record Audio'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'upload',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.upload_file,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade700,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('Upload Audio'),
                                                        ],
                                                      ),
                                                    ),
                                                  ];
                                                },
                                              ),
                                              // Record button (existing implementation)
                                              if (_isRecording)
                                                GestureDetector(
                                                  onTap: _stopRecording,
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.red,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: const Center(
                                                      child: Icon(Icons.stop),
                                                    ),
                                                  ),
                                                )
                                              else
                                                GestureDetector(
                                                  onTap: _startRecording,
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade300,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(Icons.mic),
                                                    ),
                                                  ),
                                                ),

                                              const SizedBox(width: 10),

                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(
                                                      context,
                                                    ).requestFocus(_focusNode);
                                                  },
                                                  child: TextField(
                                                    controller:
                                                        _titleController,
                                                    focusNode: _focusNode,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Enter prayer title',
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap:
                                                    _isLoading
                                                        ? null
                                                        : _submitPrayer,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.green.shade300,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  width: 34,
                                                  height: 34,
                                                  child: Center(
                                                    child:
                                                        _isLoading
                                                            ? const CircularProgressIndicator(
                                                              color:
                                                                  Colors.black,
                                                            )
                                                            : Icon(Icons.check),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  color: black,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Get.to(
                                              () => AddPostStoryProductScreen(
                                                profileModel: profileDataModel,
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          profileDataModel?.type == "Mentor"
                                              ? "Post"
                                              : "Memories",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        SizedBox(width: 5),
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${(profileCnt.totalMediaCount) + (story2Controller.myStories.isNotEmpty ? story2Controller.myStories[0].stories.length : 0)}',
                                              style: TextStyle(
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Spacer(),
                                        InkWell(
                                          onTap: () {
                                            Get.to(
                                              () => EditProfileScreen(
                                                profileObject:
                                                    widget.profileModel,
                                                userPhoneNumber:
                                                    widget
                                                        .profileModel
                                                        ?.mobileNumber,
                                              ),
                                            );
                                          },
                                          child: Icon(
                                            Icons.edit_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverAppBarDelegate(
                              TabBar(
                                labelStyle: TextStyle(
                                  color: black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                labelColor: black,
                                dividerColor: Colors.transparent,
                                physics: BouncingScrollPhysics(),
                                labelPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                unselectedLabelColor: vreyDarkGrayishBlue,
                                indicator: BoxDecoration(
                                  color: Color(0xffd9d9d9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                tabs: [
                                  Tab(
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Color.fromARGB(
                                          140,
                                          217,
                                          217,
                                          217,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "All ${(profileCnt.totalMediaCount) + (story2Controller.myStories.isNotEmpty ? story2Controller.myStories[0].stories.length : 0)}",
                                      ),
                                    ),
                                  ),
                                  Tab(
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Color.fromARGB(
                                          140,
                                          217,
                                          217,
                                          217,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "Post ${profileCnt.totalPhotos}",
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Tab(
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Color.fromARGB(
                                          140,
                                          217,
                                          217,
                                          217,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "Stories ${story2Controller.myStories.isNotEmpty ? story2Controller.myStories[0].stories.length : 0}",
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ];
                      },
                      body: TabBarView(
                        children: [
                          // All Tab Content
                          CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverList(
                                delegate: SliverChildListDelegate([
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      children: [
                                        if (story2Controller
                                                .myStories
                                                .isNotEmpty &&
                                            story2Controller
                                                .myStories[0]
                                                .stories
                                                .isNotEmpty)
                                          _buildStoryGrid(),
                                        SizedBox(height: 10),
                                        if (profileCnt
                                            .userProfilePostDataPhotoList
                                            .isNotEmpty)
                                          _buildPhotoGrid(),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),

                          // Post Tab Content
                          profileCnt.userProfilePostDataFetched.value
                              ? CustomScrollView(
                                physics: BouncingScrollPhysics(),
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 5,
                                            mainAxisSpacing: 5,
                                          ),
                                      delegate: SliverChildBuilderDelegate(
                                        (BuildContext context, int index) {
                                          final post =
                                              profileCnt
                                                  .userProfilePostDataPhotoList[index];
                                          return PostCard(
                                            image: post.thumbnail,
                                            postCount: post.postCount,
                                            press: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          PostViewScreen(
                                                            postId: post.key,
                                                          ),
                                                ),
                                              );
                                            },
                                            isVideo: post.type,
                                          );
                                        },
                                        childCount:
                                            profileCnt
                                                .userProfilePostDataPhotoList
                                                .length,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : buildCPIWidget(height * 0.5, width),

                          // Stories Tab Content
                          story2Controller.myStories.isNotEmpty
                              ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 5,
                                        mainAxisSpacing: 5,
                                      ),
                                  itemCount:
                                      story2Controller
                                          .myStories[0]
                                          .stories
                                          .length,
                                  itemBuilder: (BuildContext ctx, int index) {
                                    final story =
                                        story2Controller
                                            .myStories[0]
                                            .stories[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: blue,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: PostCard(
                                        image: story.thumbnailUrl,
                                        postCount: "0",
                                        press: () {
                                          Get.to(
                                            () => StoryViewPage(
                                              userStory:
                                                  story2Controller.myStories[0],
                                              initialIndex: index,
                                              myStory: true,
                                            ),
                                          );
                                        },
                                        isVideo:
                                            story.type == StoryType.image
                                                ? "image"
                                                : "Video",
                                      ),
                                    );
                                  },
                                ),
                              )
                              : Center(child: Text("No Stories")),
                        ],
                      ),
                    ),
                  ),
        ),
      ),
    );
  }

  static Future<void> sendFCMNotification({
    required String receiverFcmToken,
    required String title,
    required String body,
    required String type,
  }) async {
    final String serverToken = await getAccessToken();

    final url = Uri.parse(
      "https://fcm.googleapis.com/v1/projects/moral-9f5c7/messages:send",
    );

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $serverToken",
    };

    final bodyData = {
      "message": {
        'token': receiverFcmToken,
        'notification': {'body': body, 'title': title},
        'data': {'type': type},
      },
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyData),
      );
      if (response.statusCode == 200) {
        print("✅ Notification sent successfully!");
      } else {
        print("❌ Failed to send notification: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Error sending notification: $e");
    }
  }

  Future<String?> generateThumbnail(String videoPath) async {
    final thumbnail = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 200,
      quality: 75,
    );
    return thumbnail;
  }

  Widget _buildStoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Padding(
        //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //   child: Text(
        //     'Stories',
        //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        //   ),
        // ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
          ),
          itemCount: story2Controller.myStories[0].stories.length,
          itemBuilder: (BuildContext ctx, int index) {
            final story = story2Controller.myStories[0].stories[index];
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: blue, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: PostCard(
                image: story.thumbnailUrl,
                postCount: "0",
                press: () {
                  Get.to(
                    () => StoryViewPage(
                      userStory: story2Controller.myStories[0],
                      initialIndex: index,
                      myStory: true,
                    ),
                  );
                },
                isVideo: story.type == StoryType.image ? "image" : "Video",
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Padding(
        //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //   child: Text(
        //     'Post',
        //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        //   ),
        // ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
          ),
          itemCount: profileCnt.userProfilePostDataPhotoList.length,
          itemBuilder: (BuildContext ctx, int index) {
            final post = profileCnt.userProfilePostDataPhotoList[index];
            return PostCard(
              image: post.thumbnail,
              postCount: post.postCount,
              press: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostViewScreen(postId: post.key),
                  ),
                );
              },
              isVideo: post.type,
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleIndicator(Map<String, dynamic> schedule) {
    final type = schedule['type'];
    final now = DateTime.now();

    if (type == 'dates') {
      final dates =
          (schedule['dates'] as List<dynamic>)
              .map((t) => (t as cloud.Timestamp).toDate())
              .toList();
      return Text(
        'Scheduled for: ${dates.map((d) => DateFormat('MMM dd, yyyy').format(d)).join(', ')}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    } else {
      final days = (schedule['days'] as List<dynamic>).cast<int>();
      final dayNames = days.map((day) => _getDayName(day)).join(', ');
      return Text(
        'Repeats on: $dayNames',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  Widget _buildAudioControl(Announcement announcement, bool isPlaying) {
    if (announcement.audioUrl.isNotEmpty) {
      return IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          size: 27,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () => _playAudio(announcement.id, announcement.audioUrl),
      );
    } else {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.volume_off, size: 27, color: Colors.grey),
        onSelected: (String choice) {
          if (choice == 'record') {
            _startRecording();
          } else if (choice == 'upload') {
            _uploadAudio();
          }
        },
        itemBuilder:
            (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'record',
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Record Audio'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Upload Audio'),
                  ],
                ),
              ),
            ],
      );
    }
  }

  Widget _buildActionButtons(Announcement announcement, bool isEditing) {
    if (isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () async {
              await _updateAnnouncementTitle(
                announcement.id,
                _titleControllers[announcement.id]!.text,
              );
              setState(() {
                _editTextStates[announcement.id] = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _editTextStates[announcement.id] = false;
                _titleControllers[announcement.id]!.text = announcement.title;
              });
            },
          ),
        ],
      );
    } else {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          if (value == 'edit_text') {
            setState(() => _editTextStates[announcement.id] = true);
          } else if (value == 'delete') {
            await _deleteAnnouncement(announcement.id);
            _cleanupAnnouncementResources(announcement.id);
          } else if (value == 'delete_audio') {
            await _deleteAnnouncementAudio(announcement.id);
          }
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem(value: 'edit_text', child: Text('Edit Text')),
              if (announcement.audioUrl.isNotEmpty)
                const PopupMenuItem(
                  value: 'delete_audio',
                  child: Text('Delete Audio'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
      );
    }
  }

  void _cleanupAnnouncementResources(String announcementId) {
    _titleControllers[announcementId]?.dispose();
    _titleControllers.remove(announcementId);
    _editTextStates.remove(announcementId);
  }

  Future<void> _deleteAnnouncementAudio(String id) async {
    try {
      await _announcementService.deleteAnnouncementAudio(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting audio: ${e.toString()}')),
      );
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Color(0xfff9f6ed), child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

Future<String> getAccessToken() async {
  final serviceAccountJson = {
    "type": "service_account",
    "project_id": "moral-9f5c7",
    "private_key_id": "8f07cce82cc5f0b01c7e2bc7f309f98ebfe0c581",
    "private_key":
        "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQC0eQdmSFMPHQas\nipCe83s8LoNDN0iAxtsk5/kNiKH6GjO9nMgF+YUTKDtP1XfxBIfJtgPQtTjV5FPW\n4HgiiM78x06GHiYTwmKNZZnr8YgIc+M7CdYIP+Nlad3p7TdiA9g4czjHWWseTvl3\nT+vbCyzxvx2MtOHDSVxzQISyF1bmpUWkpdaqs1gYCtO69x51tt67SdMAJ1P4XOhW\ntTvREDfQ6sJqJDinGOjg0kNFWXtjnGhOwE7fs5u/dCbZrkawh6ZVx9i7cQn2OthU\nXeXCfQ0CP1VpaBzgpceZVYCiLe7ck4M+OG2NX8vLORL1haq90ySUhBZTJ6OSCT+W\nnbDz5XE5AgMBAAECggEAWRzj7vjqbm2GNJ9tHteaM9LBxOhg2BmY7wXOQAUF+jGC\n9+8ZA348XAPDGb4N7ggvJoZGJwG88Ty/uzv2hhLopf+iAe6UHbCfqjMPiGYopgfX\nHXlTYpptZc+bIJ2d+bttQh5+3EyGbJ5RZz0i+HNxu2MDq81LJvsr98rVWvzUT6la\nzqjzEmPKLwsiW8AvX1e498XRceWoczh27VNwA9eWh+EHWvGWHNQUp8EyFPFpQ5JU\n0rbjkKkYQqi4d+Vm8Oxr0dqGlQ8Z/m50mxQvnaxhsEpjQXC6Wmkm2GxDj7a82EQF\nZmYrn6ExyqWc3gqXwvP7dAdKRn0Py6ezh+kNKhiKWwKBgQDX4uTba/HNIPkM9/dP\nCpxTosqxViSvzb06zWg/ptmPuaX1/NtapVTuxTZfsH0auIK78oGp4owBJAitwSGU\nnmNYU7qT7l3pI96akR5tZz6ASbSWTUvotu1+bYu9vHk2zoh4Bg6m6zaPnQFpRnyh\nQ1w/WNIYrpCUdjqYQTWuHBaPRwKBgQDWAZzEfcNowoHNmwRv5vasRyURgSJNRDZP\nzEuJ4M/EyrTv9ni7Rlz6O1UuzxO6eAXfiRLwScc47O8EoIbZye+1Ep5RtgFRArVD\nGCcwq01tXFwflpozs/pvP911o8tIxsVpNIkWBEj8a4waetLlgt4pLPmkJBhPBNaJ\nDcjU7lk7fwKBgB3cc31qQ+r0uZ4ymlGjjRYAeXroCHEMyzTb/qR3RrabnjoVPJ4g\nKkxQmQHJXrSYevTWSVsfS/BIdK7b/PIaqnEoO7GEkhbScFL+6a+GTV3fVAxKKsrI\nqrcHHgIjlLyg+r1nURWDiWt58x0Fs+12bMcSWRUy6Cqw48/1jSBFIFW3AoGAHtUI\nov6DgrpTPS4SS5T5AQUXABicuokTUhfa4jhzdqTFwLS/3CtdBeg6c43+B6V3Iyd6\nhQf8HeV04jPGeeYwFORjzt3r/qHnP41hSA/GDfV6iEqIWN6bPB/1Zhd9GDUbB/c7\nsOJZKZTNEJuVet+J5mDGbrGMlwXZatGDl7nnPT0CgYAFk1Q5kg9w+vui7RKuw8RJ\ngg0CxBXTaYcmKP5gnYW7r6QklwTIsNrfBFPypc6iymVwXGIV2Pe7KjMvt9O5jcnA\n8PwFARkcTaP+vliUQe+b+kQkAJYVz3SArjimtZNHyWa1n8Iq52UUJxKZQzWbAxQV\nBtw9YYQKHdXH9qmSoQ25vg==\n-----END PRIVATE KEY-----\n",
    "client_email":
        "firebase-adminsdk-j0vq2@moral-9f5c7.iam.gserviceaccount.com",
    "client_id": "112464179821295423078",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url":
        "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-j0vq2%40moral-9f5c7.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com",
  };

  List<String> scopes = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/firebase.database",
    "https://www.googleapis.com/auth/firebase.messaging",
  ];
  http.Client client = await auth.clientViaServiceAccount(
    auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
    scopes,
  );
  auth.AccessCredentials credentials = await auth
      .obtainAccessCredentialsViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
        scopes,
        client,
      );
  client.close();
  return credentials.accessToken.data;
}
