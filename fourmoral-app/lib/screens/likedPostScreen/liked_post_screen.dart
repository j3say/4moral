import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/profileScreen/profile_screen_services.dart';
import 'package:fourmoral/screens/profileScreen/profile_widgets.dart';
import '../../constants/colors.dart';
import '../../models/user_profile_post_model.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../postViewScreen/post_view_screen.dart';

class LikedPostScreen extends StatefulWidget {
  const LikedPostScreen({super.key, this.profileModel});

  final ProfileModel? profileModel;
  @override
  // ignore: library_private_types_in_public_api
  _LikedPostScreenState createState() =>
      // ignore: no_logic_in_create_state
      _LikedPostScreenState();
}

class _LikedPostScreenState extends State<LikedPostScreen> {
  _LikedPostScreenState();

  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');

  getLikeProfilePostData() async {
    collectionPostReference.orderBy('dateTime').snapshots().listen((snapshots) {
      userLikePostDataPhotoList.clear();
      userLikePostDataVideoList.clear();
      for (var element in snapshots.docs) {
        if (widget.profileModel!.likePosts.toString().contains(
          element.get('key').toString(),
        )) {
          if (element.get('type').toString() == "Photo") {
            userLikePostDataPhotoList.add(
              userProfilePostPhotoDataServices(element),
            );
          } else {
            userLikePostDataVideoList.add(
              userProfilePostVideoDataServices(element),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          userLikePostDataFetched = true;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    getLikeProfilePostData();
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
        appBar: AppBar(title: const Text('Liked Post'), backgroundColor: blue),
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
                        userLikePostDataFetched
                            ? Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: height * 0.79,
                                  child:
                                      userLikePostDataPhotoList.isNotEmpty
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
                                                userLikePostDataPhotoList
                                                    .length,
                                            itemBuilder: (
                                              BuildContext ctx,
                                              int index,
                                            ) {
                                              return PostCard(
                                                image:
                                                    userLikePostDataPhotoList[index]
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
                                                                userLikePostDataPhotoList[index]
                                                                    .key,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          )
                                          : const Center(
                                            child: Text("No Photos Liked"),
                                          ),
                                ),
                              ],
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [buildCPIWidget(height * 0.5, width)],
                            ),
                        userLikePostDataFetched
                            ? Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: height * 0.79,
                                  child:
                                      userLikePostDataVideoList.isNotEmpty
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
                                                userLikePostDataVideoList
                                                    .length,
                                            itemBuilder: (
                                              BuildContext ctx,
                                              int index,
                                            ) {
                                              return PostCard(
                                                image:
                                                    userLikePostDataVideoList[index]
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
                                                                userLikePostDataVideoList[index]
                                                                    .key,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          )
                                          : const Center(
                                            child: Text("No Videos Liked"),
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
