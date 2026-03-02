import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';
import 'package:fourmoral/screens/messageScreen/services/message_service.dart';
import 'package:fourmoral/screens/messageScreen/widgets/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatInputField extends StatefulWidget {
  final Function(String) onSend;
  final String profileuserphone;

  const ChatInputField({
    super.key,
    required this.onSend,
    required this.profileuserphone,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool showSend = false;
  final messageCnt = Get.put(MessageCnt());
  final AudioRecorder _record = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false;
  bool _showLockHint = false;
  bool _showDeleteHint = false;
  Timer? _timer;
  int _recordDuration = 0;
  String _filePath = '';
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    messageCnt.messageController.addListener(() {
      setState(() {
        showSend = messageCnt.messageController.text.trim().isNotEmpty;
      });
    });
  }

  void _handleSend() {
    final text = messageCnt.messageController.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      messageCnt.messageController.clear();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _record.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _filePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _record.start(
        RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: _filePath,
      );

      _stopwatch.reset();
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        setState(() {
          _recordDuration = _stopwatch.elapsed.inSeconds;
        });
      });

      setState(() {
        _isRecording = true;
        _isLocked = false;
      });
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _timer?.cancel();
    _stopwatch.stop();
    _stopwatch.reset();

    if (_isRecording) {
      await _record.stop();
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _recordDuration = 0;
      });

      final file = File(_filePath);
      if (await file.exists()) {
        if (send) {
          await MessageService.sendEncryptedFile(
            file: file,
            fileType: "audio",
            receiverPublicKey: messageCnt.receiverPublicKey ?? "",
            userPhone: messageCnt.userphone!,
            receiverPhone: widget.profileuserphone,
            clearReply: () => messageCnt.clearReply(),
            needsScroll: messageCnt.needsScroll,
            replyData: messageCnt.replyingToMessage,
          );
          print("file Path $file");
        } else {
          await file.delete();
        }
      }
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            if (!_isRecording)
              FilePickerMenu(
                messageCnt: messageCnt,
                profileuserphone: widget.profileuserphone,
              ),
            if (!_isRecording)
              IconButton(
                icon: const Icon(Icons.mic_none_rounded, color: Colors.grey),
                onPressed: () {}, // attach file
              ),
            if (!_isRecording)
              Expanded(
                child: TextField(
                  controller: messageCnt.messageController,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: "Message",
                    border: InputBorder.none,
                  ),
                ),
              ),
            if (_isRecording)
              Text(
                _formatDuration(_recordDuration),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (_isRecording) Spacer(),
            SizedBox(width: 10),

            if (_showDeleteHint)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_back, color: Colors.black, size: 20),
                  SizedBox(width: 4),
                  Text(
                    "Slide to cancel",
                    style: TextStyle(color: Colors.black),
                  ),
                  SizedBox(width: 4),
                ],
              ),
            if (showSend)
              CircleAvatar(
                radius: 20,
                backgroundColor: blue,
                child: IconButton(
                  icon: Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _handleSend,
                ),
              ),
            if (!showSend)
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                // onLongPress: () => _startRecording(),
                onLongPressMoveUpdate: (details) {
                  if (_isRecording) {
                    if (!mounted) return;
                    setState(() {
                      _showDeleteHint = details.localOffsetFromOrigin.dx < -40;
                      _showLockHint = details.localOffsetFromOrigin.dy < -40;
                    });

                    if (details.localOffsetFromOrigin.dx < -150) {
                      _stopRecording(send: false);
                      _showDeleteHint = false;
                    } else if (details.localOffsetFromOrigin.dy < -150) {
                      if (!mounted) return;
                      setState(() {
                        _isLocked = true;
                        _isRecording = true;
                      });
                    }
                  }
                },

                onLongPressEnd: (_) {
                  if (!mounted) return;
                  setState(() {
                    _showDeleteHint = false;
                    _showLockHint = false;
                  });

                  if (!_isLocked && _isRecording) {
                    _stopRecording();
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _isRecording ? Colors.red : blue,
                      child: Icon(Icons.mic, color: Colors.white, size: 20),
                    ),
                    if (_showLockHint)
                      const Positioned(
                        top: -50,
                        right: 10,
                        child: Icon(Icons.lock, color: Colors.black, size: 24),
                      ),
                  ],
                ),
              ),
            if (_isLocked)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green[600],
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _stopRecording(),
                  ),
                ),
              ),
            // WhatsAppAudioRecorder(
            //   onSendAudio: (file) {
            //     // Upload the file and send the message
            //     print("Audio file path: ${file.path}");
            //     // Implement your upload + send logic here
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}

Widget buildOptionButton({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    ),
  );
}
