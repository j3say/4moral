import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

class GalleryView extends StatefulWidget {
  final RequestType type;
  final Function(String, String?, int)
  onMediaSelected; // Callback for single media selection
  final AssetPathEntity? album;
  final bool isMultipleSelection; // Enable multiple selection mode
  final Function(List<Map<String, String?>>)?
  onSelectionComplete; // Callback for selected media

  const GalleryView({
    super.key,
    required this.type,
    required this.onMediaSelected,
    this.album,
    this.isMultipleSelection = false,
    this.onSelectionComplete,
  });

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  final List<AssetEntity> _mediaList = [];
  final List<AssetEntity> _selectedMedia = []; // List to track selected media
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchMedia();
  }

  Future<void> _fetchMedia() async {
    setState(() {
      _mediaList.clear();
      currentPage = 0;
    });
    final albums =
        widget.album != null
            ? [widget.album!]
            : await PhotoManager.getAssetPathList(type: widget.type);
    if (albums.isNotEmpty) {
      final media = await albums[0].getAssetListPaged(
        page: currentPage,
        size: 60,
      );
      setState(() {
        _mediaList.addAll(media);
        currentPage++;
      });
    }
  }

  Future<void> _handleMediaSelection(AssetEntity asset, int index) async {
    final file = await asset.file;
    String? thumbnailPath;
    if (file != null && asset.type == AssetType.video) {
      final tempDir = await getTemporaryDirectory();
      thumbnailPath = path.join(
        tempDir.path,
        'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await video_thumbnail.VideoThumbnail.thumbnailFile(
        video: file.path,
        thumbnailPath: thumbnailPath,
        imageFormat: video_thumbnail.ImageFormat.JPEG,
        maxWidth: 320,
        quality: 75,
      );
    }
    if (file != null) {
      if (widget.isMultipleSelection) {
        setState(() {
          if (_selectedMedia.contains(asset)) {
            _selectedMedia.remove(asset);
          } else {
            _selectedMedia.add(asset);
          }
        });
      } else {
        widget.onMediaSelected(file.path, thumbnailPath, index);
        widget.onSelectionComplete?.call([
          {'filePath': file.path, 'thumbnailPath': thumbnailPath},
        ]);
      }
    }
  }

  void _handleSelectionComplete() {
    final selectedItems =
        _selectedMedia.map((asset) async {
          final file = await asset.file;
          String? thumbnailPath;
          if (file != null && asset.type == AssetType.video) {
            final tempDir = await getTemporaryDirectory();
            thumbnailPath = path.join(
              tempDir.path,
              'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await video_thumbnail.VideoThumbnail.thumbnailFile(
              video: file.path,
              thumbnailPath: thumbnailPath,
              imageFormat: video_thumbnail.ImageFormat.JPEG,
              maxWidth: 320,
              quality: 75,
            );
          }
          return {'filePath': file!.path, 'thumbnailPath': thumbnailPath};
        }).toList();

    Future.wait(selectedItems).then((items) {
      widget.onSelectionComplete?.call(items);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _mediaList.length,
            itemBuilder: (context, index) {
              final asset = _mediaList[index];
              return GestureDetector(
                onTap: () => _handleMediaSelection(asset, index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder(
                      future: asset.thumbnailDataWithSize(
                        const ThumbnailSize(200, 200),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                    if (asset.type == AssetType.video)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          color: Colors.black54,
                          child: Text(
                            Duration(
                              seconds: asset.duration,
                            ).toString().split('.').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    if (widget.isMultipleSelection &&
                        _selectedMedia.contains(asset))
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.isMultipleSelection)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed:
                  _selectedMedia.isNotEmpty ? _handleSelectionComplete : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text('Done (${_selectedMedia.length} selected)'),
            ),
          ),
      ],
    );
  }
}
