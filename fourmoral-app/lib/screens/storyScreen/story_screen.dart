import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:story_view/story_view.dart';

class StoryPageView extends StatefulWidget {
  const StoryPageView({super.key, this.storyShowList, this.controller});

  final List<StoryItem>? storyShowList;
  final StoryController? controller;

  @override
  // ignore: library_private_types_in_public_api
  _StoryPageViewState createState() => _StoryPageViewState();
}

class _StoryPageViewState extends State<StoryPageView> {
  DatabaseReference refFirebaseStory = FirebaseDatabase.instance.ref().child(
    'Stories',
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: black,
      child:
          widget.storyShowList?.isNotEmpty ?? false
              ? Scaffold(
                body: StoryView(
                  storyItems: widget.storyShowList ?? [],
                  controller: widget.controller!,
                  onComplete: () {
                    Navigator.pop(context);
                  },
                  inline: true,
                  repeat: true,
                ),
              )
              : Center(
                child: Text(
                  "Story no longer available",
                  style: TextStyle(color: white),
                ),
              ),
    );
  }
}
