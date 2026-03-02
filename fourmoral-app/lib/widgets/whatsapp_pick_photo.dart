import 'dart:async';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
// import 'package:video_thumbnail/video_thumbnail.dart' as vt;

class WhatsappPickPhoto extends StatefulWidget {
  final String profileuserphone;
  final String userphone;

  const WhatsappPickPhoto({
    super.key,
    required this.profileuserphone,
    required this.userphone,
  });

  @override
  State<WhatsappPickPhoto> createState() => _WhatsappPickPhotoState();
}

class _WhatsappPickPhotoState extends State<WhatsappPickPhoto> {
  CameraLensDirection cameraLensDirection = CameraLensDirection.back;

  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<CameraDescription> camera = [];

  init() async {
    camera = await availableCameras();
    _controller = CameraController(
      camera.firstWhere(
        (camera) => camera.lensDirection == cameraLensDirection,
      ),
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // @override
  // void initState() {
  //   initCamera();
  //   super.initState();
  // }
  // Future<void> initCamera() async {
  //   cameras = await availableCameras();
  //   _cameraController = CameraController(
  //       cameras.firstWhere(
  //           (camera) => camera.lensDirection == cameraLensDirection),
  //       ResolutionPreset.medium);
  //   cameraValue = _cameraController.initialize();
  //   setState(() {});
  // }

  bool isRecording = false;
  bool anyProcess = false;
  bool isFlash = false;

  int pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          FutureBuilder(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: CameraPreview(_controller),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Positioned(
            bottom: 60,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () async {
                      isFlash = !isFlash;
                      setState(() {});
                      if (isFlash) {
                        await _controller.setFlashMode(FlashMode.torch);
                      } else {
                        await _controller.setFlashMode(FlashMode.off);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isFlash
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  pageIndex == 1
                      ? GestureDetector(
                        onTap: () async {
                          await _initializeControllerFuture;
                          setState(() {
                            isRecording = !isRecording;
                          });
                          if (isRecording) {
                            await _controller.startVideoRecording();
                          } else {
                            XFile? videopath =
                                await _controller.stopVideoRecording();

                            setState(() {});
                            if (!mounted) {
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (builder) => VideoViewPage(
                                      path: videopath.path,
                                      userphone: widget.userphone,
                                      profileuserphone: widget.profileuserphone,
                                    ),
                              ),
                            );
                          }
                        },
                        child:
                            isRecording
                                ? const Icon(
                                  Icons.radio_button_on,
                                  color: Colors.red,
                                  size: 70,
                                )
                                : const Icon(
                                  Icons.panorama_fish_eye,
                                  color: Colors.white,
                                  size: 70,
                                ),
                      )
                      : GestureDetector(
                        onTap: () async {
                          await _initializeControllerFuture;

                          setState(() {
                            anyProcess = true;
                          });
                          final image = await _controller.takePicture();

                          if (!mounted) return;

                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (context) => CameraViewPage(
                                    userphone: widget.userphone,
                                    path: image.path,
                                    profileuserphone: widget.profileuserphone,
                                  ),
                            ),
                          );
                          anyProcess = false;

                          setState(() {});
                        },
                        // onLongPressStart: (value) {
                        //   setState(() {
                        //     isRecording = true;
                        //     anyProcess = true;
                        //   });
                        // },
                        // onLongPressEnd: (value) async {
                        //   setState(() {
                        //     isRecording = false;
                        //     anyProcess = false;
                        //   });
                        // },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(width: 2, color: Colors.white),
                          ),
                          width: 63,
                          height: 63,
                          child:
                              anyProcess
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                        ),
                      ),
                  TextButton(
                    onPressed: () {
                      if (cameraLensDirection == CameraLensDirection.front) {
                        cameraLensDirection = CameraLensDirection.back;
                      } else {
                        cameraLensDirection = CameraLensDirection.front;
                      }
                      init();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.cameraswitch,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () {
                      pageIndex = 0;
                      setState(() {});
                    },
                    child: AutoSizeText(
                      'Photo',
                      style: TextStyle(
                        color: pageIndex == 0 ? Colors.white : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      pageIndex = 1;
                      setState(() {});
                    },
                    child: AutoSizeText(
                      'Video',
                      style: TextStyle(
                        color: pageIndex == 1 ? Colors.white : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<CameraDescription> camera = [];

  init() async {
    camera = await availableCameras();
    _controller = CameraController(camera.first, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          try {
            await _initializeControllerFuture;

            final image = await _controller.takePicture();

            if (!mounted) return;

            await Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => DisplayPictureScreen(imagePath: image.path),
              ),
            );
          } catch (e) {
            rethrow;
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: Image.file(File(imagePath)),
    );
  }
}

class CameraViewPage extends StatelessWidget {
  CameraViewPage({
    super.key,
    required this.path,
    required this.profileuserphone,
    required this.userphone,
  });
  final String path;
  final String profileuserphone;
  final String userphone;

  final messageCnt = Get.put(MessageCnt());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Get.back();
          Get.back();
          messageCnt.isUploading.value = true;
          Reference firebaseStorageRef = FirebaseStorage.instance
              .ref()
              .child('Users')
              .child(userphone)
              .child("Photo")
              .child(DateTime.now().toString());
          await firebaseStorageRef.putFile(File(path));
          final url = (await firebaseStorageRef.getDownloadURL()).toString();
          messageCnt.addMessage(
            url,
            type: "image",
            videoUrl: "",
            profileuserphone: profileuserphone,
          );
          messageCnt.isUploading.value = false;
        },
        child: const Icon(Icons.send_rounded),
      ),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        // actions: [
        //   IconButton(
        //       icon: Icon(
        //         Icons.crop_rotate,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        //   IconButton(
        //       icon: Icon(
        //         Icons.emoji_emotions_outlined,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        //   IconButton(
        //       icon: Icon(
        //         Icons.title,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        //   IconButton(
        //       icon: Icon(
        //         Icons.edit,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        // ],
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height - 150,
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
            // Positioned(
            //   bottom: 0,
            //   child: Container(
            //     color: Colors.black38,
            //     width: MediaQuery.of(context).size.width,
            //     padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            //     child: TextFormField(
            //       style: TextStyle(
            //         color: Colors.white,
            //         fontSize: 17,
            //       ),
            //       maxLines: 6,
            //       minLines: 1,
            //       decoration: InputDecoration(
            //           border: InputBorder.none,
            //           hintText: "Add Caption....",
            //           prefixIcon: Icon(
            //             Icons.add_photo_alternate,
            //             color: Colors.white,
            //             size: 27,
            //           ),
            //           hintStyle: TextStyle(
            //             color: Colors.white,
            //             fontSize: 17,
            //           ),
            //           suffixIcon: CircleAvatar(
            //             radius: 27,
            //             backgroundColor: Colors.tealAccent[700],
            //             child: Icon(
            //               Icons.check,
            //               color: Colors.white,
            //               size: 27,
            //             ),
            //           )),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class VideoViewPage extends StatefulWidget {
  const VideoViewPage({
    super.key,
    required this.path,
    required this.profileuserphone,
    required this.userphone,
  });
  final String path;
  final String profileuserphone;
  final String userphone;

  @override
  // ignore: library_private_types_in_public_api
  _VideoViewPageState createState() => _VideoViewPageState();
}

class _VideoViewPageState extends State<VideoViewPage> {
  VideoPlayerController? _controller;
  final messageCnt = Get.put(MessageCnt());

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Get.back();
          Get.back();
          messageCnt.isUploading.value = true;
          Reference firebaseStorageRef = FirebaseStorage.instance
              .ref()
              .child('Users')
              .child(messageCnt.userphone ?? "")
              .child("Video")
              .child(DateTime.now().toString());
          await firebaseStorageRef.putFile(File(widget.path));
          final url = (await firebaseStorageRef.getDownloadURL()).toString();
          // final thumbnail = await vt.VideoThumbnail.thumbnailFile(
          //     video: widget.path,
          //     thumbnailPath: (await getTemporaryDirectory()).path,
          //     imageFormat: vt.ImageFormat.JPEG,
          //     maxHeight: 0,
          //     maxWidth: 0,
          //     quality: 10);

          // messageCnt.thumbnailFile = File(thumbnail!);

          Reference firebaseStorageRefThumbnail = FirebaseStorage.instance
              .ref()
              .child('Users')
              .child(messageCnt.userphone ?? "")
              .child("Video")
              .child("${DateTime.now()} Thumbnail");
          await firebaseStorageRefThumbnail.putFile(
            File(messageCnt.thumbnailFile!.path),
          );
          final thumbnailUrl =
              (await firebaseStorageRefThumbnail.getDownloadURL()).toString();

          messageCnt.addMessage(
            profileuserphone: widget.profileuserphone,
            thumbnailUrl,
            type: "video",
            videoUrl: url,
          );
          messageCnt.isUploading.value = false;
        },
        child: const Icon(Icons.send_rounded),
      ),
      appBar: AppBar(
        backgroundColor: Colors.black,
        // actions: [
        //   IconButton(
        //       icon: Icon(
        //         Icons.crop_rotate,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        //   IconButton(
        //       icon: Icon(
        //         Icons.emoji_emotions_outlined,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        //   IconButton(
        //       icon: Icon(
        //         Icons.title,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        //   IconButton(
        //       icon: Icon(
        //         Icons.edit,
        //         size: 27,
        //       ),
        //       onPressed: () {}),
        // ],
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height - 150,
              child:
                  _controller?.value.isInitialized ?? false
                      ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                      : Container(),
            ),
            // Positioned(
            //   bottom: 0,
            //   child: Container(
            //     color: Colors.black38,
            //     width: MediaQuery.of(context).size.width,
            //     padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            //     child: TextFormField(
            //       style: TextStyle(
            //         color: Colors.white,
            //         fontSize: 17,
            //       ),
            //       maxLines: 6,
            //       minLines: 1,
            //       decoration: InputDecoration(
            //           border: InputBorder.none,
            //           hintText: "Add Caption....",
            //           prefixIcon: Icon(
            //             Icons.add_photo_alternate,
            //             color: Colors.white,
            //             size: 27,
            //           ),
            //           hintStyle: TextStyle(
            //             color: Colors.white,
            //             fontSize: 17,
            //           ),
            //           suffixIcon: CircleAvatar(
            //             radius: 27,
            //             backgroundColor: Colors.tealAccent[700],
            //             child: Icon(
            //               Icons.check,
            //               color: Colors.white,
            //               size: 27,
            //             ),
            //           )),
            //     ),
            //   ),
            // ),
            Align(
              alignment: Alignment.center,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _controller?.value.isPlaying ?? false
                        ? _controller?.pause()
                        : _controller?.play();
                  });
                },
                child: CircleAvatar(
                  radius: 33,
                  backgroundColor: Colors.black38,
                  child: Icon(
                    _controller?.value.isPlaying ?? false
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
