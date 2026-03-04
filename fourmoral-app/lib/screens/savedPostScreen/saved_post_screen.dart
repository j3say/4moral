// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/profileScreen/profile_screen_services.dart';
import 'package:fourmoral/screens/profileScreen/profile_widgets.dart';
import '../../constants/colors.dart';
import '../../models/user_profile_post_model.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../postViewScreen/post_view_screen.dart';

class SavedPostScreen extends StatefulWidget {
  const SavedPostScreen({super.key, this.profileModel});

  final ProfileModel? profileModel;
  @override
  _SavedPostScreenState createState() => _SavedPostScreenState();
}

class _SavedPostScreenState extends State<SavedPostScreen> {
  _SavedPostScreenState();

  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');

  getSavedProfilePostData() async {
    collectionPostReference.orderBy('dateTime').snapshots().listen((snapshots) {
      userSavedPostDataPhotoList.clear();
      userSavedPostDataVideoList.clear();
      for (var element in snapshots.docs) {
        if (widget.profileModel?.savedPosts.toString().contains(
              element.get('key').toString(),
            ) ??
            false) {
          if (element.get('type').toString() == "Photo") {
            userSavedPostDataPhotoList.add(
              userProfilePostPhotoDataServices(element),
            );
          } else {
            userSavedPostDataVideoList.add(
              userProfilePostVideoDataServices(element),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          userSavedPostDataFetched = true;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    getSavedProfilePostData();
  }

  @override
  // ignore: must_call_super
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text('Saved Post'), backgroundColor: blue),
        body: SizedBox(
          height: height,
          width: width,
          child: Column(
            children: [
              Column(
                children: [
                  SizedBox(
                    // height: size.height * 0.08,
                    child: TabBar(
                      labelStyle: TextStyle(
                        color: black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      labelColor: black,
                      unselectedLabelColor: vreyDarkGrayishBlue,
                      tabs: const [Tab(text: "Photos"), Tab(text: "Videos")],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: height * 0.81,
                    child: TabBarView(
                      children: [
                        userSavedPostDataFetched
                            ? Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: height * 0.79,
                                  child:
                                      userSavedPostDataPhotoList.isNotEmpty
                                          ? GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.all(4),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 5,
                                                  mainAxisSpacing: 5,
                                                ),
                                            itemCount:
                                                userSavedPostDataPhotoList
                                                    .length,
                                            itemBuilder: (
                                              BuildContext ctx,
                                              int index,
                                            ) {
                                              return PostCard(
                                                image:
                                                    userSavedPostDataPhotoList[index]
                                                        .thumbnail,
                                                press: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                            context,
                                                          ) => PostViewScreen(
                                                            postId:
                                                                userSavedPostDataPhotoList[index]
                                                                    .key,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          )
                                          : const Center(
                                            child: Text("No Photos Saved"),
                                          ),
                                ),
                              ],
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [buildCPIWidget(height * 0.5, width)],
                            ),
                        userSavedPostDataFetched
                            ? Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: height * 0.79,
                                  child:
                                      userSavedPostDataVideoList.isNotEmpty
                                          ? GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.all(4),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 5,
                                                  mainAxisSpacing: 5,
                                                ),
                                            itemCount:
                                                userSavedPostDataVideoList
                                                    .length,
                                            itemBuilder: (
                                              BuildContext ctx,
                                              int index,
                                            ) {
                                              return PostCard(
                                                image:
                                                    userSavedPostDataVideoList[index]
                                                        .thumbnail,
                                                press: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                            context,
                                                          ) => PostViewScreen(
                                                            postId:
                                                                userSavedPostDataVideoList[index]
                                                                    .key,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          )
                                          : const Center(
                                            child: Text("No Videos Saved"),
                                          ),
                                ),
                              ],
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [buildCPIWidget(height * 0.5, width)],
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
