import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/services/camera_services.dart';
import 'package:get/get.dart';
import 'package:async/async.dart';
import 'package:permission_handler/permission_handler.dart';

class AddPostStoryProductController extends GetxController {
  final CameraService cameraService = CameraService();
  CancelableOperation<void>? cameraInitOperation;
  final RxString appBarTitle = 'New Post'.obs;
  final RxBool isCameraLoading = true.obs;
  final RxBool isCameraPermissionDenied = false.obs;
  late TabController tabController;
  final ProfileModel? profileModel;
  final bool isBusinessAccount;

  AddPostStoryProductController(this.profileModel)
      : isBusinessAccount = profileModel?.type.toLowerCase() == 'business';

  void initialize(TickerProvider vsync) {
    tabController = TabController(
      length: isBusinessAccount ? 3 : 2,
      vsync: vsync,
    );
    tabController.addListener(_updateAppBarTitle);
    cameraService.addListener(_onCameraStateChanged);
    _initializeCamera();
  }

  void _updateAppBarTitle() {
    if (!tabController.indexIsChanging) {
      appBarTitle.value = tabController.index == 1
          ? 'New Story'
          : isBusinessAccount && tabController.index == 2
          ? 'New Product'
          : 'New Post';
    }
  }

  Future<void> _initializeCamera() async {
    cameraInitOperation = CancelableOperation.fromFuture(
      cameraService.initializeCamera().then((success) {
        isCameraLoading.value = false;
        isCameraPermissionDenied.value = !success;
      }),
    );
    await cameraInitOperation?.valueOrCancellation();
  }

  void _onCameraStateChanged() {
    isCameraLoading.value = false;
    isCameraPermissionDenied.value = !cameraService.isInitialized;
  }

  Future<void> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      isCameraLoading.value = true;
      isCameraPermissionDenied.value = false;
      await _initializeCamera();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is required.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  @override
  void onClose() {
    cameraInitOperation?.cancel();
    tabController.dispose();
    cameraService.removeListener(_onCameraStateChanged);
    cameraService.dispose();
    super.onClose();
  }
}