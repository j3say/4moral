import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:fourmoral/widgets/upload_bar.dart';
import 'package:provider/provider.dart';
import 'package:fourmoral/services/random_key_generator.dart';
import 'package:fourmoral/screens/navigationBar/navigation_bar.dart';

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

final ValueNotifier<double> percentNotifier = ValueNotifier(0.0);
final ValueNotifier<int> fileIndexNotifier = ValueNotifier(0);
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

class PostServiceController extends GetxController {
  Future<void> showUploadNotification(
      int id,
      String title,
      String body, {
        int progress = 0,
        bool indeterminate = false,
      }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'upload_channel',
      'Uploads',
      channelDescription: 'Notifications for upload progress',
      importance: Importance.max,
      priority: Priority.high,
      showProgress: true,
      maxProgress: 100,
      indeterminate: false,
      onlyAlertOnce: true,
    );
    final AndroidNotificationDetails androidPlatformChannelSpecificsProgress =
    AndroidNotificationDetails(
      'upload_channel',
      'Uploads',
      channelDescription: 'Notifications for upload progress',
      importance: Importance.max,
      priority: Priority.high,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      indeterminate: indeterminate,
      onlyAlertOnce: true,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: progress == 0 && indeterminate == false
          ? androidPlatformChannelSpecifics
          : androidPlatformChannelSpecificsProgress,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<String> addPostMedia(
      BuildContext context,
      List<File> mediaFiles,
      ProfileModel? profileModel,
      TextEditingController captionController,
      bool includeLocation,
      double? latitude,
      double? longitude,
      String location, {
        required Function(int index, double percent) onProgressUpdate,
        required bool Function() shouldCancel,
        bool shareWithContacts = false,
        List<ContactsModel>? contacts,
      }) async {
    if (profileModel == null) {
      flutterShowToast("User profile not available");
      return '';
    }

    List<String> mediaUrls = [];
    List<String> thumbnailUrls = [];
    List<String> mediaTypes = [];
    List<String> fileExtensions = [];

    final uploadManager = Provider.of<UploadManager>(context, listen: false);

    final int totalFilesCount = mediaFiles.length;
    int completedFilesCount = 0;

    for (int i = 0; i < mediaFiles.length; i++) {
      if (shouldCancel()) {
        flutterShowToast("Upload cancelled");
        return '';
      }

      final file = mediaFiles[i];
      final isVideo = _isVideoFile(file);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final extension = file.path.split('.').last.toLowerCase();
      fileExtensions.add(extension);

      final storagePath =
          'Users/${profileModel.mobileNumber}/${isVideo ? "Video" : "Photo"}/$timestamp.$extension';

      // Add upload task
      uploadManager.addTask(file, storagePath);

      // Wait for upload to complete or fail
      UploadTaskModel? task;
      do {
        await Future.delayed(const Duration(milliseconds: 200));
        task = uploadManager.tasks.firstWhereOrNull(
              (t) => t.storagePath == storagePath,
        );
        if (shouldCancel()) {
          flutterShowToast("Upload cancelled");
          return '';
        }
        if (task != null) {
          onProgressUpdate(i, task.progress);
        }
      } while (task != null && task.status == UploadStatus.uploading);

      if (task == null || task.status != UploadStatus.completed) {
        flutterShowToast("Upload failed for file ${i + 1}");
        continue;
      }

      completedFilesCount++;

      // Get download URL
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final url = await storageRef.getDownloadURL();
      mediaUrls.add(url);
      mediaTypes.add(isVideo ? "Video" : "Photo");

      // Handle thumbnail if video
      if (isVideo) {
        final thumbnailFile = await _generateVideoThumbnail(
          file,
          timestamp,
          profileModel.mobileNumber,
        );
        if (thumbnailFile != null) {
          final thumbRef = FirebaseStorage.instance
              .ref()
              .child('Users')
              .child(profileModel.mobileNumber)
              .child("Thumbnails")
              .child('$timestamp.jpg');

          // Retry thumbnail upload
          const int maxRetries = 3;
          int attempt = 0;
          bool thumbUploadSuccess = false;

          while (attempt < maxRetries && !thumbUploadSuccess) {
            if (shouldCancel()) {
              flutterShowToast("Upload cancelled");
              return '';
            }
            try {
              await thumbRef.putFile(thumbnailFile);
              thumbUploadSuccess = true;
            } catch (_) {
              attempt++;
              if (attempt >= maxRetries) rethrow;
              await Future.delayed(const Duration(seconds: 2));
            }
          }

          final thumbUrl = await thumbRef.getDownloadURL();
          thumbnailUrls.add(thumbUrl);
        } else {
          thumbnailUrls.add("null");
        }
      } else {
        thumbnailUrls.add(url);
      }
    }

    debugPrint('Upload completed: $completedFilesCount / $totalFilesCount files uploaded successfully.');

    // Create Firestore post and get postId
    final postId = await _createPostDocument(
      profileModel,
      mediaUrls,
      thumbnailUrls,
      mediaTypes,
      fileExtensions,
      captionController.text,
      includeLocation,
      latitude,
      longitude,
      location,
      shareWithContacts: shareWithContacts,
      contacts: contacts,
    );

    // Clean up completed uploads
    if (!uploadManager.tasks.any((t) => t.status == UploadStatus.uploading)) {
      await Future.delayed(const Duration(seconds: 2));
      uploadManager.removeCompletedTasks();
    }

    // Navigate back to home
    Get.offAll(
      NavigationBarCustom(
        userPhoneNumber: profileModel.mobileNumber,
        indexSent: 0,
      ),
    );

    return postId;
  }

  Future<File?> _generateVideoThumbnail(
      File videoFile,
      String timestamp,
      String userId,
      ) async {
    try {
      if (!videoFile.existsSync()) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );

      debugPrint("thumbPath $thumbPath");
      if (thumbPath == null) {
        return null;
      }

      final thumbnailFile = File(thumbPath);
      debugPrint("thumbnailFile $thumbnailFile");
      return thumbnailFile;
    } catch (e) {
      debugPrint("Thumbnail generation failed: $e");
      return null;
    }
  }

