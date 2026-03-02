import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/homePageScreen/home_controller.dart';
import 'package:get/get.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';

import '../../services/random_key_generator.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../../widgets/flutter_toast.dart';
import '../navigationBar/navigation_bar.dart';

final homeCnt = Get.put(HomeCnt());

addStoryPhoto(
  context,
  file,
  profileModel,
  collectionUserReference,
  whatsOnYourMindController,
  formKey,
) async {
  if (formKey.currentState.validate()) {
    buildCPI(context);
    try {
      String url = 'null';

      if (file != null) {
        Reference firebaseStorageRef = FirebaseStorage.instance
            .ref()
            .child('Users')
            .child(profileModel.mobileNumber)
            .child("Story")
            .child("Photo")
            .child(DateTime.now().toString());
        await firebaseStorageRef.putFile(file);
        url = (await firebaseStorageRef.getDownloadURL()).toString();
      }

      FirebaseDatabase.instance
          .ref()
          .child('Stories')
          .child(profileModel.mobileNumber)
          .update({'lastStoryTime': DateTime.now().toString()});

      FirebaseDatabase.instance
          .ref()
          .child('Stories')
          .child(profileModel.mobileNumber)
          .child('data')
          .push()
          .set({
            'key': getRandomString(10),
            'url': url,
            'dateTime': DateTime.now().toString(),
            'profilePicture': profileModel.profilePicture,
            'username': profileModel.username,
            'caption': whatsOnYourMindController.text,
            'mobileNumber': profileModel.mobileNumber,
            'type': "Photo",
            'actype': profileModel.type,
          });

      homeCnt.storyDataFetched.value = false;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => NavigationBarCustom(
                userPhoneNumber: profileModel.mobileNumber,
                indexSent: 0,
              ),
        ),
      );

      flutterShowToast("Story Uploaded");
    } catch (e) {
      flutterShowToast(e.toString());
      Navigator.pop(context);
    }
  }
}

addStoryVideo(
  context,
  videoFile,
  profileModel,
  tempDir,
  collectionUserReference,
  whatsOnYourMindController,
  formKey,
) async {
  if (formKey.currentState.validate()) {
    buildCPI(context);

    try {
      String url = 'null';
      String thumbnailUrl = "null";
      if (videoFile != null) {
        Reference firebaseStorageRef = FirebaseStorage.instance
            .ref()
            .child('Users')
            .child(profileModel.mobileNumber)
            .child("Story")
            .child("Video")
            .child(DateTime.now().toString());
        await firebaseStorageRef.putFile(videoFile);
        url = (await firebaseStorageRef.getDownloadURL()).toString();

        // final thumbnail = await VideoThumbnail.thumbnailFile(
        //     video: videoFile.path,
        //     thumbnailPath: tempDir,
        //     imageFormat: ImageFormat.JPEG,
        //     maxHeight: 0,
        //     maxWidth: 0,
        //     quality: 10);

        // File thumbnailFile = File(thumbnail!);

        Reference firebaseStorageRefThumbnail = FirebaseStorage.instance
            .ref()
            .child('Users')
            .child(profileModel.mobileNumber)
            .child("Story")
            .child("Video")
            .child("${DateTime.now()} Thumbnail");

        // await firebaseStorageRefThumbnail.putFile(thumbnailFile);

        thumbnailUrl =
            (await firebaseStorageRefThumbnail.getDownloadURL()).toString();

        FirebaseDatabase.instance
            .ref()
            .child('Stories')
            .child(profileModel.mobileNumber)
            .update({'lastStoryTime': DateTime.now().toString()});

        FirebaseDatabase.instance
            .ref()
            .child('Stories')
            .child(profileModel.mobileNumber)
            .child('data')
            .push()
            .set({
              'key': getRandomString(10),
              'url': url,
              'dateTime': DateTime.now().toString(),
              'profilePicture': profileModel.profilePicture,
              'username': profileModel.username,
              'caption': whatsOnYourMindController.text,
              'mobileNumber': profileModel.mobileNumber,
              'thumbnail': thumbnailUrl,
              'type': "Video",
              'actype': profileModel.type,
            });

        homeCnt.storyDataFetched.value = false;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => NavigationBarCustom(
                  userPhoneNumber: profileModel.mobileNumber,
                  indexSent: 0,
                ),
          ),
        );

        flutterShowToast("Story Uploaded");
      }
    } catch (e) {
      flutterShowToast(e.toString());
      Navigator.pop(context);
    }
  }
}
