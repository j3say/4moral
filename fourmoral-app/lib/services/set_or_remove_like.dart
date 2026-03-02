import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:get/get.dart';

import '../models/post_model.dart';
import '../models/user_profile_model.dart';

final profileCnt = Get.put(ProfileController());

Future<void> setOrRemoveLike(
  PostModel postDataObject,
  ProfileModel profileDataModel,
  CollectionReference collectionPostReference,
  CollectionReference collectionUserReference,
  StateSetter setState,
) async {
  // Exit early if already processing a like action
  if (profileCnt.likeLoading) return;

  // Determine if this is a like or unlike action
  bool isLiking =
      !postDataObject.likesUsers.contains(profileDataModel.mobileNumber);

  try {
    profileCnt.likeLoading = true;
    profileCnt.update();

    // Optimistically update UI
    setState(() {
      if (isLiking) {
        postDataObject.numberOfLikes =
            (int.parse(postDataObject.numberOfLikes) + 1).toString();
        postDataObject.likesUsers =
            "${postDataObject.likesUsers}${profileDataModel.mobileNumber}//";
      } else {
        int newLikes = int.parse(postDataObject.numberOfLikes) - 1;
        postDataObject.numberOfLikes = (newLikes < 0 ? 0 : newLikes).toString();
        postDataObject.likesUsers = postDataObject.likesUsers.replaceAll(
          "${profileDataModel.mobileNumber}//",
          "",
        );
      }
    });

    // Update Firestore post
    final querySnapshot =
        await collectionPostReference
            .where('key', isEqualTo: postDataObject.key)
            .limit(1)
            .get();

    if (querySnapshot.docs.isEmpty) {
      flutterShowToast("Post not found");
      // Revert UI changes
      setState(() {
        if (isLiking) {
          postDataObject.numberOfLikes =
              (int.parse(postDataObject.numberOfLikes) - 1).toString();
          postDataObject.likesUsers = postDataObject.likesUsers.replaceAll(
            "${profileDataModel.mobileNumber}//",
            "",
          );
        } else {
          postDataObject.numberOfLikes =
              (int.parse(postDataObject.numberOfLikes) + 1).toString();
          postDataObject.likesUsers =
              "${postDataObject.likesUsers}${profileDataModel.mobileNumber}//";
        }
      });
      return;
    }

    final postDoc = querySnapshot.docs.first;
    String numberOfLikes = postDoc.get('numberOfLikes');
    String likesUsers = postDoc.get('likesUsers');
    int numberOfLikesInt = int.parse(numberOfLikes);

    if (isLiking) {
      numberOfLikesInt++;
      likesUsers = "$likesUsers${profileDataModel.mobileNumber}//";
    } else {
      numberOfLikesInt = (numberOfLikesInt - 1) < 0 ? 0 : numberOfLikesInt - 1;
      likesUsers = likesUsers.replaceAll(
        "${profileDataModel.mobileNumber}//",
        "",
      );
    }

    await postDoc.reference.update({
      'numberOfLikes': numberOfLikesInt.toString(),
      'likesUsers': likesUsers,
    });

    // Update user's likePosts
    final userSnapshot =
        await collectionUserReference
            .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
            .limit(1)
            .get();

    if (userSnapshot.docs.isNotEmpty) {
      final userDoc = userSnapshot.docs.first;
      String likePosts = userDoc.get('likePosts');
      likePosts =
          isLiking
              ? "$likePosts${postDataObject.key}//"
              : likePosts.replaceAll("${postDataObject.key}//", "");
      await userDoc.reference.update({'likePosts': likePosts});
    }

    // Add notification if liking (not for unliking)
    if (isLiking) {
      await FirebaseDatabase.instance
          .ref()
          .child('Users/${postDataObject.mobileNumber}/Notifications/')
          .push()
          .set({
            "type": "postLike",
            "mobileNumber": profileDataModel.mobileNumber,
            "time": DateTime.now().toString(),
            "url": postDataObject.urls.isNotEmpty ? postDataObject.urls[0] : '',
            "postId": postDataObject.key,
            "profilePicture": profileDataModel.profilePicture,
            "username": profileDataModel.username,
          });
    }

    // flutterShowToast(isLiking ? "Post liked" : "Post unliked");
  } catch (e) {
    debugPrint('Error updating like: $e');
    flutterShowToast("Failed to ${isLiking ? 'like' : 'unlike'} post");
    // Revert UI changes on error
    setState(() {
      if (isLiking) {
        postDataObject.numberOfLikes =
            (int.parse(postDataObject.numberOfLikes) - 1).toString();
        postDataObject.likesUsers = postDataObject.likesUsers.replaceAll(
          "${profileDataModel.mobileNumber}//",
          "",
        );
      } else {
        postDataObject.numberOfLikes =
            (int.parse(postDataObject.numberOfLikes) + 1).toString();
        postDataObject.likesUsers =
            "${postDataObject.likesUsers}${profileDataModel.mobileNumber}//";
      }
    });
  } finally {
    profileCnt.likeLoading = false;
    profileCnt.update();
  }
}