  Future<String> _createPostDocument(
      ProfileModel profileModel,
      List<String> mediaUrls,
      List<String> thumbnailUrls,
      List<String> mediaTypes,
      List<String> fileExtensions,
      String caption,
      bool includeLocation,
      double? latitude,
      double? longitude,
      String location, {
        bool shareWithContacts = false,
        List<ContactsModel>? contacts,
      }) async {
    final postRef = FirebaseFirestore.instance.collection('Posts').doc(); // Generate new document ID
    await postRef.set({
      'key': getRandomString(10),
      'postId': postRef.id, // Add postId to the document
      'urls': mediaUrls,
      'thumbnails': thumbnailUrls,
      'mediaTypes': mediaTypes,
      'fileExtensions': fileExtensions,
      'dateTime': DateTime.now().toString(),
      'caption': caption,
      'profilePicture': profileModel.profilePicture,
      'username': profileModel.username,
      'mobileNumber': profileModel.mobileNumber,
      'type': "Post",
      'likesUsers': '',
      'actype': profileModel.type,
      'numberOfLikes': '0',
      'hasLocation': includeLocation,
      'latitude': includeLocation ? latitude : null,
      'longitude': includeLocation ? longitude : null,
      'location': location,
      'shareWithContacts': shareWithContacts,
      if (shareWithContacts && contacts != null && contacts.isNotEmpty)
        'sharedWith': FieldValue.arrayUnion(contacts.map((contact) => {
          'receiverId': contact.uniqueId, // Changed from uniqueId to receiverId for consistency
          'receiverPhoneNumber': contact.mobileNumber,
          'receiverName': contact.name,
        }).toList()),
    });

    return postRef.id; // Return the postId
  }

  bool _isVideoFile(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.mkv');
  }
}

class AddPostTextController extends GetxController {
  final List<File> files;
  final ProfileModel? profileModel;
  final RxInt currentIndex = 0.obs;
  final RxBool uploading = false.obs;
  final RxBool isLocationLoading = false.obs;
  final TextEditingController location = TextEditingController();
  final TextEditingController caption = TextEditingController();
  final Rx<VideoPlayerController?> videoController = Rx<VideoPlayerController?>(null);
  final RxBool isVideoLoading = false.obs;
  final RxString videoError = ''.obs;
  final PostServiceController postServiceController = Get.put(PostServiceController());

  AddPostTextController({required this.files, this.profileModel});

  @override
  void onInit() {
    super.onInit();
    _initializeVideoController(currentIndex.value);
  }

  Future<void> _initializeVideoController(int index) async {
    if (index >= files.length || !postServiceController._isVideoFile(files[index])) {
      videoController.value?.dispose();
      videoController.value = null;
      isVideoLoading.value = false;
      videoError.value = '';
      update();
      return;
    }

    isVideoLoading.value = true;
    videoError.value = '';
    await videoController.value?.dispose();

    try {
      videoController.value = VideoPlayerController.file(files[index])
        ..addListener(() {
          update(); // Trigger UI rebuild on controller state changes
        });
      await videoController.value!.initialize();
      isVideoLoading.value = false;
      update();
    } catch (e) {
      videoError.value = 'Failed to load video: $e';
      isVideoLoading.value = false;
      debugPrint(videoError.value);
      update();
    }
  }

  void onPageChanged(int index) {
    currentIndex.value = index;
    _initializeVideoController(index);
  }

  void retryVideoLoad(int index) {
    _initializeVideoController(index);
  }

  void toggleVideoPlayback() {
    if (videoController.value != null && videoController.value!.value.isInitialized) {
      if (videoController.value!.value.isPlaying) {
        videoController.value!.pause();
      } else {
        videoController.value!.play();
      }
      // The listener on videoController triggers UI updates
    }
  }

  Future<void> pickLocation(BuildContext context) async {
    final result = await showSearch(context: context, delegate: LocationSearchDelegate());
    if (result != null && result.isNotEmpty) {
      location.text = result;
    }
  }

