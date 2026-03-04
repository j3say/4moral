// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:fourmoral/models/story_model.dart';

import '../../models/post_model.dart';
import '../../models/user_profile_model.dart';

ProfileModel profileDataServices(value) {
  ProfileModel temp;
  temp = ProfileModel(
    '${value.get('mobileNumber')}'.toString() != "null"
        ? '${value.get('mobileNumber')}'.toString()
        : "",
    '${value.get('profilePicture')}'.toString() != "null"
        ? '${value.get('profilePicture')}'.toString()
        : "",
    '${value.get('username')}'.toString() != "null"
        ? '${value.get('username')}'.toString()
        : "",
    '${value.get('type')}'.toString() != "null"
        ? '${value.get('type')}'.toString()
        : "",
    '${value.get('bio')}'.toString() != "null"
        ? '${value.get('bio')}'.toString()
        : "",
    '${value.get('uniqueId')}'.toString() != "null"
        ? '${value.get('uniqueId')}'.toString()
        : "",
    '${value.get('name')}'.toString() != "null"
        ? '${value.get('name')}'.toString()
        : "",
    '${value.get('age')}'.toString() != "null"
        ? '${value.get('age')}'.toString()
        : "",
    '${value.get('gender')}'.toString() != "null"
        ? '${value.get('gender')}'.toString()
        : "",
    '${value.get('address')}'.toString() != "null"
        ? '${value.get('address')}'.toString()
        : "",
    '${value.get('emailAddress')}'.toString() != "null"
        ? '${value.get('emailAddress')}'.toString()
        : "",
    '${value.get('religion')}'.toString() != "null"
        ? '${value.get('religion')}'.toString()
        : "",
    '${value.get('followMentors')}'.toString() != "null"
        ? '${value.get('followMentors')}'.toString()
        : "",
    '${value.get('likePosts')}'.toString() != "null"
        ? '${value.get('likePosts')}'.toString()
        : "",
    '${value.get('savedPosts')}'.toString() != "null"
        ? '${value.get('savedPosts')}'.toString()
        : "",
    '${value.get('watchLater')}'.toString() != "null"
        ? '${value.get('watchLater')}'.toString()
        : "",
    '${value.get('block')}'.toString() != "null"
        ? '${value.get('block')}'.toString()
        : "",
    '${value.get('verified')}'.toString() != "null"
        ? value.get('verified')
        : false,
    '${value.get('privateAccount')}'.toString() != "null"
        ? value.get('privateAccount')
        : false,
    '${value.get('recording')}' != "null" ? value.get('recording') : false,
    '${value.get('uid')}'.toString() != "null"
        ? '${value.get('uid')}'.toString()
        : "",
    '${value.get('contactAccount')}'.toString() != "null"
        ? value.get('contactAccount')
        : false,

  );
  return temp;
}

StoryModel storyDataServices(keyDatabase, value, category) {
  StoryModel temp;

  if (value['type'].toString() == "Photo") {
    temp = StoryModel(
      keyDatabase,
      '${value['key']}'.toString() != "null"
          ? '${value['key']}'.toString()
          : "",
      '${value['dateTime']}'.toString() != "null"
          ? '${value['dateTime']}'.toString()
          : "",
      '${value['caption']}'.toString() != "null"
          ? '${value['caption']}'.toString()
          : "",
      '${value['mobileNumber']}'.toString() != "null"
          ? '${value['mobileNumber']}'.toString()
          : "",
      '${value['profilePicture']}'.toString() != "null"
          ? '${value['profilePicture']}'.toString()
          : "",
      "",
      '${value['type']}'.toString() != "null"
          ? '${value['type']}'.toString()
          : "",
      '${value['actype']}'.toString() != "null"
          ? '${value['actype']}'.toString()
          : "",
      '${value['url']}'.toString() != "null"
          ? '${value['url']}'.toString()
          : "",
      '${value['username']}'.toString() != "null"
          ? '${value['username']}'.toString()
          : "",
      category.toString(),
    );
  } else {
    temp = StoryModel(
      keyDatabase,
      '${value['key']}'.toString() != "null"
          ? '${value['key']}'.toString()
          : "",
      '${value['dateTime']}'.toString() != "null"
          ? '${value['dateTime']}'.toString()
          : "",
      '${value['caption']}'.toString() != "null"
          ? '${value['caption']}'.toString()
          : "",
      '${value['mobileNumber']}'.toString() != "null"
          ? '${value['mobileNumber']}'.toString()
          : "",
      '${value['profilePicture']}'.toString() != "null"
          ? '${value['profilePicture']}'.toString()
          : "",
      '${value['thumbnail']}'.toString() != "null"
          ? '${value['thumbnail']}'.toString()
          : "",
      '${value['type']}'.toString() != "null"
          ? '${value['type']}'.toString()
          : "",
      '${value['actype']}'.toString() != "null"
          ? '${value['actype']}'.toString()
          : "",
      '${value['url']}'.toString() != "null"
          ? '${value['url']}'.toString()
          : "",
      '${value['username']}'.toString() != "null"
          ? '${value['username']}'.toString()
          : "",
      category.toString(),
    );
  }

  return temp;
}

PostModel postDataServices(DocumentSnapshot value, String category) {
  try {
    final data = value.data() as Map<String, dynamic>? ?? {};
    final isPhoto = data['type']?.toString() == 'Photo';

    return PostModel(
      key: data['key']?.toString() ?? '',
      caption: data['caption']?.toString() ?? '',
      dateTime: data['dateTime']?.toString() ?? '', // Consider parsing to DateTime
      mobileNumber: data['mobileNumber']?.toString() ?? '',
      profilePicture: data['profilePicture']?.toString() ?? '',
      thumbnail: isPhoto ? <String>[] : List<String>.from(data['thumbnails'] ?? []),
      type: data['type']?.toString() ?? '',
      actype: data['actype']?.toString() ?? '',
      urls: List<String>.from(data['urls'] ?? data['url'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
      username: data['username']?.toString() ?? '',
      numberOfLikes: data['numberOfLikes']?.toString() ?? '',
      likesUsers: data['likesUsers']?.toString() ?? '',
      postCategory: category,
      hasLocation: data['hasLocation'] as bool? ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  } catch (e) {
    print('Error creating PostModel: $e');
    return PostModel(
      key: '',
      caption: '',
      dateTime: '',
      mobileNumber: '',
      profilePicture: '',
      thumbnail: <String>[],
      type: '',
      actype: '',
      urls: <String>[],
      mediaTypes: <String>[],
      username: '',
      numberOfLikes: '',
      likesUsers: '',
      postCategory: category,
      hasLocation: false,
      latitude: null,
      longitude: null,
    );
  }
}
