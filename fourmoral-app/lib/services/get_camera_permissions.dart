import 'package:permission_handler/permission_handler.dart';

Future<PermissionStatus> getCameraPermission() async {
  PermissionStatus permission = await Permission.camera.status;
  if (permission != PermissionStatus.granted &&
      permission != PermissionStatus.permanentlyDenied) {
    PermissionStatus permissionStatus = await Permission.contacts.request();
    return permissionStatus;
  } else {
    return permission;
  }
}

Future<PermissionStatus> getStoragePermission() async {
  PermissionStatus permission = await Permission.storage.status;
  if (permission != PermissionStatus.granted &&
      permission != PermissionStatus.permanentlyDenied) {
    PermissionStatus permissionStatus = await Permission.contacts.request();
    return permissionStatus;
  } else {
    return permission;
  }
}
