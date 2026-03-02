import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:fourmoral/widgets/post_view_widget.dart';

import '../../constants/colors.dart';
import '../../models/post_model.dart';
import '../../models/user_profile_model.dart';
import '../homePageScreen/home_page_screen_services.dart';

class PostViewScreen extends StatefulWidget {
  const PostViewScreen({super.key, this.postId});

  final String? postId;

  @override
  // ignore: library_private_types_in_public_api
  _PostViewScreenState createState() => _PostViewScreenState();
}

class _PostViewScreenState extends State<PostViewScreen> {
  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');

  bool postDataFetched = false;

  PostModel? postDataObject;

  sample() async {
    collectionPostReference
        .orderBy('dateTime')
        .where('key', isEqualTo: widget.postId)
        .snapshots()
        .listen((snapshots) {
          if (snapshots.docs.isNotEmpty) {
            // Add this check
            postDataObject = postDataServices(snapshots.docs[0], "");

            if (mounted) {
              setState(() {
                postDataFetched = true;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                postDataFetched =
                    true; // Still set to true but postDataObject remains null
              });
            }
            flutterShowToast("Post not found");
            Navigator.of(context).pop(); // Close the screen if post not found
          }
        });
  }

  @override
  void initState() {
    super.initState();
    sample();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    String postUsername = postDataObject?.username ?? "";
    String currentUsername = profileDataModel?.username ?? "";

    bool isCurrentUser = postUsername == currentUsername;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Post"), backgroundColor: blue),
      body: SizedBox(
        height: height,
        width: width,
        child:
            postDataFetched
                ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: PostViewWidget(
                          postDataObject:
                              postDataObject ??
                              PostModel(
                                thumbnail: [],
                                urls: [],
                                mediaTypes: [],
                              ),
                          isCurrentUser: isCurrentUser,
                        ),
                      ),
                    ],
                  ),
                )
                : buildCPIWidget(height, width),
      ),
    );
  }
}
