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

class WatchLaterScreen extends StatefulWidget {
  const WatchLaterScreen({super.key, this.profileModel});

  final ProfileModel? profileModel;

  @override
  _WatchLaterScreenState createState() => _WatchLaterScreenState();
}

class _WatchLaterScreenState extends State<WatchLaterScreen> {
  CollectionReference collectionPostReference = FirebaseFirestore.instance
      .collection('Posts');

  getWatchLaterProfilePostData() async {
    collectionPostReference.orderBy('dateTime').snapshots().listen((snapshots) {
      userWatchLaterDataPhotoList.clear();
      userWatchLaterDataVideoList.clear();
      for (var element in snapshots.docs) {
        if (widget.profileModel?.watchLater.toString().contains(
              element.get('key').toString(),
            ) ??
            false) {
          if (element.get('type').toString() == "Photo") {
            userWatchLaterDataPhotoList.add(
              userProfilePostPhotoDataServices(element),
            );
          } else {
            userWatchLaterDataVideoList.add(
              userProfilePostVideoDataServices(element),
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          userWatchLaterDataFetched = true;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    getWatchLaterProfilePostData();
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
        appBar: AppBar(title: const Text('Watch Later'), backgroundColor: blue),
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
                        userWatchLaterDataFetched
                            ? Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: height * 0.79,
                                  child:
                                      userWatchLaterDataPhotoList.isNotEmpty
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
                                                userWatchLaterDataPhotoList
                                                    .length,
                                            itemBuilder: (
                                              BuildContext ctx,
                                              int index,
                                            ) {
                                              return PostCard(
                                                image:
                                                    userWatchLaterDataPhotoList[index]
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
                                                                userWatchLaterDataPhotoList[index]
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
                        userWatchLaterDataFetched
                            ? Column(
                              children: [
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: height * 0.79,
                                  child:
                                      userWatchLaterDataVideoList.isNotEmpty
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
                                                userWatchLaterDataVideoList
                                                    .length,
                                            itemBuilder: (
                                              BuildContext ctx,
                                              int index,
                                            ) {
                                              return PostCard(
                                                image:
                                                    userWatchLaterDataVideoList[index]
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
                                                                userWatchLaterDataVideoList[index]
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