  Future<void> uploadPost(BuildContext context) async {
    uploading.value = true;
    await postServiceController.addPostMedia(
      context,
      files,
      profileModel,
      caption,
      location.text.isNotEmpty,
      null, // Latitude (not implemented in UI yet)
      null, // Longitude (not implemented in UI yet)
      location.text,
      onProgressUpdate: (index, percent) {
        percentNotifier.value = percent;
        fileIndexNotifier.value = index;
        postServiceController.showUploadNotification(
          index,
          'Uploading File ${index + 1}',
          'Progress: ${(percent * 100).toInt()}%',
          progress: (percent * 100).toInt(),
        );
      },
      shouldCancel: () => false, // Implement cancellation logic if needed
    );
    uploading.value = false;
  }

  @override
  void onClose() {
    videoController.value?.dispose();
    location.dispose();
    caption.dispose();
    super.onClose();
  }
}

class AddPostTextScreen extends StatelessWidget {
  final List<File> files;
  final ProfileModel? profileModel;

  const AddPostTextScreen({super.key, required this.files, this.profileModel});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddPostTextController(files: files, profileModel: profileModel));

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: blue,
            elevation: 0,
            title: const Text('New Post', style: TextStyle(color: Colors.black)),
            centerTitle: false,
          ),
          floatingActionButton: GetBuilder<AddPostTextController>(
            builder: (controller) => FloatingActionButton(
              backgroundColor: controller.uploading.value ? Colors.grey : blue,
              onPressed: controller.uploading.value ? null : () => controller.uploadPost(context),
              child: const Icon(Icons.arrow_right_alt_rounded, color: Colors.black, size: 30),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SizedBox(
                            height: 500,
                            width: double.infinity,
                            child: PageView.builder(
                              itemCount: controller.files.length,
                              onPageChanged: controller.onPageChanged,
                              itemBuilder: (context, index) {
                                final file = controller.files[index];
                                final isVideo = file.path.toLowerCase().endsWith('.mp4');
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: isVideo
                                      ? GetBuilder<AddPostTextController>(
                                    builder: (controller) {
                                      if (controller.isVideoLoading.value) {
                                        return Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(
                                            color: Colors.grey[300],
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        );
                                      }
                                      if (controller.videoError.value.isNotEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                controller.videoError.value,
                                                style: const TextStyle(color: Colors.white),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 10),
                                              ElevatedButton(
                                                onPressed: () => controller.retryVideoLoad(index),
                                                child: const Text("Retry"),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      if (controller.videoController.value == null ||
                                          !controller.videoController.value!.value.isInitialized) {
                                        return Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(
                                            color: Colors.grey[300],
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        );
                                      }
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AspectRatio(
                                            aspectRatio: controller.videoController.value!.value.aspectRatio,
                                            child: VideoPlayer(controller.videoController.value!),
                                          ),
                                          GetBuilder<AddPostTextController>(
                                            builder: (controller) => AnimatedOpacity(
                                              opacity: controller.videoController.value?.value.isPlaying ?? false
                                                  ? 0.0
                                                  : 1.0,
                                              duration: const Duration(milliseconds: 300),
                                              child: GestureDetector(
                                                onTap: controller.toggleVideoPlayback,
                                                child: Icon(
                                                  controller.videoController.value?.value.isPlaying ?? false
                                                      ? Icons.pause_circle_filled
                                                      : Icons.play_circle_filled,
                                                  size: 60,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  )
                                      : Image.file(file, fit: BoxFit.cover),
                                );
                              },
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GetBuilder<AddPostTextController>(
                              builder: (controller) => Text(
                                "${controller.currentIndex.value + 1} / ${controller.files.length}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        GetBuilder<AddPostTextController>(
                          builder: (controller) => ListTile(
                            leading: const Icon(Icons.location_on_outlined, color: Colors.black),
                            title: controller.isLocationLoading.value
                                ? Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                color: Colors.grey[300],
                                width: 100,
                                height: 20,
                              ),
                            )
                                : Text(
                              controller.location.text.isEmpty ? "Add location" : controller.location.text,
                              style: const TextStyle(color: Colors.black),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.black),
                            onTap: controller.isLocationLoading.value ? null : () => controller.pickLocation(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 0),
                        const SizedBox(height: 20),
                        TextField(
                          controller: controller.caption,
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Write a caption...",
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
      future: locationFromAddress(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: ListView(
              children: List.generate(
                5,
                    (index) => ListTile(
                  title: Container(
                    color: Colors.grey[300],
                    height: 20,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          );
        }

        final locationData = snapshot.data!.first;
        return FutureBuilder<List<Placemark>>(
          future: placemarkFromCoordinates(locationData.latitude, locationData.longitude),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: ListView(
                  children: List.generate(
                    5,
                        (index) => ListTile(
                      title: Container(
                        color: Colors.grey[300],
                        height: 20,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ),
              );
            }

            if (snap.data == null || snap.data!.isEmpty) {
              return const Center(
                child: Text("No location found", style: TextStyle(color: Colors.black)),
              );
            }

            final placemark = snap.data!.first;
            final formatted = "${placemark.locality}, ${placemark.administrativeArea}";
            return ListTile(
              title: Text(formatted, style: const TextStyle(color: Colors.black)),
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