import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/messageScreen/services/message_service.dart';
import 'package:fourmoral/screens/videoScreen/video_screen.dart';
import 'package:fourmoral/utils/message_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> messageData;
  final bool isSender;
  final String userPrivateKey; // for decrypting file AES keys & text
  final String receiverPublicKey; // for decrypting text messages
  final void Function()? onSwipeReply;

  const MessageBubble({
    super.key,
    required this.messageData,
    required this.isSender,
    required this.userPrivateKey,
    required this.receiverPublicKey,
    this.onSwipeReply,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _canDeleteForEveryone() {
    final timeString = widget.messageData['time'] ?? '';
    final messageTime = DateTime.tryParse(timeString);
    if (messageTime == null) return false;
    final now = DateTime.now();
    return now.difference(messageTime).inMinutes <= 30;
  }

  String? decryptedText;
  Uint8List? decryptedFileBytes;
  bool isLoadingFile = false;
  VideoPlayerController? _thumbController;
  Future<VideoPlayerController>? _thumbControllerFuture;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _decryptMessageOrFile();
  }

  @override
  void dispose() {
    _thumbController?.dispose();
    _thumbController = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageData['fileUrl'] != widget.messageData['fileUrl']) {
      _decryptMessageOrFile();
    }
    if (oldWidget.messageData['fileUrl'] != widget.messageData['fileUrl'] &&
        widget.messageData['type'] == 'video') {
      _thumbControllerFuture = _initThumbController();
    }
  }

  void _showDeleteOptions() {
    log("widget.messageData['id'] ${widget.messageData}");
    final messageId = widget.messageData['id'] as String?;
    final senderPhone = widget.messageData['sender'] as String?;
    final receiverPhone = widget.messageData['receiver'] as String?;

    if (messageId == null || senderPhone == null || receiverPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message metadata incomplete')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () async {
                  Navigator.pop(context);
                  await MessageService.deleteMessageForMe(
                    userPhone: widget.isSender ? senderPhone : receiverPhone,
                    otherPhone: widget.isSender ? receiverPhone : senderPhone,
                    messageKey: messageId,
                  );
                },
              ),
              if (widget.isSender && _canDeleteForEveryone())
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Delete for everyone'),
                  onTap: () async {
                    Navigator.pop(context);
                    await MessageService.deleteMessageForEveryone(
                      userPhone: senderPhone,
                      otherPhone: receiverPhone,
                      messageKey: messageId,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _decryptMessageOrFile() async {
    final type = widget.messageData['type'] ?? 'text';
    if (type == 'text') {
      final encryptedText = widget.messageData['message'] ?? '';
      final decrypted = await MessageUtils.decryptMessage(
        encryptedText,
        widget.userPrivateKey,
      );
      if (mounted) {
        setState(() {
          decryptedText = decrypted;
        });
      }
    } else {
      if (mounted) {
        setState(() => isLoadingFile = true);
      }
      try {
        final encryptedAesKey = widget.messageData['encryptedAesKey'] ?? '';
        final iv = widget.messageData['iv'] ?? '';
        final fileUrl = widget.messageData['fileUrl'] ?? '';

        final fileBytes = await MessageService.decryptFileMessage(
          encryptedAesKey: encryptedAesKey,
          ivBase64: iv,
          privateKey: widget.userPrivateKey,
          fileUrl: fileUrl,
        );

        if (type == 'video') {
          // After decryption:
          if (mounted) {
            setState(() {
              decryptedFileBytes = fileBytes;
              isLoadingFile = false;
              _thumbControllerFuture = _initThumbController();
            });
          }
        } else {
          if (mounted) {
            setState(() {
              decryptedFileBytes = fileBytes;
              isLoadingFile = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoadingFile = false);
        }
        print("File decrypt error: $e");
      }
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isSender) {
      if (mounted) {
        setState(() {
          _dragOffset += details.delta.dx;
          if (_dragOffset < 0) _dragOffset = 0; // Only allow right swipe
        });
      }
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset > 80) {
      widget.onSwipeReply?.call();
    }
    if (mounted) {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  Widget _buildFileWidget(bool isSender) {
    if (widget.messageData['type'] == 'deleted') {
      return Text(
        "This message was deleted",
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: isSender ? Colors.white : Colors.grey,
        ),
      );
    }
    final fileType = widget.messageData['type'];

    if (isLoadingFile) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.black),
      );
    }

    if (decryptedFileBytes == null) {
      return const Text("Failed to load file");
    }

    switch (fileType) {
      case 'photo':
        return Image.memory(
          decryptedFileBytes!,
          fit: BoxFit.cover,
          width: 200,
          height: 200,
        );
      case 'video':
        return _buildVideoBubble();
      case 'audio':
        return _AudioPlayerWidget(
          audioBytes: decryptedFileBytes!,
          isSender: widget.isSender,
        );
      case 'document':
        return _buildDocumentWidget();
      default:
        return const Text("Unsupported file type");
    }
  }

  /// Small WhatsApp‑style bubble that shows a paused video thumbnail
  Widget _buildVideoBubble() {
    if (decryptedFileBytes == null || _thumbControllerFuture == null) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.black),
      );
    }
    return FutureBuilder<VideoPlayerController>(
      future: _thumbControllerFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.value.isInitialized) {
          return const SizedBox(
            width: 200,
            height: 120,
            child: Center(
              child: CupertinoActivityIndicator(color: Colors.black),
            ),
          );
        }
        final controller = snapshot.data!;
        return GestureDetector(
          onTap: _openFullScreenVideo,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<VideoPlayerController> _initThumbController() async {
    if (decryptedFileBytes == null) {
      throw Exception("Video bytes are not loaded yet.");
    }
    if (_thumbController != null) {
      await _thumbController!.dispose();
      _thumbController = null;
    }
    final tempDir = await Directory.systemTemp.createTemp();
    final tempFile = File('${tempDir.path}/thumb_video.mp4');
    await tempFile.writeAsBytes(decryptedFileBytes!, flush: true);
    final controller = VideoPlayerController.file(tempFile);
    await controller.initialize();
    if (mounted) {
      _thumbController = controller;
    }
    return controller;
  }

  void _openFullScreenVideo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                VideoPlayerScreen(decryptedFileBytes: decryptedFileBytes),
      ),
    );
  }

  Widget _buildDocumentWidget() {
    return GestureDetector(
      onTap: () async {
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File('${tempDir.path}/file.pdf');
        await tempFile.writeAsBytes(decryptedFileBytes!);
        // ignore: use_build_context_synchronously
        await OpenFile.open(tempFile.path);
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.insert_drive_file,
              color: Colors.black54,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.messageData['fileName'] ?? 'Document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.download_rounded, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.messageData['isReply'] == true;
    final replyTo = widget.messageData['replyTo'];

    final currentUser =
        widget.isSender
            ? widget.messageData['sender']
            : widget.messageData['receiver'];

    final deletedForMap =
        widget.messageData['deletedFor'] as Map<dynamic, dynamic>?;

    final isDeletedForMe =
        deletedForMap != null && deletedForMap[currentUser] == true;

    if (isDeletedForMe) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onLongPress: _showDeleteOptions,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _dragOffset),
        duration: const Duration(milliseconds: 200),
        builder: (context, value, child) {
          return Transform.translate(offset: Offset(value, 0), child: child);
        },
        child: Align(
          alignment:
              widget.isSender ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  widget.isSender
                      ? Theme.of(context).primaryColor.withOpacity(0.9)
                      : white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft:
                    widget.isSender
                        ? const Radius.circular(16)
                        : const Radius.circular(0),
                bottomRight:
                    widget.isSender
                        ? const Radius.circular(0)
                        : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.50,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReply && replyTo != null)
                  Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColorLight.withOpacity(0.1),
                      border: Border(
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                    child: Text(
                      replyTo['message'] ?? '',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: widget.isSender ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (widget.messageData['type'] == 'text')
                  Text(
                    decryptedText ?? "Decrypting...",
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isSender ? Colors.white : Colors.black87,
                    ),
                  )
                else
                  _buildFileWidget(widget.isSender),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.messageData['time']?.toString().substring(
                                  11,
                                  16,
                                ) ??
                                '',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  widget.isSender ? Colors.white : Colors.black,
                              // fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final Uint8List audioBytes;
  final bool isSender;

  const _AudioPlayerWidget({required this.audioBytes, required this.isSender});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      final source = AudioSource.uri(
        Uri.dataFromBytes(widget.audioBytes, mimeType: 'audio/mpeg'),
      );
      await _player.setAudioSource(source);
      _duration = _player.duration ?? Duration.zero;
      _isLoading = false;

      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });

      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }
        });
      });
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(
          child: CupertinoActivityIndicator(
            color: widget.isSender ? Colors.white : Colors.black,
          ),
        )
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _isPlaying ? _player.pause() : _player.play(),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: widget.isSender ? Colors.white : Colors.black87,
                    size: 25,
                  ),
                ),

                const SizedBox(width: 4),
                Expanded(
                  child: Slider(
                    min: 0,
                    thumbColor:
                        widget.isSender
                            ? Colors.white
                            : Theme.of(context).primaryColor.withOpacity(0.9),
                    inactiveColor: Colors.grey,
                    activeColor:
                        widget.isSender
                            ? Colors.white
                            : Theme.of(context).primaryColor.withOpacity(0.9),
                    max: _duration.inMilliseconds.toDouble(),
                    value:
                        _position.inMilliseconds
                            .clamp(0, _duration.inMilliseconds)
                            .toDouble(),
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ],
            ),
            Text(
              "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
              style: TextStyle(
                fontSize: 15,
                color: widget.isSender ? Colors.white : Colors.grey,
              ),
            ),
          ],
        );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
