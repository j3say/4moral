import 'package:flutter/material.dart';
import 'package:fourmoral/screens/story/user_story.dart';

class StoryCircleAvatar extends StatelessWidget {
  final UserStory userStory;
  final double size;
  final VoidCallback onTap;

  const StoryCircleAvatar({
    super.key,
    required this.userStory,
    this.size = 70.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: userStory.hasUnseenStories ? Colors.blue : Colors.grey,
                  width: 2.0,
                ),
                image: DecorationImage(
                  image: NetworkImage(userStory.profilePic),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  userStory.stories.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
