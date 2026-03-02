import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_controller.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileCnt extends GetxController {
  final homeCnt = Get.put(HomeCnt());

  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');

  // Remove .obs from these - they don't need to be reactive
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode nameFocusNode = FocusNode();
  final FocusNode communityFocusNode = FocusNode();
  final FocusNode ageFocusNode = FocusNode();
  final FocusNode bioFocusNode = FocusNode();
  final FocusNode addressFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode religionFocusNode = FocusNode();

  // Remove .obs from controllers
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController religionController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  File? file;
  RxBool isPhotoUpload = false.obs;
  RxBool loading = false.obs;
  RxBool focusChange = true.obs;
  RxList<String> categories = [''].obs;
  RxBool isLoadingCategories = false.obs;
  RxString selectedType = "".obs;

  @override
  void onClose() {
    // Dispose all controllers and focus nodes
    usernameController.dispose();
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    addressController.dispose();
    emailController.dispose();
    religionController.dispose();

    usernameFocusNode.dispose();
    nameFocusNode.dispose();
    communityFocusNode.dispose();
    ageFocusNode.dispose();
    bioFocusNode.dispose();
    addressFocusNode.dispose();
    emailFocusNode.dispose();
    religionFocusNode.dispose();

    super.onClose();
  }

  void unfocusAllFields() {
    usernameFocusNode.unfocus();
    nameFocusNode.unfocus();
    communityFocusNode.unfocus();
    ageFocusNode.unfocus();
    bioFocusNode.unfocus();
    addressFocusNode.unfocus();
    emailFocusNode.unfocus();
    religionFocusNode.unfocus();
  }

  void editProfileDataGet(ProfileModel? profileObject) {
    loading.value = true;
    usernameController.text = profileObject?.username ?? "";
    bioController.text = profileObject?.bio ?? "";
    nameController.text = profileObject?.name ?? "";
    ageController.text = profileObject?.age ?? "";
    addressController.text = profileObject?.address ?? "";
    emailController.text = profileObject?.emailAddress ?? "";
    religionController.text = profileObject?.religion ?? "";
    file = null;
    loading.value = false;
  }

  void selectDeviceImage(BuildContext context) async {
    try {
      isPhotoUpload.value = true;
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 50,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop the Image',
              toolbarColor: blue,
              toolbarWidgetColor: Colors.white,
              hideBottomControls: true,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              aspectRatioPresets: [CropAspectRatioPreset.square],
            ),
          ],
        );
        var compressedFile = await FlutterImageCompress.compressAndGetFile(
          croppedFile!.path,
          pickedFile.path,
          quality: 50,
        );
        if (compressedFile != null) {
          file = File(compressedFile.path);
        } else {
          Navigator.pop(context);
        }
        Navigator.pop(context);
      }
      isPhotoUpload.value = false;
    } catch (e) {
      isPhotoUpload.value = false;
      flutterShowToast(e.toString());
    }
  }

  void selectCameraImage(BuildContext context) async {
    try {
      isPhotoUpload.value = true;
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 50,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop the Image',
              toolbarColor: blue,
              toolbarWidgetColor: white,
              hideBottomControls: true,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: true,
            ),
          ],
        );
        var compressedFile = await FlutterImageCompress.compressAndGetFile(
          croppedFile!.path,
          pickedFile.path,
          quality: 50,
        );
        if (compressedFile != null) {
          file = File(compressedFile.path);
        } else {
          Navigator.pop(context);
        }
        Navigator.pop(context);
      }
      isPhotoUpload.value = false;
    } catch (e) {
      isPhotoUpload.value = false;
      flutterShowToast(e.toString());
    }
  }

  Future showChoiceDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: white,
          title: Text(
            "Choose option",
            style: TextStyle(fontFamily: 'Neue', color: black),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                ListTile(
                  onTap: () {
                    selectDeviceImage(context);
                  },
                  title: Text(
                    "Gallery",
                    style: TextStyle(fontFamily: 'Neue', color: black),
                  ),
                  leading: Icon(Icons.account_box, color: black),
                ),
                Divider(height: 1, color: black),
                ListTile(
                  onTap: () {
                    selectCameraImage(context);
                  },
                  title: Text(
                    "Camera",
                    style: TextStyle(fontFamily: 'Neue', color: black),
                  ),
                  leading: Icon(Icons.camera, color: black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
