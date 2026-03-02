import 'package:fourmoral/screens/story/story2_modal.dart';

class UserStory {
  final String userId;
  final String username;
  final String profilePic;
  final List<Story2Model> stories;
  final bool hasUnseenStories;
  final String mobileNumber; // New field added

  UserStory({
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.stories,
    this.hasUnseenStories = false,
    required this.mobileNumber, // Add to constructor
  });

  factory UserStory.fromJson(Map<String, dynamic> json) {
    return UserStory(
      userId: json['userId'],
      username: json['username'],
      profilePic: json['profilePic'],
      stories: (json['stories'] as List)
          .map((story) => Story2Model.fromJson(story))
          .toList(),
      hasUnseenStories: json['hasUnseenStories'] ?? false,
      mobileNumber: json['mobileNumber'], // Parse from JSON
    );
  }
}
