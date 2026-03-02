import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';
// import 'package:gallery_picker/gallery_picker.dart';
import 'package:get/get.dart';

UploadTask? uploadTask;

Widget buildProgress() => StreamBuilder(
  stream: uploadTask?.snapshotEvents,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final data = snapshot.data;
      double progress = data!.bytesTransferred / data.totalBytes;
      return Text(
        "${(100 * progress).roundToDouble()}%",
        style: const TextStyle(color: Colors.red),
      );
    } else {
      return const SizedBox();
    }
  },
);

class MultipleMediasView extends StatefulWidget {
  final List? medias;
  final String? userphone;
  final String? profileuserphone;
  final bool? doubleBack;

  const MultipleMediasView({
    super.key,
    this.medias,
    this.userphone,
    this.profileuserphone,
    this.doubleBack,
  });

  @override
  State<MultipleMediasView> createState() => _MultipleMediasViewState();
}

class _MultipleMediasViewState extends State<MultipleMediasView> {
  List selectedMedias = [];

  final messageCnt = Get.put(MessageCnt());

  @override
  void initState() {
    selectedMedias.clear();
    if (widget.medias != null) {
      selectedMedias = widget.medias!;
    }
    setState(() {});
    super.initState();
  }

  int pageIndex = 0;
  var controller = PageController(initialPage: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              selectedMedias.isNotEmpty
                  ? SizedBox(
                    height: MediaQuery.of(context).size.height - 150,
                    child: PageView(
                      controller: controller,
                      onPageChanged: (value) {
                        pageIndex = value;
                        setState(() {});
                      },
                      children: [
                        // for (var media in selectedMedias)
                        //   Center(
                        //       child: MediaProvider(
                        //           media: media,
                        //           height: MediaQuery.of(context).size.height -
                        //               150),
                        //               )
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
              SizedBox(
                height: 65,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < selectedMedias.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: TextButton(
                          onPressed: () {
                            pageIndex = i;
                            controller.animateToPage(
                              pageIndex,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeIn,
                            );
                            setState(() {});
                          },
                          child: Container(
                            width: 65,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 2,
                                color:
                                    pageIndex == i
                                        ? Colors.black
                                        : Colors.white,
                              ),
                            ),
                            // child: ThumbnailMedia(
                            //   media: selectedMedias[i],
                            // ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            for (int i = 0; i < selectedMedias.length; i++) {
              if (selectedMedias[i].isImage) {
                selectedMedias[i].getFile().then((value) async {
                  messageCnt.isUploading.value = true;
                  Reference firebaseStorageRef = FirebaseStorage.instance
                      .ref()
                      .child('Users')
                      .child(widget.userphone ?? "")
                      .child("Photo")
                      .child(DateTime.now().toString());
                  await firebaseStorageRef.putFile(File(value.path));
                  final url =
                      (await firebaseStorageRef.getDownloadURL()).toString();
                  messageCnt.addMessage(
                    url,
                    type: "image",
                    videoUrl: "",
                    profileuserphone: widget.profileuserphone ?? "",
                  );
                  messageCnt.isUploading.value = false;
                });
              } else {
                selectedMedias[i].getFile().then((value) async {
                  messageCnt.isUploading.value = true;

                  Reference firebaseStorageRef = FirebaseStorage.instance
                      .ref()
                      .child('Users')
                      .child(messageCnt.userphone ?? "")
                      .child("Video")
                      .child(DateTime.now().toString());
                  await firebaseStorageRef.putFile(File(value.path));
                  final url =
                      (await firebaseStorageRef.getDownloadURL()).toString();
                  // final thumbnail = await VideoThumbnail.thumbnailFile(
                  //     video: value.path,
                  //     thumbnailPath: (await getTemporaryDirectory()).path,
                  //     imageFormat: ImageFormat.JPEG,
                  //     maxHeight: 0,
                  //     maxWidth: 0,
                  //     quality: 10);

                  // messageCnt.thumbnailFile = File(thumbnail!);

                  Reference firebaseStorageRefThumbnail = FirebaseStorage
                      .instance
                      .ref()
                      .child('Users')
                      .child(messageCnt.userphone ?? "")
                      .child("Video")
                      .child("${DateTime.now()} Thumbnail");
                  await firebaseStorageRefThumbnail.putFile(
                    File(messageCnt.thumbnailFile!.path),
                  );
                  final thumbnailUrl =
                      (await firebaseStorageRefThumbnail.getDownloadURL())
                          .toString();

                  messageCnt.addMessage(
                    profileuserphone: widget.profileuserphone ?? "",
                    thumbnailUrl,
                    type: "video",
                    videoUrl: url,
                  );
                  messageCnt.isUploading.value = false;
                });
              }
            }
            Navigator.pop(context);
          } catch (e) {
            print("ERROR $e");
          }
        },
        child: const Icon(Icons.send_rounded),
      ),
    );
  }
}
