import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/postUploadScreen/post_view_screen.dart';
import 'package:fourmoral/screens/postStoryProductUpload/services/camera_services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

class PostUploadScreen extends StatefulWidget {
  const PostUploadScreen({
    super.key,
    this.profileModel,
    required this.cameraService,
  });

  final ProfileModel? profileModel;
  final CameraService cameraService;

  @override
  State<PostUploadScreen> createState() => _PostUploadScreenState();
}

class _PostUploadScreenState extends State<PostUploadScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final List<Widget> _mediaList = [];
  final List<File> path = [];
  File? _file;
  int currentPage = 0;
  int? lastPage;
  Set<int> selectedIndexes = {};
  List<File> selectedFiles = [];
  int indexx = 0;
  final List<bool> _isVideo = []; // Track whether each media is a video

  @override
  bool get wantKeepAlive => true;
  late final TabController _galleryTabController;

  @override
  void initState() {
    super.initState();
    debugPrint('PostUploadScreen: initState called');
    _fetchNewMedia();
    _galleryTabController = TabController(length: 4, vsync: this);
    _galleryTabController.addListener(() {
      if (_galleryTabController.indexIsChanging) {
        // Reset logic when switching tab
        selectedFiles = [];
        selectedIndexes.clear();
        setState(() {});
        // You can call setState here to clear list
      }
    });
  }

  Future<void> _fetchNewMedia() async {
    try {
      debugPrint('PostUploadScreen: Fetching new media');
      lastPage = currentPage;
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth) {
        List<AssetPathEntity> album = await PhotoManager.getAssetPathList(
          type: RequestType.all,
        );
        List<AssetEntity> media =
            await album.firstOrNull?.getAssetListPaged(
              page: currentPage,
              size: 60,
            ) ??
            [];

        for (var asset in media) {
          if (asset.type == AssetType.image || asset.type == AssetType.video) {
            final file = await asset.file;
            if (file != null) {
              path.add(File(file.path));
              _isVideo.add(asset.type == AssetType.video);
              _file ??= path[0];
            }
          }
        }
        List<Widget> temp = [];
        for (var asset in media) {
          temp.add(
            FutureBuilder(
              future: asset.thumbnailDataWithSize(
                const ThumbnailSize(200, 200),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        snapshot.data as Uint8List,
                        fit: BoxFit.cover,
                      ),
                      if (asset.type == AssetType.video)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            color: Colors.black54,
                            child: Builder(
                              builder: (context) {
                                final duration = Duration(
                                  seconds: asset.duration,
                                );
                                String twoDigits(int n) =>
                                    n.toString().padLeft(2, '0');
                                final minutes = twoDigits(
                                  duration.inMinutes.remainder(60),
                                );
                                final seconds = twoDigits(
                                  duration.inSeconds.remainder(60),
                                );
                                return Text(
                                  '$minutes:$seconds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          );
        }
        if (mounted) {
          setState(() {
            _mediaList.addAll(temp);
            currentPage++;
            debugPrint(
              'PostUploadScreen: Media fetched, total items: ${_mediaList.length}',
            );
          });
        }
      } else {
        debugPrint('PostUploadScreen: Photo permission not granted');
      }
    } catch (e, stackTrace) {
      debugPrint(
        'PostUploadScreen: Error fetching media: $e\nStackTrace: $stackTrace',
      );
    }
  }

  void _openCameraScreen() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => CameraScreen(
                cameraService: widget.cameraService,
                onMediaCaptured: (file, thumbnail, duration) {
                  if (mounted) {
                    setState(() {
                      path.insert(0, file);
                      _file = file;
                      indexx = 0;
                      _isVideo.insert(
                        0,
                        duration != null,
                      ); // Mark as video if duration is provided
                      _mediaList.insert(
                        0,
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            thumbnail != null
                                ? Image.memory(thumbnail, fit: BoxFit.cover)
                                : Image.file(file, fit: BoxFit.cover),
                            if (duration != null)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  color: Colors.black54,
                                  child: Builder(
                                    builder: (context) {
                                      final dur = Duration(seconds: duration);
                                      String twoDigits(int n) =>
                                          n.toString().padLeft(2, '0');
                                      final minutes = twoDigits(
                                        dur.inMinutes.remainder(60),
                                      );
                                      final seconds = twoDigits(
                                        dur.inSeconds.remainder(60),
                                      );
                                      return Text(
                                        '$minutes:$seconds',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                      selectedIndexes = {0};
                      selectedFiles = [file];
                      debugPrint(
                        'PostUploadScreen: Media captured: ${file.path}',
                      );
                    });
                  }
                },
              ),
        ),
      );
    }
  }

  @override
  void dispose() {
    debugPrint('PostUploadScreen: Disposing');
    _galleryTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _openCameraScreen,
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                color: Colors.black,
                child:
                    widget.cameraService.isInitialized &&
                            widget.cameraService.controller != null
                        ? CameraPreview(widget.cameraService.controller!)
                        : const Center(
                          child: Text(
                            'No camera available.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
              ),
            ),
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: TabBar(
                controller: _galleryTabController,
                indicatorColor: Colors.blue,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Recent'),
                  Tab(text: 'Video'),
                  Tab(text: 'All'),
                  Tab(text: 'All Albums'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _galleryTabController,
                children: [
                  GridView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: _mediaList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 1,
                          crossAxisSpacing: 2,
                        ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              int actualIndex = index;
                              _file = path[actualIndex];
                              indexx = actualIndex;

                              if (selectedIndexes.contains(actualIndex)) {
                                selectedIndexes.remove(actualIndex);
                                selectedFiles.remove(path[actualIndex]);
                              } else {
                                selectedIndexes.add(actualIndex);
                                selectedFiles.add(path[actualIndex]);
                              }
                              debugPrint(
                                'PostUploadScreen: Selected media at index $actualIndex',
                              );
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            _mediaList[index],
                            if (selectedIndexes.contains(index))
                              Positioned(
                                top: 5,
                                right: 5,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    '${selectedIndexes.toList().indexOf(index) + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  StatefulBuilder(
                    builder: (context, setState) {
                      final filteredItems = [
                        for (int i = 0; i < _mediaList.length; i++)
                          if (_isVideo[i]) _mediaList[i],
                      ];
                      return GridView.builder(
                        padding: const EdgeInsets.only(top: 4),
                        itemCount: filteredItems.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 1,
                              crossAxisSpacing: 2,
                            ),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              if (mounted) {
                                setState(() {
                                  int actualIndex = index;
                                  _file = path[actualIndex];
                                  indexx = actualIndex;

                                  if (selectedIndexes.contains(actualIndex)) {
                                    selectedIndexes.remove(actualIndex);
                                    selectedFiles.remove(path[actualIndex]);
                                  } else {
                                    selectedIndexes.add(actualIndex);
                                    selectedFiles.add(path[actualIndex]);
                                  }
                                  debugPrint(
                                    'PostUploadScreen: Selected media at index $actualIndex',
                                  );
                                });
                              }
                            },
                            child: Stack(
                              children: [
                                filteredItems[index],
                                if (selectedIndexes.contains(index))
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.blue,
                                      child: Text(
                                        '${selectedIndexes.toList().indexOf(index) + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  GridView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: _mediaList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 1,
                          crossAxisSpacing: 2,
                        ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              int actualIndex = index;
                              _file = path[actualIndex];
                              indexx = actualIndex;

                              if (selectedIndexes.contains(actualIndex)) {
                                selectedIndexes.remove(actualIndex);
                                selectedFiles.remove(path[actualIndex]);
                              } else {
                                selectedIndexes.add(actualIndex);
                                selectedFiles.add(path[actualIndex]);
                              }
                              debugPrint(
                                'PostUploadScreen: Selected media at index $actualIndex',
                              );
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            _mediaList[index],
                            if (selectedIndexes.contains(index))
                              Positioned(
                                top: 5,
                                right: 5,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    '${selectedIndexes.toList().indexOf(index) + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  GridView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: _mediaList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 1,
                          crossAxisSpacing: 2,
                        ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (mounted) {
                            setState(() {
                              int actualIndex = index;
                              _file = path[actualIndex];
                              indexx = actualIndex;

                              if (selectedIndexes.contains(actualIndex)) {
                                selectedIndexes.remove(actualIndex);
                                selectedFiles.remove(path[actualIndex]);
                              } else {
                                selectedIndexes.add(actualIndex);
                                selectedFiles.add(path[actualIndex]);
                              }
                              debugPrint(
                                'PostUploadScreen: Selected media at index $actualIndex',
                              );
                            });
                          }
                        },
                        child: Stack(
                          children: [
                            _mediaList[index],
                            if (selectedIndexes.contains(index))
                              Positioned(
                                top: 5,
                                right: 5,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.blue,
                                  child: Text(
                                    '${selectedIndexes.toList().indexOf(index) + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // if (_mediaList.isEmpty)
            //   Center(
            //     child: Text(
            //       "No Photo Found",
            //       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            //     ),
            //   )
            // else
            //   Expanded(
            //     child: GridView.builder(
            //       padding: const EdgeInsets.only(top: 4),
            //       itemCount: _mediaList.length,
            //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            //         crossAxisCount: 3,
            //         mainAxisSpacing: 1,
            //         crossAxisSpacing: 2,
            //       ),
            //       itemBuilder: (context, index) {
            //         return GestureDetector(
            //           onTap: () {
            //             if (mounted) {
            //               setState(() {
            //                 int actualIndex = index;
            //                 _file = path[actualIndex];
            //                 indexx = actualIndex;
            //
            //                 if (selectedIndexes.contains(actualIndex)) {
            //                   selectedIndexes.remove(actualIndex);
            //                   selectedFiles.remove(path[actualIndex]);
            //                 } else {
            //                   selectedIndexes.add(actualIndex);
            //                   selectedFiles.add(path[actualIndex]);
            //                 }
            //                 debugPrint(
            //                   'PostUploadScreen: Selected media at index $actualIndex',
            //                 );
            //               });
            //             }
            //           },
            //           child: Stack(
            //             children: [
            //               _mediaList[index],
            //               if (selectedIndexes.contains(index))
            //                 Positioned(
            //                   top: 5,
            //                   right: 5,
            //                   child: CircleAvatar(
            //                     radius: 12,
            //                     backgroundColor: Colors.blue,
            //                     child: Text(
            //                       '${selectedIndexes.toList().indexOf(index) + 1}',
            //                       style: const TextStyle(
            //                         color: Colors.white,
            //                         fontSize: 12,
            //                       ),
            //                     ),
            //                   ),
            //                 ),
            //             ],
            //           ),
            //         );
            //       },
            //     ),
            //   ),
          ],
        ),

        if (selectedFiles.isNotEmpty)
          Positioned(
            bottom: 60,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: blue,
              onPressed: () {
                if (mounted) {
                  Get.to(
                    transition: Transition.rightToLeft,
                    duration: const Duration(milliseconds: 500),
                    () => PostViewScreen(
                      files: selectedFiles,
                      profileModel: widget.profileModel,
                    ),
                  );
                }
              },
              child: const Icon(Icons.arrow_forward, color: Colors.black),
            ),
          ),
      ],
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraService cameraService;
  final Function(File, Uint8List?, int?) onMediaCaptured; // Updated callback

  const CameraScreen({
    super.key,
    required this.cameraService,
    required this.onMediaCaptured,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isRecording = false;

  Future<void> _capturePhoto() async {
    try {
      debugPrint('CameraScreen: Capturing photo');
      if (widget.cameraService.isInitialized &&
          widget.cameraService.controller != null &&
          !_isRecording) {
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final XFile photo =
            await widget.cameraService.controller!.takePicture();
        await photo.saveTo(filePath);
        final file = File(filePath);
        widget.onMediaCaptured(
          file,
          null,
          null,
        ); // No thumbnail or duration for photos
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        'CameraScreen: Error capturing photo: $e\nStackTrace: $stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  Future<void> _startVideoRecording() async {
    try {
      debugPrint('CameraScreen: Starting video recording');
      if (widget.cameraService.isInitialized &&
          widget.cameraService.controller != null &&
          !widget.cameraService.controller!.value.isRecordingVideo) {
        await widget.cameraService.controller!.startVideoRecording();
        if (mounted) {
          setState(() {
            _isRecording = true;
            debugPrint('CameraScreen: Video recording started');
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        'CameraScreen: Error starting video recording: $e\nStackTrace: $stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start video recording: $e')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    try {
      debugPrint('CameraScreen: Stopping video recording');
      if (widget.cameraService.isInitialized &&
          widget.cameraService.controller != null &&
          widget.cameraService.controller!.value.isRecordingVideo) {
        final XFile video =
            await widget.cameraService.controller!.stopVideoRecording();
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        await video.saveTo(filePath);
        final file = File(filePath);

        final thumbnailFile = await video_thumbnail
            .VideoThumbnail.thumbnailData(
          video: filePath,
          imageFormat: video_thumbnail.ImageFormat.JPEG,
          maxWidth: 200,
          quality: 75,
        );

        // Get video duration using AssetEntity
        final asset = await PhotoManager.editor.saveVideo(
          file,
          title: path.basename(filePath),
        );
        final duration = asset != null ? (asset.duration) : 0;

        if (mounted) {
          setState(() {
            _isRecording = false;
            debugPrint('CameraScreen: Video captured: $filePath');
          });
          widget.onMediaCaptured(file, thumbnailFile, duration);
          Navigator.pop(context);
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        'CameraScreen: Error stopping video recording: $e\nStackTrace: $stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop video recording: $e')),
        );
      }
    }
  }

  void _handleButtonTap() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _capturePhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          widget.cameraService.isInitialized &&
                  widget.cameraService.controller != null
              ? Positioned.fill(
                child: AspectRatio(
                  aspectRatio:
                      widget.cameraService.controller!.value.aspectRatio,
                  child: CameraPreview(widget.cameraService.controller!),
                ),
              )
              : const Center(
                child: Text(
                  'No camera available.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          if (_isRecording)
            Positioned(
              top: 60,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red,
                child: const Text(
                  'Recording',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 60,
            child: GestureDetector(
              onTap: _handleButtonTap,
              onLongPress: _startVideoRecording,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.grey.shade300,
                    width: _isRecording ? 4.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child:
                    _isRecording
                        ? Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        )
                        : const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
