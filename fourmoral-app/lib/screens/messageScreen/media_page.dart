import 'package:flutter/material.dart';
import 'package:fourmoral/screens/videoScreen/video_screen.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:external_path/external_path.dart';
import 'package:jiffy/jiffy.dart';
import 'package:dio/dio.dart' as di;
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';

class MediaPage extends StatefulWidget {
  final String profileuserphone;

  const MediaPage({super.key, required this.profileuserphone});

  @override
  _MediaPageState createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage>
    with SingleTickerProviderStateMixin {
  final MessageCnt messageCnt = Get.find<MessageCnt>();
  late TabController _tabController;
  final AudioPlayer audioPlayer = AudioPlayer();
  RxBool isPlaying = false.obs;
  RxString currentlyPlaying = ''.obs;
  double downloadProgress = 0.0;
  RxBool isDownloading = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  String getFileName(String url) {
    RegExp regExp = RegExp(r'.+(\/|%2F)(.+)\?.+');
    var matches = regExp.allMatches(url);
    var match = matches.elementAt(0);
    return Uri.decodeFull(match.group(2)!);
  }

  Future downloadFile({String? imageSrc, String? imageName}) async {
    di.Dio dio = di.Dio();
    String path = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOAD,
    );
    var imageDownloadPath = '$path/$imageName';
    await dio.download(
      imageSrc ?? "",
      imageDownloadPath,
      onReceiveProgress: (received, total) {
        setState(() {
          downloadProgress = received.toDouble() / total.toDouble();
        });
      },
    );
    return imageDownloadPath;
  }

  List<Map<String, dynamic>> get mediaItems {
    return messageCnt.messageslist
        .where((msg) {
          return msg['type'] == 'image' ||
              msg['type'] == 'video' ||
              msg['type'] == 'audio' ||
              msg['type'] == 'document';
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get images {
    return mediaItems.where((msg) => msg['type'] == 'image').toList();
  }

  List<Map<String, dynamic>> get videos {
    return mediaItems.where((msg) => msg['type'] == 'video').toList();
  }

  List<Map<String, dynamic>> get audio {
    return mediaItems.where((msg) => msg['type'] == 'audio').toList();
  }

  List<Map<String, dynamic>> get documents {
    return mediaItems.where((msg) => msg['type'] == 'document').toList();
  }

  void toggleAudioPlayback(String url) async {
    if (currentlyPlaying.value == url && isPlaying.value) {
      await audioPlayer.pause();
    } else {
      currentlyPlaying.value = url;
      await audioPlayer.play(UrlSource(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media, Links, and Docs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.image)),
            Tab(icon: Icon(Icons.video_library)),
            Tab(icon: Icon(Icons.audiotrack)),
            Tab(icon: Icon(Icons.insert_drive_file)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMediaGrid(images),
          _buildMediaGrid(videos, isVideo: true),
          _buildAudioList(),
          _buildDocumentsList(),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(
    List<Map<String, dynamic>> items, {
    bool isVideo = false,
  }) {
    if (items.isEmpty) {
      return const Center(child: Text('No media found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            if (isVideo) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => VideoPlayerScreen(
                        videoLink: item['videoUrl'] ?? item['message'],
                      ),
                ),
              );
            } else {
              _showImagePreview(context, item['message']);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              isVideo
                  ? Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item['message'],
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) => const Icon(Icons.error),
                      ),
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 40,
                      ),
                    ],
                  )
                  : CachedNetworkImage(
                    imageUrl: item['message'],
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (context, url, error) => const Icon(Icons.error),
                  ),
              if (item['type'] == 'video')
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    color: Colors.black54,
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioList() {
    if (audio.isEmpty) {
      return const Center(child: Text('No audio messages found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: audio.length,
      itemBuilder: (context, index) {
        final item = audio[index];
        return ListTile(
          leading: Obx(
            () => IconButton(
              icon: Icon(
                currentlyPlaying.value == item['message'] && isPlaying.value
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 36,
              ),
              onPressed: () => toggleAudioPlayback(item['message']),
            ),
          ),
          title: Text('Audio message ${index + 1}'),
          subtitle: Text(
            Jiffy.parse(item['time']).format(pattern: 'MMM dd, yyyy hh:mm a'),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              setState(() {
                isDownloading.value = true;
              });
              try {
                await downloadFile(
                  imageSrc: item['message'],
                  imageName: 'audio_message_${index + 1}.m4a',
                );
                flutterShowToast('Audio downloaded to Downloads folder');
              } catch (e) {
                flutterShowToast('Failed to download audio');
              } finally {
                setState(() {
                  isDownloading.value = false;
                });
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDocumentsList() {
    if (documents.isEmpty) {
      return const Center(child: Text('No documents found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final item = documents[index];
        return ListTile(
          leading: const Icon(Icons.insert_drive_file, size: 36),
          title: Text(getFileName(item['message'])),
          subtitle: Text(
            Jiffy.parse(item['time']).format(pattern: 'MMM dd, yyyy hh:mm a'),
          ),
          trailing:
              item['documentDownload']
                  ? const Icon(Icons.download_done)
                  : IconButton(
                    icon:
                        isDownloading.value
                            ? CircularProgressIndicator(value: downloadProgress)
                            : const Icon(Icons.download),
                    onPressed: () async {
                      setState(() {
                        isDownloading.value = true;
                      });
                      try {
                        await downloadFile(
                          imageSrc: item['message'],
                          imageName: getFileName(item['message']),
                        );
                        flutterShowToast(
                          'Document downloaded to Downloads folder',
                        );

                        // Update the document status in Firebase
                        messageCnt.ref
                            ?.child(item['mainKey'])
                            .child('Data')
                            .child(item['key'])
                            .update({'documentCheck': true});
                      } catch (e) {
                        flutterShowToast('Failed to download document');
                      } finally {
                        setState(() {
                          isDownloading.value = false;
                        });
                      }
                    },
                  ),
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () async {
                    setState(() {
                      isDownloading.value = true;
                    });
                    try {
                      await downloadFile(
                        imageSrc: imageUrl,
                        imageName:
                            'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
                      );
                      flutterShowToast('Image downloaded to Downloads folder');
                    } catch (e) {
                      flutterShowToast('Failed to download image');
                    } finally {
                      setState(() {
                        isDownloading.value = false;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
