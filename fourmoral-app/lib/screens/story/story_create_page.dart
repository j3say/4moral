import 'dart:async';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story2_modal.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'dart:ui' as ui;

class StoryCreatePage extends StatefulWidget {
  const StoryCreatePage({super.key, this.profileModel});
  final ProfileModel? profileModel;

  @override
  _StoryCreatePageState createState() => _StoryCreatePageState();
}

class _StoryCreatePageState extends State<StoryCreatePage> {
  final Story2Controller storyController = Get.put(Story2Controller());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Text story variables
  bool _isTextStory = false;
  String _storyText = '';
  final TextEditingController _textController = TextEditingController();
  Color _selectedBgColor = Colors.purple;
  final List<Color> _bgColorOptions = [
    Colors.purple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.black,
  ];
  TextAlign _textAlignment = TextAlign.center;
  double _fontSize = 24.0;
  bool _isBold = false;

  // Caption field
  final TextEditingController _captionController = TextEditingController();
  final bool _showCaptionField = true;
  final FocusNode _captionFocusNode = FocusNode();

  List<Map<String, dynamic>> _followerUsers = [];
  List<String> _restrictedUsers = [];
  bool _showUserSelection = false;
  bool _isLoadingUsers = false;
  int _cursorPosition = 0;
  String _currentWord = '';
  bool _isTypingHashtag = false;
  bool _isTypingMention = false;
  File? _imageFile;
  File? _videoFile;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  List<String> _suggestions = [];
  OverlayEntry? _overlayEntry;

  late DatabaseReference _hashtagsRef;
  late DatabaseReference _userTagsRef;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _hashtagsRef = FirebaseDatabase.instance.ref().child('hashtags');
    _userTagsRef = FirebaseDatabase.instance.ref().child('user_tags');
    _captionController.addListener(_onTextChanged);
    _captionFocusNode.addListener(() {
      if (!_captionFocusNode.hasFocus) {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _videoController?.dispose();
    _chewieController?.dispose();
    _textController.dispose();
    _captionController.removeListener(_onTextChanged);
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _captionController.text;
    final selection = _captionController.selection;

    if (selection.baseOffset != -1) {
      _cursorPosition = selection.baseOffset;

      // Find the start position of the current word
      int startLookingFrom = _cursorPosition - 1;
      while (startLookingFrom >= 0) {
        if (text[startLookingFrom] == ' ' || text[startLookingFrom] == '\n') {
          break;
        }
        startLookingFrom--;
      }

      // Extract the current word being typed
      final word = text.substring(startLookingFrom + 1, _cursorPosition);

      if (word.startsWith('#')) {
        _currentWord = word;
        _isTypingHashtag = true;
        _isTypingMention = false;
        _searchHashtags(word.substring(1));
      } else if (word.startsWith('@')) {
        _currentWord = word;
        _isTypingHashtag = false;
        _isTypingMention = true;
        _searchUsers(word.substring(1));
      } else {
        _isTypingHashtag = false;
        _isTypingMention = false;
        _currentWord = '';
        _removeOverlay();
      }
    }
  }

  void _searchHashtags(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        final trendingSnapshot =
            await _hashtagsRef.orderByChild('count').limitToLast(5).get();

        if (trendingSnapshot.exists) {
          Map<dynamic, dynamic> values =
              trendingSnapshot.value as Map<dynamic, dynamic>;
          List<MapEntry<dynamic, dynamic>> sortedEntries =
              values.entries.toList();
          sortedEntries.sort(
            (a, b) =>
                (b.value['count'] as int).compareTo(a.value['count'] as int),
          );

          setState(() {
            _suggestions =
                sortedEntries
                    .map((entry) => '#${entry.key.toString()}')
                    .toList();
          });
        }
      } else {
        final searchSnapshot =
            await _hashtagsRef
                .orderByKey()
                .startAt(query)
                .endAt('$query\uf8ff')
                .limitToFirst(5)
                .get();

        if (searchSnapshot.exists) {
          Map<dynamic, dynamic> values =
              searchSnapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _suggestions =
                values.keys.map((key) => '#${key.toString()}').toList();
          });
        } else {
          setState(() {
            _suggestions = ['#$query'];
          });
        }
      }

      if (_suggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        setState(() {
          _suggestions = [];
        });
        _removeOverlay();
        return;
      }

