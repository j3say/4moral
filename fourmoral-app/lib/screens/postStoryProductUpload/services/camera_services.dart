import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  CameraController? _controller;
  bool _isInitialized = false;
  final Set<VoidCallback> _listeners = {};

  factory CameraService() => _instance;
  CameraService._internal();

  Future<bool> initializeCamera() async {
    if (_controller != null && _isInitialized) {
      debugPrint('Camera already initialized');
      return true;
    }

    try {
      // Request camera permission
      final permissionStatus = await Permission.camera.request();
      if (!permissionStatus.isGranted) {
        debugPrint('Camera permission denied');
        _isInitialized = false;
        _notifyListeners();
        return false;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        _isInitialized = false;
        _notifyListeners();
        return false;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      _isInitialized = true;
      debugPrint('Camera initialized successfully');
      _notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _isInitialized = false;
      _notifyListeners();
      return false;
    }
  }

  CameraController? get controller => _controller;

  bool get isInitialized => _isInitialized;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    // Create a copy to avoid concurrent modification
    final listeners = _listeners.toList();
    for (var listener in listeners) {
      listener();
    }
  }

  Future<void> dispose() async {
    if (_controller != null && _isInitialized) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
      debugPrint('Camera disposed');
      _notifyListeners();
    }
  }
}