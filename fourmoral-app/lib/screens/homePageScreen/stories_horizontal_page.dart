import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/story/user_story.dart';

class StoriesHorizontalPage extends StatelessWidget {
  final List<UserStory> stories;
  final ProfileModel? profileModel;
  final Function(UserStory) onStoryTap;

  const StoriesHorizontalPage({
    super.key,
    required this.stories,
    this.profileModel,
    required this.onStoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 66.5,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(50),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            return SizedBox(
              height: double.infinity,
              child: _buildStoryItem(story, onStoryTap),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoryItem(UserStory story, Function(UserStory) onTap) {
    return GestureDetector(
      onTap: () => onTap(story),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular avatar with border
            Container(
              padding: EdgeInsets.all(2), // Border width
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors:
                      story.hasUnseenStories
                          ? [Colors.purple, Colors.orange]
                          : [Colors.grey, Colors.grey],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: FadeInImage.assetNetwork(
                    placeholder: "assets/profilePlaceHolder.png",
                    image: story.profilePic ?? "",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SizedBox(height: 2),
            Text(
              story.username ?? "",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
