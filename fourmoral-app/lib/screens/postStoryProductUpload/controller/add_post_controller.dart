import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/post_service_controller.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class AddPostTextController extends GetxController with WidgetsBindingObserver {
  final List<File> files;
  final ProfileModel? profileModel;
  final RxBool uploading = false.obs;
  final RxDouble uploadingPercent = 0.0.obs;
  final RxInt uploadingIndex = 0.obs;
  final RxBool cancelUploadRequested = false.obs;
  final RxInt currentIndex = 0.obs;
  final Rx<VideoPlayerController?> videoController = Rx<VideoPlayerController?>(
    null,
  );
  final RxBool isVideoInitialized = false.obs;
  final RxBool isVideoLoading = false.obs;
  final RxString videoError = ''.obs;
  final RxBool isPlaying = false.obs;
  final RxList<Uint8List> imageBytesList = <Uint8List>[].obs;
  final RxList<String> mediaTypes = <String>[].obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxBool isLocationLoading = false.obs;
  final TextEditingController caption = TextEditingController();
  final Rx<TextEditingController> location = TextEditingController().obs;
  final RxBool shareWithContacts = false.obs;
  final RxList<ContactsModel> selectedContacts = <ContactsModel>[].obs;

  final postServiceController = Get.put(PostServiceController());
  final profileController = Get.put(ProfileController());
  final contactsScreenCnt = Get.put(ContactsScreenCnt());

  String fcmServerKey =
      'AAAAfwomSfk:APA91bH_4SJXRUglhcM0t3Y102vwQlwyGLgBQlHuTP6IbsQwfVjVxdKeA8VrEK2WlNyW0EqS-TR-HZo0YBHUPRG-Yvxc8cVx_vhDx_vPDiG2juWSwKh_4236I76Jp_OeRPpsn7imlxLX';

  AddPostTextController({required this.files, this.profileModel});

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initializeMedia();
    // Fetch location only if needed (user-triggered)
    _getCurrentLocation();
    profileController.initialize(profileModel, profileModel?.mobileNumber);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    videoController.value?.dispose();
    caption.dispose();
    location.value.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      videoController.value?.pause();
      isPlaying.value = false;
      isVideoInitialized.value = false;
    } else if (state == AppLifecycleState.resumed) {
      if (videoController.value != null &&
          videoController.value!.value.isInitialized) {
        videoController.value?.play();
        isPlaying.value = true;
        isVideoInitialized.value = true;
      }
    }
  }

  void _initializeMedia() async {
    imageBytesList.clear();
    mediaTypes.clear();
    for (var file in files) {
      final isVideo = file.path.toLowerCase().endsWith('.mp4');
      if (isVideo) {
        mediaTypes.add('video');
        imageBytesList.add(Uint8List(0)); // Placeholder for videos
        if (files.indexOf(file) == currentIndex.value) {
          await _initializeVideo(file);
        }
      } else {
        mediaTypes.add('image');
        try {
          final bytes = await file.readAsBytes();
          imageBytesList.add(bytes);
        } catch (e) {
          debugPrint("Error loading image bytes: $e");
          imageBytesList.add(Uint8List(0)); // Placeholder for failed images
        }
      }
    }
    imageBytesList.refresh();
    mediaTypes.refresh();
  }

  Future<void> _initializeVideo(File file) async {
    isVideoLoading.value = true;
    videoError.value = '';
    try {
      await videoController.value?.dispose();
      videoController.value = VideoPlayerController.file(file);
      await videoController.value!.initialize();
      videoController.value!.setLooping(true);
      videoController.value!.play();
      isPlaying.value = true;
      isVideoInitialized.value = true;
      isVideoLoading.value = false;
      videoController.refresh();
      debugPrint("Video initialized successfully: ${file.path}");
    } catch (e) {
      debugPrint("Error initializing video: ${file.path}, error: $e");
      videoError.value = "Failed to load video: $e";
      isVideoInitialized.value = false;
      isVideoLoading.value = false;
    }
  }

  void toggleVideoPlayback() {
    if (videoController.value != null) {
      if (isPlaying.value) {
        videoController.value?.pause();
        isPlaying.value = false;
      } else {
        videoController.value?.play();
        isPlaying.value = true;
      }
    }
  }

  void retryVideoLoad(int index) {
    if (index < files.length && mediaTypes[index] == 'video') {
      _initializeVideo(files[index]);
    }
  }

  void openEditor() {
    debugPrint("Opening image editor for file at index ${currentIndex.value}");
    // Implement image editing logic here
  }

  Future<void> _getCurrentLocation() async {
    isLocationLoading.value = true;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        flutterShowToast("Please enable location services.");
        debugPrint("Location services disabled");
        isLocationLoading.value = false;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          flutterShowToast("Location permission denied.");
          debugPrint("Location permission denied");
          isLocationLoading.value = false;
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        flutterShowToast(
          "Location permission permanently denied. Please enable it in settings.",
        );
        debugPrint("Location permission permanently denied");
        isLocationLoading.value = false;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Location fetch timed out");
        },
      );

      currentPosition.value = position;
      debugPrint(
        "Location fetched: ${position.latitude}, ${position.longitude}",
      );

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(
          Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException("Geocoding timed out");
          },
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final formatted =
              "${placemark.locality ?? 'Unknown'}, ${placemark.administrativeArea ?? ''}";
          location.value.text = formatted;
          debugPrint("Location set: $formatted");
        } else {
          location.value.text = "Unknown location";
          debugPrint("No placemarks found");
        }
      } catch (e) {
        debugPrint("Error during geocoding: $e");
        location.value.text = "${position.latitude}, ${position.longitude}";
        flutterShowToast("Failed to fetch address, using coordinates instead.");
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      flutterShowToast("Failed to fetch location: $e");
      location.value.text = "Location unavailable";
    } finally {
      isLocationLoading.value = false;
      location.refresh();
    }
  }

  Future<void> pickLocation(BuildContext context) async {
    final result = await showSearch<String>(
      context: context,
      delegate: LocationSearchDelegate(),
    );

    if (result != null && result.isNotEmpty) {
      location.value.text = result;
      location.refresh();
      debugPrint("Location picked: $result");
    } else {
      await _getCurrentLocation(); // Fetch current location if no search result
    }
  }

  // Send FCM notification to a single device
  // Future<void> sendFCMNotification({
  //   required String receiverFcmToken,
  //   required String title,
  //   required String body,
  //   required String type, // post, story, or chat
  //   required String requestId,
  //   Map<String, String>? data,
  // }) async {
  //   try {
  //     final url = 'https://fcm.googleapis.com/fcm/send';
  //     final headers = {
  //       'Content-Type': 'application/json',
  //       'Authorization': 'key=$fcmServerKey',
  //     };
  //     final payload = {
  //       'to': receiverFcmToken,
  //       'notification': {
  //         'title': title,
  //         'body': body,
  //       },
  //       'data': {
  //         'type': type,
  //         'requestId': requestId,
  //         ...?data,
  //       },
  //     };
  //
  //     final response = await http
  //         .post(Uri.parse(url), headers: headers, body: jsonEncode(payload))
  //         .timeout(Duration(seconds: 10));
  //
  //     if (response.statusCode == 200) {
  //       debugPrint("Notification sent successfully: ${response.body}");
  //     } else {
  //       debugPrint("Failed to send notification: ${response.body}");
  //       flutterShowToast("Failed to send notification");
  //     }
  //   } catch (e) {
  //     debugPrint("Error sending notification: $e");
  //     flutterShowToast("Error sending notification: $e");
  //   }
  // }
  static Future<void> sendFCMNotification({
    required String receiverFcmToken,
    required String title,
    required String body,
    required String type,
    required String requestId,
    Map<String, String>? data,
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
        "token": receiverFcmToken,
        "notification": {"title": title, "body": body},
        'data': {'type': type, 'requestId': requestId, ...?data},
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

  // Send notifications to selected contacts for a post, story, or chat request
  Future<void> sendNotificationsToContacts({
    required List<ContactsModel> contacts,
    required String type, // post, story, or chat
    required String requestId,
    String? postId,
    String? storyId,
  }) async {
    for (var contact in contacts) {
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(contact.uniqueId)
                .get();

        final fcmToken = userDoc.data()?['fcmTokens'][0] as String?;
        if (fcmToken == null || fcmToken.isEmpty) {
          debugPrint("No FCM token found for user: ${contact.uniqueId}");
          continue;
        }

        // Create notification payload
        String title;
        String body;
        Map<String, String> data = {
          'senderId': profileModel?.mobileNumber ?? '',
          'senderName': profileModel?.name ?? 'Unknown',
        };

        if (type == 'post') {
          title = "${profileModel?.name ?? 'Someone'} shared a post with you";
          body = "Check out the new post!";
          data['postId'] = postId ?? '';
        } else if (type == 'story') {
          title = "${profileModel?.name ?? 'Someone'} shared a story with you";
          body = "View the story now!";
          data['storyId'] = storyId ?? '';
        } else {
          title = "${profileModel?.name ?? 'Someone'} sent you a chat request";
          body = "Accept or reject the chat request.";
          data['chatRequestId'] = requestId;
        }

        // Store notification request in Firestore
        final notificationId =
            FirebaseFirestore.instance.collection('notifications').doc().id;

        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .set({
              'notificationId': notificationId,
              'type': type,
              'requestId': requestId,
              'senderId': profileModel?.mobileNumber,
              'receiverId': contact.uniqueId,
              'status': 'pending',
              'title': title,
              'body': body,
              'data': data,
              'timestamp': FieldValue.serverTimestamp(),
            });

        // Send FCM notification
        await sendFCMNotification(
          receiverFcmToken: fcmToken,
          title: title,
          body: body,
          type: type,
          requestId: requestId,
          data: data,
        );
      } catch (e) {
        debugPrint("Error sending notification to ${contact.uniqueId}: $e");
      }
    }
  }

  // Handle accept/reject request
  Future<void> handleRequest({
    required String notificationId,
    required String status, // accepted or rejected
    required String receiverId,
    required String type,
    String? postId,
    String? storyId,
    String? chatRequestId,
  }) async {
    try {
      // Update notification status
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Fetch sender's FCM token
      final senderDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(profileModel?.mobileNumber)
              .get();
      final senderFcmToken = senderDoc.data()?['fcmToken'] as String?;

      if (senderFcmToken != null && senderFcmToken.isNotEmpty) {
        // Send notification to sender
        final title =
            status == 'accepted'
                ? "${profileModel?.name ?? 'Someone'} accepted your $type request"
                : "${profileModel?.name ?? 'Someone'} rejected your $type request";
        final body =
            status == 'accepted'
                ? "Your $type request was accepted!"
                : "Your $type request was rejected.";
        final data = {
          'type': type,
          'requestId': notificationId,
          'receiverId': receiverId,
          if (postId != null) 'postId': postId,
          if (storyId != null) 'storyId': storyId,
          if (chatRequestId != null) 'chatRequestId': chatRequestId,
        };

        await sendFCMNotification(
          receiverFcmToken: senderFcmToken,
          title: title,
          body: body,
          type: type,
          requestId: notificationId,
          data: data,
        );
      }

      if (status == 'accepted') {
        // Update relevant collection based on type
        if (type == 'post') {
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .update({
                'sharedWith': FieldValue.arrayUnion([receiverId]),
              });
        } else if (type == 'story') {
          await FirebaseFirestore.instance
              .collection('stories')
              .doc(storyId)
              .update({
                'sharedWith': FieldValue.arrayUnion([receiverId]),
              });
        } else if (type == 'chat') {
          // Create chat room or update chat status
          final chatRoomId =
              FirebaseFirestore.instance.collection('chatRooms').doc().id;
          await FirebaseFirestore.instance
              .collection('chatRooms')
              .doc(chatRoomId)
              .set({
                'chatRoomId': chatRoomId,
                'participants': [profileModel?.mobileNumber, receiverId],
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        flutterShowToast("$type request $status successfully");
      }
    } catch (e) {
      debugPrint("Error handling $type request: $e");
      flutterShowToast("Error handling request: $e");
    }
  }

  Future<void> uploadPost(BuildContext context) async {
    uploading.value = true;
    cancelUploadRequested.value = false;
    try {
      List<ContactsModel> contactsToShare = [];
      if (shareWithContacts.value && profileController.contactAccount.value) {
        final snapshot =
            await FirebaseFirestore.instance
                .collection('SelectedContacts')
                .doc(profileModel?.mobileNumber)
                .collection('Data')
                .orderBy('timestamp', descending: true)
                .get();

        final querySnapshot = snapshot.docs.map((doc) => doc.data()).toList();

        for (var element in querySnapshot) {
          contactsToShare.add(
            ContactsModel(
              element['receiverName'],
              element['receiverName'],
              '',
              element['receiverPhoneNumber'],
              element['receiverId'],
              isSelected: true,
            ),
          );
        }
      } else if (shareWithContacts.value &&
          !profileController.contactAccount.value) {
        contactsToShare =
            contactsScreenCnt.contactsDataList
                .where((contact) => contact.mobileNumber.isNotEmpty)
                .toList();
      }

      log("contactsToShare: $contactsToShare");

      // Upload post and get post ID
      final postId = await postServiceController.addPostMedia(
        context,
        files,
        profileModel,
        caption,
        true,
        currentPosition.value?.latitude,
        currentPosition.value?.longitude,
        location.value.text,
        onProgressUpdate: (index, percent) {
          uploadingIndex.value = index;
          uploadingPercent.value = percent;
        },
        shouldCancel: () => cancelUploadRequested.value,
        shareWithContacts: shareWithContacts.value,
        contacts: contactsToShare.isNotEmpty ? contactsToShare : null,
      );

      // Send notifications to selected contacts
      if (contactsToShare.isNotEmpty) {
        final requestId =
            FirebaseFirestore.instance.collection('notifications').doc().id;
        await sendNotificationsToContacts(
          contacts: contactsToShare,
          type: 'post',
          requestId: requestId,
          postId: postId,
        );
      }

      flutterShowToast("Post uploaded successfully");
      if (!shareWithContacts.value) {
        flutterShowToast(
          "Post shared ${profileController.privateAccount.value ? 'with followers' : 'publicly'}",
        );
      } else if (contactsToShare.isNotEmpty) {
        flutterShowToast("Post shared with selected contacts");
      } else {
        flutterShowToast("No contacts available to share");
      }
    } catch (e) {
      flutterShowToast("Upload failed: $e");
    } finally {
      uploading.value = false;
    }
  }

  Future<void> sendChatRequest(
    BuildContext context,
    ContactsModel contact,
  ) async {
    try {
      final requestId =
          FirebaseFirestore.instance.collection('notifications').doc().id;
      await sendNotificationsToContacts(
        contacts: [contact],
        type: 'chat',
        requestId: requestId,
      );
      flutterShowToast("Chat request sent to ${contact.username}");
    } catch (e) {
      flutterShowToast("Failed to send chat request: $e");
    }
  }

  void onPageChanged(int index) {
    currentIndex.value = index;
    final file = files[index];
    final isVideo = file.path.toLowerCase().endsWith('.mp4');
    if (isVideo) {
      _initializeVideo(file);
    } else {
      videoController.value?.pause();
      videoController.value?.dispose();
      videoController.value = null;
      isVideoInitialized.value = false;
      isPlaying.value = false;
      debugPrint("Switched to non-video file at index $index");
    }
  }
}

class LocationSearchDelegate extends SearchDelegate<String> {
  List<String> suggestions = [];

  @override
  String get searchFieldLabel => "Search location";

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 18),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(
            suggestions[index],
            style: const TextStyle(color: Colors.black),
          ),
          onTap: () => close(context, suggestions[index]),
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Location>>(
      future: locationFromAddress(query).timeout(Duration(seconds: 5)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final locationData = snapshot.data!.first;
        return FutureBuilder<List<Placemark>>(
          future: placemarkFromCoordinates(
            locationData.latitude,
            locationData.longitude,
          ).timeout(Duration(seconds: 5)),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.data == null || snap.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No location found",
                  style: TextStyle(color: Colors.black),
                ),
              );
            }

            final placemark = snap.data!.first;
            final formatted =
                "${placemark.locality}, ${placemark.administrativeArea}";
            return ListTile(
              title: Text(
                formatted,
                style: const TextStyle(color: Colors.black),
              ),
              onTap: () => close(context, formatted),
            );
          },
        );
      },
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
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
