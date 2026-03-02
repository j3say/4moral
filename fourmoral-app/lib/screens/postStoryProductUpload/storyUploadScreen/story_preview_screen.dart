import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class StoryPreviewScreen extends StatefulWidget {
  final String filePath;
  final String? thumbnailPath;

  const StoryPreviewScreen({
    super.key,
    required this.filePath,
    this.thumbnailPath,
  });

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  VideoPlayerController? _videoController;
  bool isVideoInitialized = false;
  bool isPlaying = false;
  final TextEditingController _captionController = TextEditingController();
  final Story2Controller storyController = Get.find<Story2Controller>();
  bool _thumbnailExists = false;

  @override
  void initState() {
    super.initState();
    storyController.initializeUserData();
    if (widget.filePath.endsWith('.mp4')) {
      _checkThumbnail();
      _initializeVideoPlayer();
    }
  }

  Future<void> _checkThumbnail() async {
    if (widget.thumbnailPath != null) {
      final file = File(widget.thumbnailPath!);
      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _thumbnailExists = exists;
        });
        if (!exists) {
          debugPrint('Thumbnail file does not exist: ${widget.thumbnailPath}');
        }
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        debugPrint('Video file does not exist: ${widget.filePath}');
        return;
      }
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();
      if (mounted) {
        setState(() {
          isVideoInitialized = true;
          isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          isVideoInitialized = false;
          isPlaying = false;
        });
      }
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && isVideoInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        setState(() {
          isPlaying = false;
        });
      } else {
        _videoController!.play();
        setState(() {
          isPlaying = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.filePath.endsWith('.mp4');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        backgroundColor: blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isVideo
                  ? isVideoInitialized && _videoController != null
                  ? Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                  AnimatedOpacity(
                    opacity: isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: _toggleVideoPlayback,
                      child: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
                  : _thumbnailExists && widget.thumbnailPath != null
                  ? Image.file(
                File(widget.thumbnailPath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'Error loading thumbnail',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
                  : const Center(
                child: Text(
                  'Failed to load video',
                  style: TextStyle(color: Colors.white),
                ),
              )
                  : Image.file(
                File(widget.filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'Error loading image',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              maxLines: 3,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      floatingActionButton: Obx(
            () => FloatingActionButton(
          onPressed: storyController.isUploading.value
              ? null
              : () async {
            final file = File(widget.filePath);
            final thumbnailFile = widget.thumbnailPath != null && _thumbnailExists ? File(widget.thumbnailPath!) : null;
            final caption = _captionController.text;
            final type = isVideo ? StoryType.video : StoryType.image;
            await storyController.uploadStory(
              file,
              type,
              caption: caption,
              thumbnailFile: thumbnailFile,
            );
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: storyController.isUploading.value
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.send),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }
}