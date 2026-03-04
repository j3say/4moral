import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/services/location_service.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class EditPostController extends GetxController {
  final PostModel post;
  final ProfileModel profile;
  final DocumentReference postReference;

  final RxString caption = ''.obs;
  final RxBool includeLocation = false.obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxString locationString = ''.obs;
  final RxString currentWord = ''.obs;
  final RxInt cursorPosition = 0.obs;
  final RxBool isTypingHashtag = false.obs;
  final RxBool isTypingMention = false.obs;
  final RxList<String> suggestions = <String>[].obs;
  final Rx<OverlayEntry?> overlayEntry = Rx<OverlayEntry?>(null);
  late DatabaseReference hashtagsRef;
  late DatabaseReference userTagsRef;
  Timer? debounce;
  final FocusNode captionFocusNode = FocusNode();
  final TextEditingController captionController = TextEditingController();

  EditPostController({
    required this.post,
    required this.profile,
    required this.postReference,
  });

  @override
  void onInit() {
    super.onInit();
    // Initialize state
    caption.value = post.caption ?? '';
    captionController.text = post.caption ?? '';
    includeLocation.value = post.hasLocation ?? false;
    if (includeLocation.value) {
      locationString.value =
      "${post.latitude?.toStringAsFixed(4)}, ${post.longitude?.toStringAsFixed(4)}";
    }

    // Initialize Firebase references
    hashtagsRef = FirebaseDatabase.instance.ref().child('hashtags');
    userTagsRef = FirebaseDatabase.instance.ref().child('user_tags');

    // Add listeners
    captionController.addListener(_onTextChanged);
    captionFocusNode.addListener(() {
      if (!captionFocusNode.hasFocus) {
        _removeOverlay();
      }
    });
  }

  @override
  void onClose() {
    _removeOverlay();
    captionController.removeListener(_onTextChanged);
    captionController.dispose();
    captionFocusNode.dispose();
    debounce?.cancel();
    super.onClose();
  }

  void _onTextChanged() {
    final text = captionController.text;
    final selection = captionController.selection;

    if (selection.baseOffset != -1) {
      cursorPosition.value = selection.baseOffset;

      // Find the start position of the current word
      int startLookingFrom = cursorPosition.value - 1;
      while (startLookingFrom >= 0) {
        if (text[startLookingFrom] == ' ' || text[startLookingFrom] == '\n') {
          break;
        }
        startLookingFrom--;
      }

      // Extract the current word being typed
      final word = text.substring(startLookingFrom + 1, cursorPosition.value);

      if (word.startsWith('#')) {
        currentWord.value = word;
        isTypingHashtag.value = true;
        isTypingMention.value = false;
        _searchHashtags(word.substring(1));
      } else if (word.startsWith('@')) {
        currentWord.value = word;
        isTypingHashtag.value = false;
        isTypingMention.value = true;
        _searchUsers(word.substring(1));
      } else {
        isTypingHashtag.value = false;
        isTypingMention.value = false;
        currentWord.value = '';
        _removeOverlay();
      }
    }
  }

  void _searchHashtags(String query) async {
    if (debounce?.isActive ?? false) debounce!.cancel();

    debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        final trendingSnapshot = await hashtagsRef.orderByChild('count').limitToLast(5).get();

        if (trendingSnapshot.exists) {
          Map<dynamic, dynamic> values = trendingSnapshot.value as Map<dynamic, dynamic>;
          List<MapEntry<dynamic, dynamic>> sortedEntries = values.entries.toList();
          sortedEntries.sort(
                (a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int),
          );

          suggestions.value = sortedEntries.map((entry) => '#${entry.key.toString()}').toList();
        }
      } else {
        final searchSnapshot = await hashtagsRef
            .orderByKey()
            .startAt(query)
            .endAt('$query\uf8ff')
            .limitToFirst(5)
            .get();

        if (searchSnapshot.exists) {
          Map<dynamic, dynamic> values = searchSnapshot.value as Map<dynamic, dynamic>;
          suggestions.value = values.keys.map((key) => '#${key.toString()}').toList();
        } else {
          suggestions.value = ['#$query'];
        }
      }

      if (suggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        suggestions.value = [];
        _removeOverlay();
        return;
      }

      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('Users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '${query}z')
          .limit(10)
          .get();

      suggestions.value = result.docs.map((doc) => '@${doc['username']}').toList();

      if (suggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
      suggestions.value = [];
      _removeOverlay();
    }
  }

  void _insertSuggestion(String suggestion, BuildContext context) {
    final text = captionController.text;
    int startPos = cursorPosition.value - 1;
    while (startPos >= 0) {
      if (text[startPos] == ' ' || text[startPos] == '\n') {
        break;
      }
      startPos--;
    }
    startPos++;

    final newText = text.replaceRange(
      startPos,
      cursorPosition.value,
      '$suggestion ',
    );

    captionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: startPos + suggestion.length + 1,
      ),
    );
    caption.value = newText;

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
    if (!_isValidHashtag(hashtag)) return;
    String cleanHashtag = hashtag.substring(1);

    final tagRef = hashtagsRef.child(cleanHashtag);
    final snapshot = await tagRef.child('count').get();
    int currentCount = snapshot.exists ? (snapshot.value as int) : 0;

    await tagRef.update({
      'count': currentCount + 1,
      'lastUsed': ServerValue.timestamp,
    });

    await userTagsRef.child(cleanHashtag).set(ServerValue.timestamp);
  }

  void _showSuggestionsOverlay() {
    if (Get.context == null) return;
    _removeOverlay();
    final RenderBox? renderBox = Get.context!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);

    final textPainter = TextPainter(
      text: TextSpan(
        text: captionController.text.substring(0, cursorPosition.value),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final cursorOffset = textPainter.size.height + 40;

    overlayEntry.value = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + cursorOffset,
        left: offset.dx + 10,
        width: renderBox.size.width - 20,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    suggestion,
                    style: TextStyle(
                      color: suggestion.startsWith('#') ? Colors.blue : Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _insertSuggestion(suggestion, context),
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(Get.context!).insert(overlayEntry.value!);
    // debugPrint("Suggestions overlay shown: ${suggestions.value}");
  }

  void _removeOverlay() {
    overlayEntry.value?.remove();
    overlayEntry.value = null;
    debugPrint("Suggestions overlay removed");
  }

  Future<void> updatePost() async {
    try {
      // Check if document exists
      final docSnapshot = await postReference.get();
      if (!docSnapshot.exists) {
        throw Exception('Post document does not exist');
      }

      // Save hashtags
      final RegExp hashtagRegExp = RegExp(r'\#(\w+)');
      final matches = hashtagRegExp.allMatches(captionController.text);
      for (var match in matches) {
        if (match.group(0) != null) {
          _saveHashtag(match.group(0)!);
        }
      }

      // Update document
      await postReference.update({
        'caption': captionController.text,
        'hasLocation': includeLocation.value,
        'latitude': includeLocation.value ? currentPosition.value?.latitude : null,
        'longitude': includeLocation.value ? currentPosition.value?.longitude : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      Get.back(result: true);
      flutterShowToast("Post updated successfully");
    } catch (e) {
      flutterShowToast("Error updating post: ${e.toString()}");
      debugPrint('Error details: $e');
    }
  }

  Future<void> getUserLocation() async {
    includeLocation.value = true;
    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      currentPosition.value = position;
      locationString.value =
      "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      debugPrint("Location updated: ${locationString.value}");
    } else {
      includeLocation.value = false;
      locationString.value = "";
      flutterShowToast("Could not get location or permission denied");
      debugPrint("Location retrieval failed");
    }
  }
}