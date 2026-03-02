import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/group_user.dart';
import 'package:fourmoral/models/media_item.dart';
import 'package:fourmoral/models/message.dart';
import 'package:intl/intl.dart';

class GroupMediaPage extends StatefulWidget {
  final String groupId;
  final Map<String, GroupUser> usersMap;

  const GroupMediaPage({
    super.key,
    required this.groupId,
    required this.usersMap,
  });

  @override
  _GroupMediaPageState createState() => _GroupMediaPageState();
}

class _GroupMediaPageState extends State<GroupMediaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Media collections
  List<MediaItem> _images = [];
  List<MediaItem> _videos = [];
  List<MediaItem> _audio = [];
  List<MediaItem> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    try {
      final messages =
          await _firestore
              .collection('groups')
              .doc(widget.groupId)
              .collection('messages')
              .where('type', whereIn: ['image', 'video', 'audio', 'file'])
              .orderBy('sentAt', descending: true)
              .get();

      final allMedia =
          messages.docs.map((doc) {
            final message = Message.fromMap(doc.data());
            return MediaItem.fromMessage(message);
          }).toList();

      setState(() {
        _images = allMedia.where((m) => m.type == MessageType.image).toList();
        _videos = allMedia.where((m) => m.type == MessageType.video).toList();
        _audio = allMedia.where((m) => m.type == MessageType.audio).toList();
        _files = allMedia.where((m) => m.type == MessageType.file).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load media: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Media'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Images (${_images.length})'),
            Tab(text: 'Videos (${_videos.length})'),
            Tab(text: 'Audio (${_audio.length})'),
            Tab(text: 'Files (${_files.length})'),
          ],
          isScrollable: true,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildMediaGrid(_images),
                  _buildMediaGrid(_videos),
                  _buildMediaList(_audio),
                  _buildMediaList(_files),
                ],
              ),
    );
  }

  Widget _buildMediaGrid(List<MediaItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('No media found', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _handleMediaTap(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMediaThumbnail(item),
              if (item.type == MessageType.video)
                Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 40,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaList(List<MediaItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('No media found', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final sender = widget.usersMap[item.senderId];

        return ListTile(
          leading: _buildMediaIcon(item),
          title: Text(item.fileName),
          subtitle: Text(
            '${sender?.name ?? 'Unknown'} • ${DateFormat('MMM d, yyyy').format(item.sentAt)}',
          ),
          onTap: () => _handleMediaTap(item),
        );
      },
    );
  }

  Widget _buildMediaThumbnail(MediaItem item) {
    switch (item.type) {
      case MessageType.image:
        return Image.network(
          item.url,
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
          errorBuilder:
              (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: Icon(Icons.broken_image, color: Colors.grey[400]),
              ),
        );
      case MessageType.video:
        return Container(
          color: Colors.black,
          child: Icon(Icons.videocam, color: Colors.white),
        );
      case MessageType.audio:
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.audiotrack, color: Colors.grey[600]),
        );
      case MessageType.file:
        return Container(
          color: Colors.grey[200],
          child: Icon(Icons.insert_drive_file, color: Colors.grey[600]),
        );
      default:
        return Container();
    }
  }

  Widget _buildMediaIcon(MediaItem item) {
    switch (item.type) {
      case MessageType.image:
        return Icon(Icons.image, color: Colors.blue);
      case MessageType.video:
        return Icon(Icons.videocam, color: Colors.red);
      case MessageType.audio:
        return Icon(Icons.audiotrack, color: Colors.green);
      case MessageType.file:
        return Icon(Icons.insert_drive_file, color: Colors.orange);
      default:
        return Icon(Icons.insert_drive_file);
    }
  }

  void _handleMediaTap(MediaItem item) {
    switch (item.type) {
      case MessageType.image:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenImagePage(imageUrl: item.url),
          ),
        );
        break;
      case MessageType.video:
        // Implement video player
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing video: ${item.fileName}')),
        );
        break;
      case MessageType.audio:
        // Implement audio player
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playing audio: ${item.fileName}')),
        );
        break;
      case MessageType.file:
        // Implement file opener
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening file: ${item.fileName}')),
        );
        break;
      default:
        break;
    }
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
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
            ),
          ),
        ),
      ),
    );
  }
}
