import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:fourmoral/models/product_model.dart';

class MediaSlider extends StatefulWidget {
  final List<ProductMedia> mediaItems;

  const MediaSlider({super.key, required this.mediaItems});

  @override
  _MediaSliderState createState() => _MediaSliderState();
}

class _MediaSliderState extends State<MediaSlider> {
  late PageController _pageController;
  int _currentPage = 0;
  final List<VideoPlayerController?> _videoControllers = [];
  final List<ChewieController?> _chewieControllers = [];
  final List<bool> _videoInitialized = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeVideoPlayers();
  }

  void _initializeVideoPlayers() async {
    for (var media in widget.mediaItems) {
      if (media.type == 'video') {
        final controller = VideoPlayerController.network(media.url);
        _videoControllers.add(controller);
        _chewieControllers.add(null);
        _videoInitialized.add(false);

        try {
          await controller.initialize();
          if (mounted) {
            setState(() {
              _chewieControllers[_chewieControllers.length -
                  1] = ChewieController(
                videoPlayerController: controller,
                autoPlay: false,
                looping: false,
                aspectRatio: controller.value.aspectRatio,
              );
              _videoInitialized[_videoInitialized.length - 1] = true;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _videoInitialized[_videoInitialized.length - 1] = true;
            });
          }
        }
      } else {
        _videoControllers.add(null);
        _chewieControllers.add(null);
        _videoInitialized.add(true);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers) {
      controller?.dispose();
    }
    for (var controller in _chewieControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: Stack(
        children: [
          Center(child: CircularProgressIndicator()),
          Center(
            child: Icon(
              Icons.videocam,
              size: 50,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 8),
            Text('Failed to load video', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaItems.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);

              for (var controller in _videoControllers) {
                if (controller?.value.isPlaying ?? false) {
                  controller?.pause();
                }
              }
            },
            itemBuilder: (context, index) {
              final media = widget.mediaItems[index];
              if (media.type == 'video') {
                if (!_videoInitialized[index]) {
                  return _buildVideoPlaceholder();
                }
                return _chewieControllers[index] != null
                    ? Chewie(controller: _chewieControllers[index]!)
                    : _buildErrorPlaceholder();
              } else {
                return Image.network(
                  media.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, size: 50),
                    );
                  },
                );
              }
            },
          ),
        ),
        if (widget.mediaItems.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.mediaItems.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
