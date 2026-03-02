import 'dart:io';
import 'dart:typed_data';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/circular_progress_indicator.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? videoLink;
  final Uint8List? decryptedFileBytes;

  const VideoPlayerScreen({super.key, this.videoLink, this.decryptedFileBytes});

  @override
  // ignore: library_private_types_in_public_api
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  double? height, width;

  VideoPlayerController? _controller;

  ChewieController? chewieController;

  Chewie? playerWidget;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.decryptedFileBytes != null) {
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/temp_video.mp4');
      await tempFile.writeAsBytes(widget.decryptedFileBytes!);
      _controller = VideoPlayerController.file(tempFile);
    } else if (widget.videoLink != null) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoLink!),
      );
    } else {
      throw Exception("No video source provided.");
    }

    await _controller!.initialize();

    chewieController = ChewieController(
      videoPlayerController: _controller!,
      autoPlay: true,
      looping: true,
      autoInitialize: true,
    );

    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    width = size.width;
    height = size.height;
    return SafeArea(
      child: Scaffold(
        extendBody: true,
        body: SizedBox(
          height: height,
          width: width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: height! * 0.8,
                width: width,
                child: Center(
                  child:
                      _controller?.value.isInitialized ?? false
                          ? Chewie(controller: chewieController!)
                          : buildCPIWidget(height, width),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
