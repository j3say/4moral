import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'dart:async';

class HashtagCaptionField extends StatefulWidget {
  final Function(String) onChanged;
  final String hintText;
  final String userId; // Add user ID for personalized suggestions

  const HashtagCaptionField({
    super.key,
    required this.onChanged,
    required this.userId,
    this.hintText = "Add caption...",
  });

  @override
  _HashtagCaptionFieldState createState() => _HashtagCaptionFieldState();
}

class _HashtagCaptionFieldState extends State<HashtagCaptionField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Keeps track of the current hashtag/mention being typed
  String _currentWord = '';

  // Position where to show the suggestions overlay
  OverlayEntry? _overlayEntry;

  // For storing and showing suggestions
  List<String> _suggestions = [];

  // Firebase references
  late DatabaseReference _hashtagsRef;
  late DatabaseReference _usersRef;
  late DatabaseReference _userTagsRef;

  // Debounce timer for search optimization
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Initialize Firebase references
    _hashtagsRef = FirebaseDatabase.instance.ref().child('hashtags');
    _usersRef = FirebaseDatabase.instance.ref().child('Users');
    _userTagsRef = FirebaseDatabase.instance
        .ref()
        .child('user_tags')
        .child(widget.userId);

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onChanged(text);

    // Find the word being currently typed
    final selection = _controller.selection;
    if (selection.baseOffset != -1) {
      final cursorPos = selection.baseOffset;

      // Find the start position of the current word
      int startLookingFrom = cursorPos - 1;
      while (startLookingFrom >= 0) {
        if (text[startLookingFrom] == ' ' || text[startLookingFrom] == '\n') {
          break;
        }
        startLookingFrom--;
      }

      // Extract the current word being typed
      final currentWord = text.substring(startLookingFrom + 1, cursorPos);

      if (currentWord.startsWith('#')) {
        // User is typing a hashtag
        _currentWord = currentWord;
        _searchHashtags(currentWord.substring(1));
      } else if (currentWord.startsWith('@')) {
        // User is typing a username mention
        _currentWord = currentWord;
        _searchUsers(currentWord.substring(1));
      } else {
        // User is not typing a hashtag or username
        _removeOverlay();
        _currentWord = '';
      }
    }
  }

  void _searchHashtags(String query) {
    // Cancel previous debounce if exists
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    // Debounce to avoid too many database queries
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        // If just # is typed, show trending hashtags
        try {
          final snapshot =
              await _hashtagsRef.orderByChild('count').limitToLast(10).get();

          if (snapshot.exists) {
            // Convert snapshot to map
            Map<dynamic, dynamic> values =
                snapshot.value as Map<dynamic, dynamic>;

            // Sort hashtags by count
            List<MapEntry<dynamic, dynamic>> sortedEntries =
                values.entries.toList();
            sortedEntries.sort(
              (a, b) =>
                  (b.value['count'] as int).compareTo(a.value['count'] as int),
            );

            // Format hashtags with # prefix
            setState(() {
              _suggestions =
                  sortedEntries
                      .map((entry) => '#${entry.key.toString()}')
                      .toList();
            });

            _showSuggestionsOverlay();
          } else {
            _removeOverlay();
          }
        } catch (e) {
          print('Error fetching trending hashtags: $e');
          _removeOverlay();
        }
      } else {
        // Search for hashtags that start with the query
        try {
          final snapshot =
              await _hashtagsRef
                  .orderByKey()
                  .startAt(query)
                  .endAt('$query\uf8ff') // Firebase key for range queries
                  .limitToFirst(10)
                  .get();

          if (snapshot.exists) {
            Map<dynamic, dynamic> values =
                snapshot.value as Map<dynamic, dynamic>;

            setState(() {
              _suggestions =
                  values.keys.map((key) => '#${key.toString()}').toList();
            });

            _showSuggestionsOverlay();
          } else {
            // No matching hashtags, suggest the new one
            setState(() {
              _suggestions = ['#$query'];
            });
            _showSuggestionsOverlay();
          }
        } catch (e) {
          print('Error searching hashtags: $e');
          _removeOverlay();
        }
      }
    });
  }

  void _searchUsers(String query) {
    // Cancel previous debounce if exists
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    // Debounce to avoid too many database queries
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        // If just @ is typed, show suggested users
        try {
          final snapshot = await _usersRef.limitToLast(10).get();

          if (snapshot.exists) {
            Map<dynamic, dynamic> values =
                snapshot.value as Map<dynamic, dynamic>;

            setState(() {
              _suggestions =
                  values.entries
                      .map((entry) => '@${entry.key.toString()}')
                      .toList();
            });

            _showSuggestionsOverlay();
          } else {
            _removeOverlay();
          }
        } catch (e) {
          print('Error fetching suggested users: $e');
          _removeOverlay();
        }
      } else {
        // Search for users that match the query
        try {
          final snapshot =
              await _usersRef
                  .orderByChild('username')
                  .startAt(query)
                  .endAt('$query\uf8ff')
                  .limitToFirst(10)
                  .get();

          if (snapshot.exists) {
            Map<dynamic, dynamic> values =
                snapshot.value as Map<dynamic, dynamic>;

            setState(() {
              _suggestions =
                  values.entries.map((entry) {
                    // Get username from the user data
                    String username =
                        entry.value['username'] ?? entry.key.toString();
                    return '@$username';
                  }).toList();
            });

            _showSuggestionsOverlay();
          } else {
            _removeOverlay();
          }
        } catch (e) {
          print('Error searching users: $e');
          _removeOverlay();
        }
      }
    });
  }

  void _insertSuggestion(String suggestion) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;

    // Find the start position of the hashtag/mention
    int startPos = cursorPos - 1;
    while (startPos >= 0) {
      if (text[startPos] == ' ' || text[startPos] == '\n') {
        break;
      }
      startPos--;
    }
    startPos++;

    // Replace the current word with the suggestion
    final newText = text.replaceRange(startPos, cursorPos, '$suggestion ');

    // Update the text and cursor position
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: startPos + suggestion.length + 1,
      ),
    );

    _removeOverlay();

    // If it's a hashtag, save it to the database
    if (suggestion.startsWith('#')) {
      _saveHashtag(suggestion.substring(1)); // Remove # before saving
    }
  }

  Future<void> _saveHashtag(String hashtag) async {
    try {
      // Update hashtag count in global hashtags
      final tagRef = _hashtagsRef.child(hashtag);
      final snapshot = await tagRef.child('count').get();
      int currentCount = snapshot.exists ? (snapshot.value as int) : 0;

      await tagRef.update({
        'count': currentCount + 1,
        'lastUsed': ServerValue.timestamp,
      });

      // Add to user's recent hashtags
      await _userTagsRef.child(hashtag).set(ServerValue.timestamp);
    } catch (e) {
      print('Error saving hashtag: $e');
    }
  }

  void _showSuggestionsOverlay() {
    if (_suggestions.isEmpty) {
      _removeOverlay();
      return;
    }

    _removeOverlay();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: offset.dy + renderBox.size.height,
            left: offset.dx,
            width: renderBox.size.width,
            child: Material(
              elevation: 4.0,
              child: Container(
                height: min(_suggestions.length * 50.0, 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4.0),
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

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      maxLines: 5,
      minLines: 1,
    );
  }
}
