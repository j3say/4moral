import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show pow;
import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:fourmoral/models/group_user.dart';
import 'package:fourmoral/screens/group/group_media_page.dart';
import 'package:fourmoral/screens/group/service/encryption_service.dart';
import 'package:fourmoral/screens/group/service/file_cache_manager.dart';
import 'package:fourmoral/screens/videoScreen/video_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fourmoral/models/group.dart';
import 'package:fourmoral/models/message.dart';
import 'package:fourmoral/screens/group/group_info_screen.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;
  final String userMobile;

  const GroupChatScreen({
    super.key,
    required this.group,
    required this.userMobile,
  });

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // search
  bool _isSearching = false;
  List<DocumentSnapshot> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  // Add speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  late CollectionReference _messagesRef;
  late Stream<QuerySnapshot> _messagesStream;
  Map<String, GroupUser> _usersMap = {};
  bool _isLoading = true;
  DateTime? _lastMessageDate;
  bool ismessageSend = false;
  String? _encryptionKey;

  Message? _replyingToMessage;
  final GlobalKey _replyBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _messagesRef = _firestore
        .collection('groups')
        .doc(widget.group.id)
        .collection('messages');

    _messagesStream =
        _messagesRef.orderBy('sentAt', descending: false).snapshots();

    _loadUsers();
    _initSpeech();
    _loadEncryptionKey();
  }

  void _startReplyingToMessage(Message message) {
    setState(() {
      _replyingToMessage = message;
    });

    // Scroll to reply bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _replyBarKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    FocusScope.of(context).requestFocus(FocusNode());
  }

  Future<void> _loadEncryptionKey() async {
    try {
      final groupDoc =
          await _firestore.collection('groups').doc(widget.group.id).get();
      if (groupDoc.exists && groupDoc.data()?['encryptionKey'] != null) {
        setState(() {
          _encryptionKey = groupDoc.data()!['encryptionKey'] as String;
        });
      } else {
        // Create new key if doesn't exist
        _encryptionKey = await FreebaseEncryptionService.getOrCreateGroupKey(
          widget.group.id,
        );
      }
    } catch (e) {
      _showSnackBar('Encryption key error: ${e.toString()}');
      debugPrint('Failed to load encryption key: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    try {
      final snapshot =
          await _messagesRef.orderBy('content').startAt([query]).endAt([
            '$query\uf8ff',
          ]).get();

      setState(() {
        _searchResults = snapshot.docs; // Store DocumentSnapshots directly
      });
    } catch (e) {
      _showSnackBar('Error searching messages: ${e.toString()}');
    }
  }

  // Initialize speech recognition
  void _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (errorNotification) {
        setState(() => _isListening = false);
        _showSnackBar(
          'Speech recognition error: ${errorNotification.errorMsg}',
        );
      },
    );
  }

  // Start/stop listening for voice input
  void _listen() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showSnackBar('Microphone permission denied');
      return;
    }

    if (!_isListening) {
      setState(() => _isListening = true);

      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Add space if the controller already has text
            if (_messageController.text.isNotEmpty &&
                !_messageController.text.endsWith(' ')) {
              _messageController.text += ' ';
            }
            _messageController.text += result.recognizedWords;
            // Move cursor to the end
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
        partialResults: false,
      );
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<Uint8List> _getDecryptedMedia(String mediaUrl) async {
    try {
      // Generate a unique cache key based on mediaUrl
      final cacheKey = mediaUrl.hashCode.toString();

      // Check if we have a cached version
      final cachedBytes = await FileCacheManager.getFromCache(cacheKey);
      if (cachedBytes != null) {
        return cachedBytes;
      }

      if (_encryptionKey == null) {
        await _loadEncryptionKey();
        if (_encryptionKey == null) {
          throw Exception('No encryption key available');
        }
      }

      // Download the encrypted file
      final httpsReference = FirebaseStorage.instance.refFromURL(mediaUrl);
      final encryptedBytes = await httpsReference.getData();

      if (encryptedBytes == null) {
        throw Exception('Failed to download media');
      }

      // Decrypt the file
      final decryptedBytes = await FreebaseEncryptionService.decryptFile(
        encryptedBytes,
        _encryptionKey!,
      );

      // Save to cache for future use
      await FileCacheManager.saveToCache(cacheKey, decryptedBytes);

      return decryptedBytes;
    } catch (e) {
      debugPrint('Media decryption error: $e');
      throw Exception('Could not decrypt media');
    }
  }

  Widget _buildMediaMessage(Message message, bool isMe) {
    final cacheKey = '${message.id}_${message.sentAt.millisecondsSinceEpoch}';

    return FutureBuilder<Uint8List>(
      future: _getDecryptedMedia(message.mediaUrl ?? ""),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: Center(child: Text('Error loading media')),
          );
        }

        final decryptedBytes = snapshot.data!;

        switch (message.type) {
          case MessageType.image:
            return GestureDetector(
              onTap: () => _showFullScreenImage(message.mediaUrl ?? ""),
              child: Image.memory(
                decryptedBytes,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            );

          case MessageType.video:
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => VideoPlayerScreen(
                          decryptedFileBytes: decryptedBytes,
                        ),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoThumbnail(decryptedBytes, cacheKey: cacheKey),
                  Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                ],
              ),
            );

          case MessageType.audio:
            return AudioPlayerWidget(
              audioBytes: decryptedBytes,
              fileName: message.fileInfo,
              cacheKey: cacheKey,
            );

          case MessageType.file:
            return FileDisplayWidget(
              bytes: decryptedBytes,
              fileName: message.fileInfo ?? 'File',
              encrypted: _encryptionKey!,
              message: message,
              cacheKey: cacheKey,
            );

          default:
            return Container();
        }
      },
    );
  }

  Future<void> _loadUsers() async {
    try {
      final usersSnapshot =
          await _firestore
              .collection('users')
              .where(
                FieldPath.documentId,
                whereIn: widget.group.members.map((m) => m.userId).toList(),
              )
              .get();

      _usersMap = {
        for (var doc in usersSnapshot.docs)
          doc.id: GroupUser.fromMap(doc.data()),
      };

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading users: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Send Media',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 16),

                // Media options grid
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  childAspectRatio: 0.9,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildMediaOption(
                      icon: Icons.photo_library,
                      color: Colors.blue,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage();
                      },
                    ),
                    _buildMediaOption(
                      icon: Icons.camera_alt,
                      color: Colors.purple,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(fromCamera: true);
                      },
                    ),
                    _buildMediaOption(
                      icon: Icons.videocam,
                      color: Colors.red,
                      label: 'Video',
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo();
                      },
                    ),
                    _buildMediaOption(
                      icon: Icons.video_call,
                      color: Colors.orange,
                      label: 'Camera Video',
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo(fromCamera: true);
                      },
                    ),
                    _buildMediaOption(
                      icon: Icons.audiotrack,
                      color: Colors.green,
                      label: 'Audio',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAudio();
                      },
                    ),
                    _buildMediaOption(
                      icon: Icons.insert_drive_file,
                      color: Colors.brown,
                      label: 'Document',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFile();
                      },
                    ),
                    // _buildMediaOption(
                    //   icon: Icons.location_on,
                    //   color: Colors.teal,
                    //   label: 'Location',
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     // Implement location sharing
                    //   },
                    // ),
                    // _buildMediaOption(
                    //   icon: Icons.contact_page,
                    //   color: Colors.indigo,
                    //   label: 'Contact',
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     // Implement contact sharing
                    //   },
                    // ),
                  ],
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Future<void> _deleteMessageForMe(String messageId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(widget.group.id)
          .collection('messages')
          .doc(messageId)
          .update({'isDeleted': true});
    } catch (e) {
      _showSnackBar('Failed to delete message: ${e.toString()}');
    }
  }

  Future<void> _deleteMessageForEveryone(String messageId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Check if user is admin
      final isAdmin = widget.group.adminUid.contains(currentUser.uid);
      if (!isAdmin) {
        _showSnackBar('Only admins can delete messages for everyone');
        return;
      }

      await _firestore
          .collection('groups')
          .doc(widget.group.id)
          .collection('messages')
          .doc(messageId)
          .update({
            'deletedForEveryone': true,
            'content': 'This message was deleted',
            'mediaUrl': null,
            'fileInfo': null,
          });

      // Also delete from storage if it's a media message
      final messageDoc =
          await _firestore
              .collection('groups')
              .doc(widget.group.id)
              .collection('messages')
              .doc(messageId)
              .get();

      if (messageDoc.exists) {
        final message = Message.fromMap(messageDoc.data()!);
        if (message.mediaUrl != null) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(message.mediaUrl!);
            await ref.delete();
          } catch (e) {
            debugPrint('Failed to delete media file: $e');
          }
        }
      }
    } catch (e) {
      _showSnackBar('Failed to delete message: ${e.toString()}');
    }
  }

  Future<void> _sendMessage({
    required String content,
    required MessageType type,
    String? filePath,
    String? fileName,
    Message? replyTo,
  }) async {
    setState(() {
      ismessageSend = true;
    });
    if (content.trim().isEmpty && type == MessageType.text) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      String? mediaUrl;
      String? fileInfo = fileName;
      String finalContent = content;
      Uint8List? fileBytes;

      // Handle file messages
      if (type != MessageType.text && filePath != null) {
        final file = File(filePath);
        fileBytes = await file.readAsBytes();
        fileInfo = fileName ?? file.path.split('/').last;
      }

      // Ensure we have encryption key
      if (_encryptionKey == null) {
        await _loadEncryptionKey();
        if (_encryptionKey == null) {
          _showSnackBar('Encryption failed - no key available');
          return;
        }
      }

      // Process content based on message type
      switch (type) {
        case MessageType.text:
          // Encrypt text content
          finalContent = await FreebaseEncryptionService.processMessageContent(
            type: MessageType.text,
            content: content,
            keyBase64: _encryptionKey!,
            encrypt: true,
          );
          break;

        case MessageType.image:
        case MessageType.video:
        case MessageType.audio:
        case MessageType.file:
          if (fileBytes == null) {
            _showSnackBar('No file selected');
            return;
          }

          // Encrypt file content
          final encryptedBytes = await FreebaseEncryptionService.encryptFile(
            fileBytes,
            _encryptionKey!,
          );

          // Upload to Firebase Storage
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final extension = fileInfo!.split('.').last;
          final ref = FirebaseStorage.instance.ref().child(
            'group_media/${widget.group.id}/$timestamp.$extension',
          );

          final uploadTask = ref.putData(encryptedBytes);
          final snapshot = await uploadTask.whenComplete(() {});
          mediaUrl = await snapshot.ref.getDownloadURL();

          // For media messages, we'll use a placeholder content
          finalContent = type.toString().split('.').last;
          break;
      }

      // Create and send message
      final message = Message(
        id: _messagesRef.doc().id,
        senderId: currentUser.uid,
        content: finalContent,
        type: type,
        sentAt: DateTime.now(),
        mediaUrl: mediaUrl,
        fileInfo: fileInfo,
        repliedTo: replyTo,
      );

      await _messagesRef.doc(message.id).set(message.toMap());

      // Update group's last message
      await _firestore.collection('groups').doc(widget.group.id).update({
        'lastMessage': {
          'content': _getLastMessagePreview(type, content),
          'sentAt': DateTime.now(),
          'senderId': currentUser.uid,
        },
        'lastActivity': DateTime.now(),
      });

      _scrollToBottom();
      if (mounted) {
        setState(() {
          ismessageSend = false;
          _replyingToMessage = null;
          _messageController.clear();
        });
      }
    } catch (e) {
      setState(() {
        ismessageSend = false;
      });
      _showSnackBar('Failed to send message: ${e.toString()}');
      debugPrint('Error sending message: $e');
    }
  }

  String _getLastMessagePreview(MessageType type, String content) {
    switch (type) {
      case MessageType.text:
        return content.length > 30 ? '${content.substring(0, 30)}...' : content;
      case MessageType.image:
        return '📷 Image';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🔊 Audio';
      case MessageType.file:
        return '📄 File';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        await _sendMessage(
          content: 'Image',
          type: MessageType.image,
          filePath: image.path,
          fileName: image.name,
          replyTo: _replyingToMessage,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (video != null) {
        await _sendMessage(
          content: 'Video',
          type: MessageType.video,
          filePath: video.path,
          fileName: video.name,
          replyTo: _replyingToMessage,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to pick video: ${e.toString()}');
    }
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);

      if (result != null && result.files.single.path != null) {
        await _sendMessage(
          content: 'Audio',
          type: MessageType.audio,
          filePath: result.files.single.path!,
          fileName: result.files.single.name,
          replyTo: _replyingToMessage,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to pick audio: ${e.toString()}');
    }
  }

  Future<void> _pickFile() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (status != PermissionStatus.granted) {
        _showSnackBar('Storage permission required to select files');
        return;
      }

      // Show file picker with custom UI
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Select File to Send',
        lockParentWindow: true,
        allowedExtensions: null,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.first;

        // Show confirmation dialog with file preview
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Send File?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilePreview(file),
                    SizedBox(height: 16),
                    Text(
                      '${file.name}\n'
                      '${_formatFileSize(file.size)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    child: Text(
                      'Send',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _sendMessage(
                        content: 'File: ${file.name}',
                        type: MessageType.file,
                        filePath: file.path!,
                        fileName: file.name,
                        replyTo: _replyingToMessage,
                      );
                    },
                  ),
                ],
              ),
        );
      }
    } on PlatformException catch (e) {
      _showSnackBar('File picker error: ${e.message}');
    } catch (e) {
      _showSnackBar('Failed to pick file: ${e.toString()}');
    }
  }

  Widget _buildFilePreview(PlatformFile file) {
    final iconSize = 48.0;
    final iconColor = Theme.of(context).primaryColor;

    if (file.extension == 'pdf') {
      return Icon(Icons.picture_as_pdf, size: iconSize, color: Colors.red);
    } else if (['doc', 'docx'].contains(file.extension)) {
      return Icon(Icons.description, size: iconSize, color: Colors.blue);
    } else if (['xls', 'xlsx'].contains(file.extension)) {
      return Icon(Icons.table_chart, size: iconSize, color: Colors.green);
    } else if (['ppt', 'pptx'].contains(file.extension)) {
      return Icon(Icons.slideshow, size: iconSize, color: Colors.orange);
    } else if (['zip', 'rar', '7z'].contains(file.extension)) {
      return Icon(Icons.archive, size: iconSize, color: Colors.purple);
    } else {
      return Icon(Icons.insert_drive_file, size: iconSize, color: iconColor);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _formatDate(date),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Future<String> _getDecryptedContent(Message message) async {
    if (message.type != MessageType.text) return message.content;

    if (_encryptionKey == null) {
      await _loadEncryptionKey();
      if (_encryptionKey == null) return '[Waiting for decryption key]';
    }

    try {
      return await FreebaseEncryptionService.processMessageContent(
        type: MessageType.text,
        content: message.content,
        keyBase64: _encryptionKey,
        encrypt: false,
      );
    } catch (e) {
      debugPrint('Decryption error: $e');
      return '[Could not decrypt message]';
    }
  }

  void _showMessageOptions(
    BuildContext context,
    Message message,
    bool isMe,
    bool isAdmin,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.reply),
                title: Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _startReplyingToMessage(message);
                },
              ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete for me'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForMe(message.id);
                  },
                ),
              if (isAdmin)
                ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Delete for everyone'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForEveryone(message.id);
                  },
                ),
              // ListTile(
              //   leading: Icon(Icons.copy),
              //   title: Text('Copy text'),
              //   onTap: () {
              //     Navigator.pop(context);
              //     Clipboard.setData(ClipboardData(text: message.content));
              //     _showSnackBar('Copied to clipboard');
              //   },
              // ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPreviewForMediaType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.file:
        return 'File';
      default:
        return 'Media';
    }
  }

  Future<String> _getDecryptedReplyContent(Message message) async {
    if (message.type != MessageType.text) {
      return _getPreviewForMediaType(message.type);
    }

    if (_encryptionKey == null) {
      await _loadEncryptionKey();
      if (_encryptionKey == null) return '[Waiting for decryption key]';
    }

    try {
      return await FreebaseEncryptionService.processMessageContent(
        type: MessageType.text,
        content: message.content,
        keyBase64: _encryptionKey,
        encrypt: false,
      );
    } catch (e) {
      debugPrint('Reply decryption error: $e');
      return '[Could not decrypt reply]';
    }
  }

  Widget _buildMessageReplyPreview(Message repliedTo, bool isCurrentMessageMe) {
    final isOriginalSenderMe = repliedTo.senderId == _auth.currentUser?.uid;

    return FutureBuilder<String>(
      future: _getDecryptedReplyContent(repliedTo),
      builder: (context, snapshot) {
        final displayContent = snapshot.data ?? 'Decrypting...';

        return Container(
          margin: EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isCurrentMessageMe
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: Theme.of(context).primaryColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOriginalSenderMe
                    ? 'You'
                    : _usersMap[repliedTo.senderId]?.name ?? 'User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 2),
              _buildReplyPreviewContent(repliedTo, displayContent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc, {required bool showAvatar}) {
    final message = Message.fromMap(doc.data() as Map<String, dynamic>);
    final isMe = message.senderId == _auth.currentUser?.uid;
    final isAdmin = widget.group.adminUid.contains(
      _auth.currentUser?.uid ?? "",
    );
    final sender = _usersMap[message.senderId];

    // Handle deleted messages
    if (message.deletedForEveryone) {
      return _buildDeletedMessage(isMe, "This message was deleted by admin");
    }

    if (message.isDeleted && !isMe && !isAdmin) {
      return SizedBox.shrink(); // Don't show deleted messages to others
    }

    // Check if we need to show a date separator
    Widget? dateSeparator;
    final messageDate = DateTime(
      message.sentAt.year,
      message.sentAt.month,
      message.sentAt.day,
    );

    if (_lastMessageDate == null || messageDate != _lastMessageDate) {
      dateSeparator = _buildDateSeparator(messageDate);
      _lastMessageDate = messageDate;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dateSeparator != null) dateSeparator,
        GestureDetector(
          onLongPress:
              () => _showMessageOptions(context, message, isMe, isAdmin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message.repliedTo != null)
                _buildMessageReplyPreview(message.repliedTo!, isMe),

              FutureBuilder<String>(
                future:
                    message.isDeleted
                        ? Future.value("This message was deleted")
                        : _getDecryptedContent(message),
                builder: (context, snapshot) {
                  final displayContent = snapshot.data ?? 'Decrypting...';

                  return Padding(
                    padding: EdgeInsets.only(
                      left: isMe ? 64 : 8,
                      right: isMe ? 8 : 64,
                      top: 2,
                      bottom: 2,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        if (!isMe && sender != null && !message.isDeleted)
                          Padding(
                            padding: const EdgeInsets.only(left: 40, bottom: 2),
                            child: Row(
                              children: [
                                Text(
                                  sender.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  DateFormat('h:mm a').format(message.sentAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          mainAxisAlignment:
                              isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe && showAvatar && !message.isDeleted)
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: NetworkImage(
                                  sender?.profilePicture ??
                                      'https://via.placeholder.com/150',
                                ),
                              )
                            else if (!isMe && !showAvatar)
                              SizedBox(width: 32),
                            SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.all(
                                  message.type == MessageType.text ? 12 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      message.isDeleted
                                          ? Colors.grey.withOpacity(0.1)
                                          : isMe
                                          ? Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.9)
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                      message.repliedTo != null ? 4 : 16,
                                    ),
                                    topRight: Radius.circular(
                                      message.repliedTo != null ? 4 : 16,
                                    ),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                ),
                                child:
                                    message.isDeleted
                                        ? Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              displayContent,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        )
                                        : message.type == MessageType.text
                                        ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayContent,
                                              style: TextStyle(
                                                color:
                                                    isMe
                                                        ? Colors.white
                                                        : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              DateFormat(
                                                'h:mm a',
                                              ).format(message.sentAt),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    isMe
                                                        ? Colors.white70
                                                        : Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        )
                                        : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildMediaMessage(message, isMe),
                                            Text(
                                              DateFormat(
                                                'h:mm a',
                                              ).format(message.sentAt),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    isMe
                                                        ? Colors.white70
                                                        : Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeletedMessage(bool isMe, String text) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 64 : 8,
        right: isMe ? 8 : 64,
        top: 2,
        bottom: 2,
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_forever, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog.fullscreen(
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
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
                Positioned(
                  top: 20,
                  left: 16,
                  child: IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          elevation: 1,
          titleSpacing: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title:
              _isSearching
                  ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      border: InputBorder.none,
                      suffixIcon:
                          _searchResults.isNotEmpty
                              ? Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${_searchResults.length}',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                              : null,
                    ),

                    onChanged: (query) {
                      _performSearch(query);
                    },
                  )
                  : GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => GroupInfoScreen(
                                  group: widget.group,
                                  userMobile: widget.userMobile,
                                ),
                          ),
                        ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'group-${widget.group.id}',
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              widget.group.groupPicUrl.isNotEmpty
                                  ? widget.group.groupPicUrl
                                  : 'https://via.placeholder.com/150',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.group.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream:
                                    _firestore
                                        .collection('users')
                                        .where('online', isEqualTo: true)
                                        .where(
                                          FieldPath.documentId,
                                          whereIn:
                                              widget.group.members
                                                  .map((m) => m.userId)
                                                  .toList(),
                                        )
                                        .snapshots(),
                                builder: (context, snapshot) {
                                  final onlineCount =
                                      snapshot.hasData
                                          ? snapshot.data!.docs.length
                                          : 0;
                                  return Text(
                                    onlineCount > 0
                                        ? '$onlineCount online • ${widget.group.members.length} members'
                                        : '${widget.group.members.length} members',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          actions: [
            if (_isSearching)
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchResults.clear();
                  });
                },
              )
            else
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            if (!_isSearching) ...[
              IconButton(
                icon: Icon(
                  Icons.videocam,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed:
                    () => _showSnackBar('Video call feature coming soon'),
              ),
              PopupMenuButton<int>(
                icon: Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 0:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => GroupInfoScreen(
                                group: widget.group,
                                userMobile: widget.userMobile,
                              ),
                        ),
                      );
                      break;
                    case 1:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => GroupMediaPage(
                                groupId: widget.group.id,
                                usersMap: _usersMap,
                              ),
                        ),
                      );
                      break;
                    case 2:
                      // Handle option 3
                      break;
                    case 3:
                      // Handle option 4
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(value: 0, child: Text("View Group Info")),
                      PopupMenuItem(value: 1, child: Text("View Media")),
                      PopupMenuItem(value: 2, child: Text("Clear Chat")),
                      PopupMenuItem(value: 3, child: Text("Exit Group")),
                    ],
              ),
            ],
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            image: DecorationImage(
              image: AssetImage('assets/_.jpeg'),
              fit: BoxFit.cover,
              opacity: 0.1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                        : _isSearching && _searchResults.isNotEmpty
                        ? ListView.builder(
                          padding: EdgeInsets.only(bottom: 16, top: 16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            return _buildMessageItem(
                              _searchResults[index],
                              showAvatar: true,
                            );
                          },
                        )
                        : _isSearching && _searchController.text.isNotEmpty
                        ? Center(
                          child: Text(
                            'No results found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                        : StreamBuilder<QuerySnapshot>(
                          stream: _messagesStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final messages = snapshot.data?.docs ?? [];

                            if (messages.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start the conversation!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Reset the date tracking variable
                            _lastMessageDate = null;

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients &&
                                  messages.isNotEmpty) {
                                _scrollController.jumpTo(
                                  _scrollController.position.maxScrollExtent,
                                );
                              }
                            });

                            return ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.only(bottom: 16, top: 16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                // Your existing message builder code...
                                final currentMsg = Message.fromMap(
                                  messages[index].data()
                                      as Map<String, dynamic>,
                                );

                                bool showAvatar = true;
                                if (index + 1 < messages.length) {
                                  final nextMsg = Message.fromMap(
                                    messages[index + 1].data()
                                        as Map<String, dynamic>,
                                  );

                                  // Don't show avatar if the next message is from the same sender and sent within 5 mins
                                  if (nextMsg.senderId == currentMsg.senderId &&
                                      nextMsg.sentAt
                                              .difference(currentMsg.sentAt)
                                              .inMinutes
                                              .abs() <
                                          5) {
                                    showAvatar = false;
                                  }
                                }

                                return _buildMessageItem(
                                  messages[index],
                                  showAvatar: showAvatar,
                                );
                              },
                            );
                          },
                        ),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    final message = _replyingToMessage!;
    final isMe = message.senderId == _auth.currentUser?.uid;

    return FutureBuilder<String>(
      future: _getDecryptedReplyContent(message),
      builder: (context, snapshot) {
        final displayContent = snapshot.data ?? 'Decrypting...';

        return Container(
          key: _replyBarKey,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to ${isMe ? 'yourself' : _usersMap[message.senderId]?.name ?? 'user'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    _buildReplyPreviewContent(
                      message,
                      displayContent,
                    ), // Pass both arguments
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() => _replyingToMessage = null);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreviewContent(Message message, String displayContent) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          displayContent.length > 50
              ? '${displayContent.substring(0, 50)}...'
              : displayContent,
          style: TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case MessageType.image:
        return Row(
          children: [
            Icon(Icons.image, size: 16),
            SizedBox(width: 4),
            Text('Photo', style: TextStyle(fontSize: 12)),
          ],
        );
      case MessageType.video:
        return Row(
          children: [
            Icon(Icons.videocam, size: 16),
            SizedBox(width: 4),
            Text('Video', style: TextStyle(fontSize: 12)),
          ],
        );
      case MessageType.audio:
        return Row(
          children: [
            Icon(Icons.audiotrack, size: 16),
            SizedBox(width: 4),
            Text('Audio', style: TextStyle(fontSize: 12)),
          ],
        );
      case MessageType.file:
        return Row(
          children: [
            Icon(Icons.insert_drive_file, size: 16),
            SizedBox(width: 4),
            Text(
              message.fileInfo ?? 'File',
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
    }
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        if (_replyingToMessage != null) _buildReplyPreviewBar(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Attachment button
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                onPressed: () => _showAttachmentMenu(context),
              ),
              SizedBox(width: 4),

              // Message input
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          maxLines: 5,
                          minLines: 1,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Voice message button
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Colors.grey[600],
                        ),
                        onPressed: _listen,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),

              // Send button
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor,
                ),
                child:
                    ismessageSend
                        ? CircularProgressIndicator()
                        : IconButton(
                          icon: Icon(Icons.send, color: Colors.white),
                          onPressed: () {
                            if (_messageController.text.trim().isNotEmpty) {
                              _sendMessage(
                                content: _messageController.text.trim(),
                                type: MessageType.text,
                                replyTo: _replyingToMessage,
                              );
                            }
                          },
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VideoThumbnail extends StatefulWidget {
  final Uint8List videoBytes;
  final String cacheKey;

  const VideoThumbnail(this.videoBytes, {super.key, required this.cacheKey});

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  static final _thumbnailCache = <String, File>{};

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Check cache first
    if (_thumbnailCache.containsKey(widget.cacheKey)) {
      final cachedFile = _thumbnailCache[widget.cacheKey]!;
      _controller = VideoPlayerController.file(cachedFile)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller.setLooping(true);
            _controller.pause();
          }
        });
      return;
    }

    // Create temporary file to play from bytes
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${widget.cacheKey}.mp4');
    await file.writeAsBytes(widget.videoBytes);
    _thumbnailCache[widget.cacheKey] = file;

    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.pause();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          Icon(
            Icons.play_circle_fill,
            size: 50,
            color: Colors.white.withOpacity(0.8),
          ),
        ],
      ),
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final Uint8List audioBytes;
  final String? fileName;
  final String cacheKey;

  const AudioPlayerWidget({
    super.key,
    required this.audioBytes,
    this.fileName,
    required this.cacheKey,
  });

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  Duration? _duration;
  Duration? _position;
  String? _tempFilePath;
  static final _audioCache = <String, File>{};

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _initializePlayer();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Initialize audio player
      _audioPlayer = AudioPlayer();

      // Setup listeners
      _audioPlayer.playerStateStream.listen((playerState) {
        if(!mounted) return;
        setState(() {
          _isPlaying = playerState.playing;
        });
      });

      _audioPlayer.durationStream.listen((duration) {
        if(!mounted) return;
        setState(() => _duration = duration);
      });

      _audioPlayer.positionStream.listen((position) {
        if(!mounted) return;
        setState(() => _position = position);
      });

      _audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          if (e is PlayerException) {
            debugPrint('Error code: ${e.code}');
            debugPrint('Error message: ${e.message}');
          } else {
            debugPrint('An error occurred: $e');
          }
          if(!mounted) return;
          setState(() => _hasError = true);
        },
      );

      // Check cache first
      if (_audioCache.containsKey(widget.cacheKey)) {
        _tempFilePath = _audioCache[widget.cacheKey]!.path;
      } else {
        // Create temporary file
        final tempDir = await getTemporaryDirectory();
        final extension = widget.fileName?.split('.').last ?? 'mp3';
        _tempFilePath = '${tempDir.path}/${widget.cacheKey}.$extension';
        final file = File(_tempFilePath!);
        await file.writeAsBytes(widget.audioBytes);
        _audioCache[widget.cacheKey] = file;
      }

      // Set audio source
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.file(_tempFilePath!)),
      );
      if(!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if(!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      debugPrint('Player initialization error: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_isLoading || _hasError) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      if(!mounted) return;
      setState(() => _hasError = true);
      debugPrint('Playback error: $e');
    }
  }

  Future<void> _seekAudio(double value) async {
    if (_isLoading || _hasError || _duration == null) return;
    try {
      await _audioPlayer.seek(Duration(seconds: value.toInt()));
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  Future<void> _stopPlayer() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _position = Duration.zero;
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Text(
              'Error playing audio',
              style: TextStyle(color: Colors.red),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _initializePlayer();
              },
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 8),
            const Text('Loading audio...'),
            const Spacer(),
            if (_tempFilePath != null)
              Text(
                '${(widget.audioBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.fileName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.fileName!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _togglePlayback,
              ),
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: (_position?.inSeconds.toDouble() ?? 0).clamp(
                        0,
                        _duration?.inSeconds.toDouble() ?? 1,
                      ),
                      min: 0,
                      max: _duration?.inSeconds.toDouble() ?? 1,
                      onChanged: _seekAudio,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.  withOpacity(0.24),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.stop,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: _stopPlayer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FileDisplayWidget extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  final String encrypted;
  final Message message;
  final String cacheKey;

  const FileDisplayWidget({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.encrypted,
    required this.message,
    required this.cacheKey,
  });

  @override
  State<FileDisplayWidget> createState() => _FileDisplayWidgetState();
}

class _FileDisplayWidgetState extends State<FileDisplayWidget> {
  final double iconSize = 48;
  static final _fileCache = <String, File>{};

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  Future<void> _downloadAndDecryptFile(Message message) async {
    try {
      if (_fileCache.containsKey(widget.cacheKey)) {
        final cachedFile = _fileCache[widget.cacheKey]!;
        final openResult = await OpenFile.open(cachedFile.path);
        if (mounted) {
          if (openResult.type == ResultType.done) {
            _showSnackBar('File opened from cache');
          } else {
            _showSnackBar('File could not be opened: ${openResult.message}');
          }
        }
        return;
      }
      // 1. Validate message and URL
      if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
        if (mounted) _showSnackBar('No file available to download');
        return;
      }

      // 2. Check storage permission
      final status = await Permission.storage.request();
      log("status $status");
      if (!status.isGranted) {
        if (mounted) _showSnackBar('Storage permission required');
        return;
      }

      // 3. Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Downloading File'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing file...'),
                ],
              ),
            ),
      );

      // 4. Get valid file reference
      String filePath = message.mediaUrl!;
      Reference ref;

      try {
        // Try direct reference first
        ref = FirebaseStorage.instance.refFromURL(filePath);
      } catch (e) {
        // Fallback to constructing path manually if needed
        try {
          final uri = Uri.parse(filePath);
          final pathSegments = uri.pathSegments;
          final bucket = uri.host;
          final objectPath = pathSegments.join('/');
          ref = FirebaseStorage.instanceFor(bucket: bucket).ref(objectPath);
        } catch (e) {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            _showSnackBar('Invalid file path');
          }
          return;
        }
      }

      // 5. Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${message.fileInfo}');

      // 6. Download with progress monitoring
      try {
        final downloadTask = ref.writeToFile(tempFile);

        downloadTask.snapshotEvents.listen((taskSnapshot) {
          debugPrint(
            'Progress: ${taskSnapshot.bytesTransferred}/${taskSnapshot.totalBytes}',
          );
        });

        await downloadTask;
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showSnackBar('Download failed: ${e.toString()}');
        }
        return;
      }

      // 7. Verify download completed
      if (!await tempFile.exists()) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          _showSnackBar('Downloaded file not found');
        }
        return;
      }

      // 8. Read and decrypt file
      final encryptedBytes = await tempFile.readAsBytes();
      final decryptedBytes = await FreebaseEncryptionService.decryptFile(
        encryptedBytes,
        widget.encrypted,
      );

      // 9. Save to permanent location
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/${message.fileInfo}';
      final permanentFile = File(savePath);
      await permanentFile.writeAsBytes(decryptedBytes);

      // 10. Clean up and show success
      await tempFile.delete();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // 11. Open the file
      final openResult = await OpenFile.open(savePath);
      if (mounted) {
        if (openResult.type == ResultType.done) {
          _showSnackBar('File saved successfully');
        } else {
          _showSnackBar('File saved but could not open: ${openResult.message}');
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Firebase error: ${e.message}');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('System error: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Error: ${e.toString()}');
      }
      debugPrint('Download error details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileExt = widget.fileName.split('.').last.toLowerCase();
    final fileSize = widget.bytes.lengthInBytes / (1024 * 1024); // In MB

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          _buildFileIcon(fileExt),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '${fileSize.toStringAsFixed(2)} MB',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _downloadAndDecryptFile(widget.message),
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String extension) {
    final iconData = _getIconForExtension(extension);
    final color = _getColorForExtension(extension);

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(iconData, size: iconSize * 0.6, color: color)),
    );
  }

  IconData _getIconForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