      final QuerySnapshot result =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('username', isGreaterThanOrEqualTo: query)
              .where('username', isLessThan: '${query}z')
              .limit(10)
              .get();

      final List<String> usernames =
          result.docs.map((doc) => '@${doc['username']}').toList();

      setState(() {
        _suggestions = usernames;
      });

      if (_suggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _suggestions = [];
      });
      _removeOverlay();
    }
  }

  void _insertSuggestion(String suggestion) {
    final text = _captionController.text;
    int startPos = _cursorPosition - 1;
    while (startPos >= 0) {
      if (text[startPos] == ' ' || text[startPos] == '\n') {
        break;
      }
      startPos--;
    }
    startPos++;

    final newText = text.replaceRange(
      startPos,
      _cursorPosition,
      '$suggestion ',
    );

    _captionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: startPos + suggestion.length + 1,
      ),
    );

    _removeOverlay();

    if (suggestion.startsWith('#')) {
      _saveHashtag(suggestion);
    }
  }

  bool _isValidHashtag(String hashtag) {
    String cleanTag = hashtag.substring(1);
    return cleanTag.length >= 2 &&
        cleanTag.length <= 20 &&
        RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cleanTag);
  }

  Future<void> _saveHashtag(String hashtag) async {
    String cleanHashtag = hashtag.substring(1);
    final tagRef = _hashtagsRef.child(cleanHashtag);
    final snapshot = await tagRef.child('count').get();
    int currentCount = snapshot.exists ? (snapshot.value as int) : 0;

    await tagRef.update({
      'count': currentCount + 1,
      'lastUsed': ServerValue.timestamp,
    });

    await _userTagsRef.child(cleanHashtag).set(ServerValue.timestamp);
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    final textPainter = TextPainter(
      text: TextSpan(
        text: _captionController.text.substring(0, _cursorPosition),
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final cursorOffset = textPainter.size.height + 40;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: offset.dy + cursorOffset,
            left: offset.dx + 10,
            width: renderBox.size.width - 20,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        suggestion,
                        style: TextStyle(
                          color:
                              suggestion.startsWith('#')
                                  ? Colors.blue
                                  : Colors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () => _insertSuggestion(suggestion),
                    );
                  },
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        final imageData = await File(pickedFile.path).readAsBytes();

        final editedImage = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageEditor(image: imageData),
          ),
        );

        if (editedImage != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/edited_story_image.jpg');
          await tempFile.writeAsBytes(editedImage);

          setState(() {
            _isTextStory = false;
            _imageFile = tempFile;
            _videoFile = null;
            _videoController?.dispose();
            _chewieController?.dispose();
            _videoController = null;
            _chewieController = null;
          });
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickVideo(source: source);
      if (pickedFile != null) {
        setState(() {
          _isTextStory = false;
          _videoFile = File(pickedFile.path);
          _imageFile = null;
          _initializeVideoPlayer();
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick video: ${e.toString()}');
    }
  }

  void _createTextStory() {
    setState(() {
      _isTextStory = true;
      _imageFile = null;
      _videoFile = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
    });
  }

  void _initializeVideoPlayer() {
    _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = VideoPlayerController.file(_videoFile!)
      ..initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: true,
            showControls: true,
          );
        });
      });
  }

  Future<void> _uploadStory() async {
    final caption = _captionController.text.trim();

    // Extract and save hashtags
    final RegExp hashtagRegExp = RegExp(r'\#(\w+)');
    final matches = hashtagRegExp.allMatches(caption);
    for (var match in matches) {
      if (match.group(0) != null) {
        _saveHashtag(match.group(0)!);
      }
    }

    if (_isTextStory) {
      if (_storyText.isEmpty) {
        Get.snackbar('Error', 'Please enter some text for your story');
        return;
      }

      final textStoryImage = await _createTextStoryImage();
      if (textStoryImage == null) {
        Get.snackbar('Error', 'Failed to create text story image');
        return;
      }

      await storyController.uploadStory(
        textStoryImage,
        StoryType.image,
        caption: caption,
        restrictedUsers: _restrictedUsers,
      );
    } else if (_imageFile != null || _videoFile != null) {
      final storyType = _imageFile != null ? StoryType.image : StoryType.video;
      final mediaFile = _imageFile ?? _videoFile!;

      await storyController.uploadStory(
        mediaFile,
        storyType,
        caption: caption,
        restrictedUsers: _restrictedUsers,
      );
    } else {
      Get.snackbar('Error', 'Please create a story first');
      return;
    }

    // Clear after upload
    setState(() {
      _isTextStory = false;
      _storyText = '';
      _textController.clear();
      _captionController.clear();
      _imageFile = null;
      _videoFile = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
      _restrictedUsers = [];
    });
  }

  Future<File?> _createTextStoryImage() async {
    try {
      final width = MediaQuery.of(context).size.width;
      final height = width * 16 / 9;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = _selectedBgColor;

      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: _storyText,
          style: TextStyle(
            color: Colors.white,
            fontSize: _fontSize,
            fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: _textAlignment,
      );

      textPainter.layout(maxWidth: width - 48);

      final xPos =
          _textAlignment == TextAlign.center
              ? (width - textPainter.width) / 2
              : _textAlignment == TextAlign.right
              ? width - textPainter.width - 24
              : 24;

      textPainter.paint(
        canvas,
        Offset(xPos.toDouble(), (height - textPainter.height) / 2),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      // Save the image to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/text_story.png');
      await tempFile.writeAsBytes(buffer);

      return tempFile;
    } catch (e) {
      print('Error creating text story image: ${e.toString()}');
      return null;
    }
  }

  void _toggleUserRestriction(String userId) {
    setState(() {
      if (_restrictedUsers.contains(userId)) {
        _restrictedUsers.remove(userId);
      } else {
        _restrictedUsers.add(userId);
      }
    });
  }

  Future<void> _fetchFollowersFromAllUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
        _followerUsers = [];
      });

      String? currentUserContact = widget.profileModel?.mobileNumber;
      if (currentUserContact == null || currentUserContact.isEmpty) {
        Get.snackbar('Error', 'Current user contact information not available');
        setState(() => _isLoadingUsers = false);
        return;
      }

      final querySnapshot = await _firestore.collection('Users').get();
      final List<Map<String, dynamic>> followers = [];

      for (var doc in querySnapshot.docs) {
        final userData = doc.data();
        final String? followMentors = userData['followMentors'] as String?;

        if (followMentors != null &&
            followMentors.contains(currentUserContact)) {
          followers.add({
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown User',
            'contact': userData['contact'] ?? '',
            'avatar': userData['profilePicture'] ?? '',
          });
        }
      }

      setState(() {
        _followerUsers = followers;
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Error fetching followers: ${e.toString()}');
      Get.snackbar('Error', 'Failed to load followers: ${e.toString()}');
      setState(() => _isLoadingUsers = false);
    }
  }

  void _showFollowerSelectionPanel() async {
    await _fetchFollowersFromAllUsers();
    setState(() => _showUserSelection = true);
  }

  Widget _buildUserSelectionPanel() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Text(
            'Hide story from',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Select followers who shouldn\'t see this story',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Divider(),
          _isLoadingUsers
              ? Center(child: CircularProgressIndicator())
              : _followerUsers.isEmpty
              ? Center(child: Text('No followers found'))
              : Expanded(
                child: ListView.builder(
                  itemCount: _followerUsers.length,
                  itemBuilder: (context, index) {
                    final user = _followerUsers[index];
                    return CheckboxListTile(
                      value: _restrictedUsers.contains(user['id']),
                      onChanged: (value) => _toggleUserRestriction(user['id']),
                      title: Text(user['name']),
                      subtitle: Text(user['contact']),
                      secondary: CircleAvatar(
                        backgroundImage:
                            user['avatar'].isNotEmpty
                                ? NetworkImage(user['avatar'])
                                : null,
                        child:
                            user['avatar'].isEmpty ? Icon(Icons.person) : null,
                      ),
                    );
                  },
                ),
              ),
          ElevatedButton(
            onPressed: () => setState(() => _showUserSelection = false),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
            ),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _bgColorOptions.length,
        itemBuilder: (context, index) {
          final color = _bgColorOptions[index];
          final isSelected = color == _selectedBgColor;

          return GestureDetector(
            onTap: () => setState(() => _selectedBgColor = color),
            child: Container(
              width: 30,
              height: 30,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow:
                    isSelected
                        ? [BoxShadow(color: Colors.black26, blurRadius: 2)]
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextStoryEditor() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: _selectedBgColor),
            padding: EdgeInsets.all(16),
            child: Center(
              child: TextField(
                controller: _textController,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your story...',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _fontSize,
                  fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: _textAlignment,
                onChanged: (value) {
                  setState(() {
                    _storyText = value;
                  });
                },
              ),
            ),
          ),
        ),

        // Bottom controls panel
        Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildColorSelector(),
              SizedBox(height: 8),

              // Text formatting controls - simplified
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Text formatting
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.format_align_left, size: 20),
                        color:
                            _textAlignment == TextAlign.left
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                        onPressed:
                            () =>
                                setState(() => _textAlignment = TextAlign.left),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.format_align_center, size: 20),
                        color:
                            _textAlignment == TextAlign.center
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                        onPressed:
                            () => setState(
                              () => _textAlignment = TextAlign.center,
                            ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.format_align_right, size: 20),
                        color:
                            _textAlignment == TextAlign.right
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                        onPressed:
                            () => setState(
                              () => _textAlignment = TextAlign.right,
                            ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.format_bold, size: 20),
                        color:
                            _isBold
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                        onPressed: () => setState(() => _isBold = !_isBold),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),

                  // Right side: Font size controls
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 20),
                        onPressed:
                            () => setState(() {
                              if (_fontSize > 16) _fontSize -= 2;
                            }),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      Text(
                        '${_fontSize.toInt()}',
                        style: TextStyle(fontSize: 14),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 20),
                        onPressed:
                            () => setState(() {
                              if (_fontSize < 36) _fontSize += 2;
                            }),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSelectionOptions() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple icon buttons with text
          _buildMediaOption(
            icon: Icons.text_fields,
            label: 'Text',
            onTap: _createTextStory,
          ),
          SizedBox(width: 20),
          _buildMediaOption(
            icon: Icons.photo_library,
            label: 'Photo',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          SizedBox(width: 20),
          _buildMediaOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () => _pickImage(ImageSource.camera),
          ),
          SizedBox(width: 20),
          _buildMediaOption(
            icon: Icons.videocam,
            label: 'Video',
            onTap: () => _pickVideo(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            child: Icon(icon, size: 30, color: Theme.of(context).primaryColor),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCaptionField() {
    Size size = MediaQuery.of(context).size;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 80, // Position above the send button
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: TextFormField(
          controller: _captionController,
          focusNode: _captionFocusNode,
          scrollPadding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          cursorWidth: ((0.067 * size.height) / 100),
          cursorColor: Colors.black,
          style: TextStyle(
            fontSize: ((2.032 * size.height) / 100),
            color: Colors.black,
          ),
          decoration: InputDecoration(
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
            hintText: 'Write a caption... Use # for hashtags or @ for mentions',
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            contentPadding: EdgeInsets.only(
              left: ((1.896 * size.height) / 100),
              right: ((1.896 * size.height) / 100),
              top: 10,
              bottom: 10,
            ),
          ),
          maxLines: 5,
          minLines: 3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Story',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        elevation: 0,
        backgroundColor: _isTextStory ? _selectedBgColor : null,
        actions:
            _isTextStory || _imageFile != null || _videoFile != null
                ? [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.visibility_off),
                      tooltip: 'Restrict viewers',
                      onPressed: _showFollowerSelectionPanel,
                    ),
                  ),
                  SizedBox(width: 8),
                ]
                : null,
      ),
      body: Stack(
        children: [
          // Main content
          if (_isTextStory)
            _buildTextStoryEditor()
          else if (_imageFile != null)
            Stack(
              children: [
                Image.file(
                  _imageFile!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ],
            )
          else if (_videoFile != null && _chewieController != null)
            Chewie(controller: _chewieController!)
          else
            _buildMediaSelectionOptions(),

          // Caption field
          if (_isTextStory || _imageFile != null || _videoFile != null)
            _buildCaptionField(),

          // User Selection Panel (overlay)
          if (_showUserSelection)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showUserSelection = false),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black54,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildUserSelectionPanel(),
                  ),
                ),
              ),
            ),

          // Upload Progress Indicator
          Obx(
            () =>
                storyController.isUploading.value
                    ? Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(),
                    )
                    : const SizedBox(),
          ),

          // Send button (Only show when content is ready)
          if (_isTextStory || _imageFile != null || _videoFile != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: _uploadStory,
                mini: false,
                child: Icon(Icons.send),
              ),
            ),
        ],
      ),
    );
  }
}
