import 'dart:async';
import 'dart:developer';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:get/get.dart';

class ExploreCnt extends GetxController {
  final CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');
  final searchController = TextEditingController();
  final RxList<PostModel> explorePostDataList = <PostModel>[].obs;
  final RxList<PostModel> filteredPostDataList = <PostModel>[].obs;
  final RxBool explorePageDataFetched = false.obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString hashtagFilter = ''.obs;
  final RxString errorMessage = ''.obs;
  StreamSubscription<QuerySnapshot>? _postStreamSubscription;
  Timer? _debounce;

  ProfileModel?
  profileDataModel; // Injected or fetched profile (assumed global)

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_onSearchChanged);
    getExplorePageData();
  }

  @override
  void onClose() {
    _postStreamSubscription?.cancel();
    _debounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.onClose();
  }

  void syncSearchQuery(String query) {
    searchQuery.value = query;
    searchController.text = query;
    _filterPostsDebounced(query);
  }

  void _onSearchChanged() {
    searchQuery.value = searchController.text;
    _filterPostsDebounced(searchQuery.value);
  }

  void setHashtagFilter(String hashtag) {
    if (hashtag.isNotEmpty) {
      hashtagFilter.value = hashtag.startsWith('#') ? hashtag : '#$hashtag';
      filterPostsByHashtag();
      debugPrint("Hashtag filter set: ${hashtagFilter.value}");
    }
  }

  void clearHashtagFilter() {
    hashtagFilter.value = '';
    filteredPostDataList.assignAll(explorePostDataList);
    debugPrint("Hashtag filter cleared");
  }

  void filterPostsByHashtag() {
    isLoading.value = true;
    errorMessage.value = '';
    if (hashtagFilter.isEmpty) {
      filteredPostDataList.assignAll(explorePostDataList);
    } else {
      filteredPostDataList.assignAll(
        explorePostDataList.where((post) {
          return (post.caption ?? '').toLowerCase().contains(
            hashtagFilter.value.toLowerCase(),
          );
        }).toList(),
      );
    }
    isLoading.value = false;
  }

  void _filterPostsDebounced(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      filterPosts(query);
    });
  }

  void filterPosts(String query) {
    isLoading.value = true;
    errorMessage.value = '';
    if (query.isEmpty && hashtagFilter.isEmpty) {
      filteredPostDataList.assignAll(explorePostDataList);
    } else if (hashtagFilter.isNotEmpty) {
      filterPostsByHashtag();
      if (query.isNotEmpty) {
        filteredPostDataList.assignAll(
          filteredPostDataList.where((post) {
            final usernameMatch = (post.username ?? '').toLowerCase().contains(
              query.toLowerCase(),
            );
            final captionMatch = (post.caption ?? '').toLowerCase().contains(
              query.toLowerCase(),
            );
            return usernameMatch || captionMatch;
          }).toList(),
        );
      }
    } else {
      filteredPostDataList.assignAll(
        explorePostDataList.where((post) {
          final usernameMatch = (post.username ?? '').toLowerCase().contains(
            query.toLowerCase(),
          );
          final captionMatch = (post.caption ?? '').toLowerCase().contains(
            query.toLowerCase(),
          );
          return usernameMatch || captionMatch;
        }).toList(),
      );
    }
    isLoading.value = false;
    debugPrint("Filtered posts by query: ${filteredPostDataList.length} posts");
  }

  Future<void> pullRefresh() async {
    isLoading.value = true;
    errorMessage.value = '';
    explorePageDataFetched.value = false;
    explorePostDataList.clear();
    filteredPostDataList.clear();
    await getExplorePageData();
    if (hashtagFilter.isNotEmpty) {
      filterPostsByHashtag();
    }
    debugPrint("Pull refresh completed");
  }

  Future<void> getExplorePageData() async {
    if (explorePageDataFetched.value || _postStreamSubscription != null) {
      return; // Prevent duplicate listeners
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      log("Starting explore data fetch");
      _postStreamSubscription = collectionPostReference
          .orderBy('dateTime', descending: true)
          .limit(20)
          .snapshots()
          .listen(
            (snapshots) async {
              final List<PostModel> newPosts = [];

              for (var element in snapshots.docs) {
                try {
                  final mobileNumber =
                      element.get('mobileNumber')?.toString() ?? '';
                  final documentId = element.id;

                  // Skip if user has blocked this account
                  if (profileDataModel?.block.contains(mobileNumber) == true) {
                    continue;
                  }

                  // Check accountType in post data
                  final accountType = element.get('actype')?.toString() ?? '';
                  final isValidAccountType = [
                    'Ngo',
                    'Holy peaces',
                    'Mentor',
                  ].contains(accountType);

                  if (!isValidAccountType) {
                    continue;
                  }

                  final post = _createPostModel(element, documentId);
                  newPosts.add(post);
                } catch (e) {
                  log("Error processing post: $e");
                }
              }

              explorePostDataList.assignAll(newPosts);
              filteredPostDataList.assignAll(newPosts);
              explorePageDataFetched.value = true;
              isLoading.value = false;
            },
            onError: (e) {
              errorMessage.value = 'Failed to load posts: $e';
              explorePageDataFetched.value = true;
              isLoading.value = false;
              log("Stream error: $e");
            },
          );
    } catch (e) {
      errorMessage.value = 'Failed to load posts: $e';
      explorePageDataFetched.value = true;
      isLoading.value = false;
      log("Error in getExplorePageData: $e");
    }
  }

  PostModel _createPostModel(DocumentSnapshot element, String documentId) {
    final data = element.data() as Map<String, dynamic>? ?? {};
    return PostModel(
      key: documentId,
      caption: data['caption']?.toString() ?? '',
      dateTime: data['dateTime'],
      mobileNumber: data['mobileNumber']?.toString() ?? '',
      profilePicture: data['profilePicture']?.toString() ?? '',
      thumbnail: List<String>.from(data['thumbnails'] ?? []),
      type: data['type']?.toString() ?? '',
      actype: data['actype']?.toString() ?? '',
      urls: List<String>.from(data['urls'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
      username: data['username']?.toString() ?? '',
      numberOfLikes: data['numberOfLikes'] ?? 0,
      likesUsers: data['likesUsers']?.toString() ?? '',
      postCategory: data['postCategory']?.toString() ?? '',
      hasLocation: data['hasLocation'] as bool? ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}