void setOrRemoveSaved(
  PostModel postDataObject,
  ProfileModel profileDataModel,
  collectionUserReference,
  setState,
) {
  if (!profileDataModel.savedPosts.contains(postDataObject.key)) {
    setState(() {
      profileDataModel.savedPosts =
          "${profileDataModel.savedPosts}${postDataObject.key}//";
    });
    collectionUserReference
        .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
        .get()
        .then((value) {
          String savedPosts = value.docs[0].get('savedPosts');

          savedPosts = "$savedPosts${postDataObject.key}//";

          value.docs[0].reference.update({'savedPosts': savedPosts});
        });
  } else {
    setState(() {
      profileDataModel.savedPosts = profileDataModel.savedPosts.replaceAll(
        "${postDataObject.key}//",
        "",
      );
    });
    collectionUserReference
        .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
        .get()
        .then((value) {
          String savedPosts = value.docs[0].get('savedPosts');

          savedPosts = savedPosts.replaceAll("${postDataObject.key}//", "");

          value.docs[0].reference.update({'savedPosts': savedPosts});
        });
  }
}

void setOrRemoveWatchLater(
  PostModel postDataObject,
  ProfileModel profileDataModel,
  collectionUserReference,
  setState,
) {
  if (!profileDataModel.watchLater.contains(postDataObject.key)) {
    setState(() {
      profileDataModel.watchLater =
          "${profileDataModel.watchLater}${postDataObject.key}//";
    });
    collectionUserReference
        .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
        .get()
        .then((value) {
          String watchLater = value.docs[0].get('watchLater');

          watchLater = "$watchLater${postDataObject.key}//";

          value.docs[0].reference.update({'watchLater': watchLater});

          flutterShowToast("Added to Watch Later");
        });
  } else {
    setState(() {
      profileDataModel.watchLater = profileDataModel.watchLater.replaceAll(
        "${postDataObject.key}//",
        "",
      );
    });
    collectionUserReference
        .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
        .get()
        .then((value) {
          String watchLater = value.docs[0].get('watchLater');

          watchLater = watchLater.replaceAll("${postDataObject.key}//", "");

          value.docs[0].reference.update({'watchLater': watchLater});
        });

    flutterShowToast("Removed from Watch Later");
  }
}

void setBlock(
  blockMobileNumber,
  ProfileModel profileDataModel,
  collectionUserReference,
  setState,
) {
  setState(() {
    profileDataModel.block = "${profileDataModel.block}$blockMobileNumber//";
  });
  collectionUserReference
      .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
      .get()
      .then((value) {
        String block = value.docs[0].get('block');

        block = "$block$blockMobileNumber//";

        value.docs[0].reference.update({'block': block});

        flutterShowToast("User Blocked");
      });
}

void removeBlock(
  blockMobileNumber,
  ProfileModel profileDataModel,
  collectionUserReference,
  setState,
) {
  setState(() {
    profileDataModel.block = profileDataModel.block.replaceAll(
      "$blockMobileNumber//",
      "",
    );
  });
  collectionUserReference
      .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
      .get()
      .then((value) {
        String block = value.docs[0].get('block');

        block = block.replaceAll("$blockMobileNumber//", "");

        value.docs[0].reference.update({'block': block});
      });

  flutterShowToast("User Removed from Blocked");
}

Future<void> deletePost(
  PostModel postDataObject,
  CollectionReference collectionPostReference,
  BuildContext context, // Add context parameter
) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    // Query the post to be deleted
    final querySnapshot =
        await collectionPostReference
            .where('key', isEqualTo: postDataObject.key)
            .limit(1)
            .get();

    // Remove loading indicator
    Navigator.of(context).pop();

    if (querySnapshot.docs.isEmpty) {
      flutterShowToast("Post not found");
      return;
    }

    // Delete the post document
    await querySnapshot.docs.first.reference.delete();
    flutterShowToast("Post Deleted Successfully");

    // Close the post view screen after deletion
    Navigator.of(context).pop();
  } catch (e) {
    debugPrint('Error deleting post: $e');
    flutterShowToast("Failed to delete post: ${e.toString()}");
  }
}

void followOrRemoveMentor(
  PostModel postDataObject,
  ProfileModel profileDataModel,
  collectionUserReference,
  setState,
) {
  if (!profileDataModel.followMentors.contains(postDataObject.mobileNumber)) {
    setState(() {
      profileDataModel.followMentors =
          "${profileDataModel.followMentors}${postDataObject.mobileNumber}//";
    });

    collectionUserReference
        .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
        .get()
        .then((value) {
          String followMentors = value.docs[0].get('followMentors');

          followMentors = "$followMentors${postDataObject.mobileNumber}//";

          value.docs[0].reference.update({'followMentors': followMentors});
        });

    FirebaseDatabase.instance
        .ref()
        .child('Users/')
        .child('${postDataObject.mobileNumber}/Notifications/')
        .push()
        .set({
          "type": "followMentor",
          "mobileNumber": profileDataModel.mobileNumber,
          "time": DateTime.now().toString(),
          "profilePicture": profileDataModel.profilePicture,
          "username": profileDataModel.username,
        });
  } else {
    setState(() {
      profileDataModel.followMentors = profileDataModel.followMentors
          .replaceAll("${postDataObject.mobileNumber}//", "");
    });
    collectionUserReference
        .where('mobileNumber', isEqualTo: profileDataModel.mobileNumber)
        .get()
        .then((value) {
          String followMentors = value.docs[0].get('followMentors');

          followMentors = followMentors.replaceAll(
            "${postDataObject.mobileNumber}//",
            "",
          );

          value.docs[0].reference.update({'followMentors': followMentors});
        });
  }
}
