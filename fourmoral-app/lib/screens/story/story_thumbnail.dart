import 'package:flutter/material.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:video_player/video_player.dart';

class StoryThumbnail extends StatefulWidget {
  final Story2Model story;
  final double width;
  final double height;

  const StoryThumbnail({
    super.key,
    required this.story,
    this.width = 100.0,
    this.height = 160.0,
  });

  @override
  _StoryThumbnailState createState() => _StoryThumbnailState();
}

class _StoryThumbnailState extends State<StoryThumbnail> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.story.type == StoryType.video) {
      _initializeVideoController();
    }
  }

  void _initializeVideoController() async {
    _videoController = VideoPlayerController.network(widget.story.mediaUrl);
    await _videoController!.initialize();
    await _videoController!.setLooping(true);
    await _videoController!.setVolume(0.0);
    await _videoController!.pause();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.story.type == StoryType.image
                ? Image.network(
                  widget.story.mediaUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.error, color: Colors.red),
                    );
                  },
                )
                : _videoController != null &&
                    _videoController!.value.isInitialized
                ? VideoPlayer(_videoController!)
                : const Center(child: CircularProgressIndicator()),
            if (widget.story.type == StoryType.video)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24.0,
                  ),
                ),
              ),
            Positioned(
              bottom: 8.0,
              right: 8.0,
              child: Text(
                _getTimeAgo(widget.story.createdAt),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4.0,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
