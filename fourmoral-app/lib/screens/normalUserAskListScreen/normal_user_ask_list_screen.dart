import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:jiffy/jiffy.dart';

import '../../constants/colors.dart';
import '../../models/ask_postlist_model.dart';
import '../../models/post_model.dart';
import '../askPostListScreen/ask_postlist_services.dart';
import '../askScreen/ask_screen.dart';
import '../homePageScreen/home_page_screen_services.dart';

class NormalUserAskPostListScreen extends StatefulWidget {
  const NormalUserAskPostListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _NormalUserAskPostListScreenState createState() =>
      _NormalUserAskPostListScreenState();
}

class _NormalUserAskPostListScreenState
    extends State<NormalUserAskPostListScreen> {
  var normalUserAskPostListDataFetched = true;

  List<AskPostListModel> normalUserAskPostListDataList = [];

  DatabaseReference? refNormalAsk;

  List<PostModel> postObjectList = [];

  getAskData() {
    try {
      setState(() {
        normalUserAskPostListDataFetched = false;
      });

      refNormalAsk?.onValue.listen((event) async {
        normalUserAskPostListDataList.clear();
        Map? values = event.snapshot.value as Map?;
        if (values != null) {
          values.forEach((mentorNumber, mentorPosts) {
            mentorPosts.forEach((postKey, postAsksUsers) {
              postAsksUsers.forEach((askUser, askValues) {
                if (askUser == profileDataModel?.mobileNumber) {
                  FirebaseFirestore.instance
                      .collection('Posts')
                      .where('key', isEqualTo: postKey)
                      .snapshots()
                      .listen((snapshots) {
                        if (snapshots.docs.isNotEmpty) {
                          postObjectList.add(
                            postDataServices(snapshots.docs[0], ""),
                          );
                          normalUserAskPostListDataList.add(
                            askPostListServicesDataServices(
                              postKey,
                              snapshots.docs[0],
                            ),
                          );
                          normalUserAskPostListDataList.sort((a, b) {
                            return DateTime.parse(
                              b.dateTime,
                            ).compareTo(DateTime.parse(a.dateTime));
                          });
                          postObjectList.sort((a, b) {
                            return DateTime.parse(
                              b.dateTime,
                            ).compareTo(DateTime.parse(a.dateTime));
                          });
                          setState(() {
                            normalUserAskPostListDataFetched = true;
                          });
                        } else {
                          setState(() {
                            normalUserAskPostListDataFetched = true;
                          });
                        }
                      });
                } else {
                  setState(() {
                    normalUserAskPostListDataFetched = true;
                  });
                }
              });
            });
          });
        } else {
          setState(() {
            normalUserAskPostListDataFetched = true;
          });
        }
      });
    } catch (e) {
      print("ERROR ${e.toString()}");
      setState(() {
        normalUserAskPostListDataFetched = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    refNormalAsk = FirebaseDatabase.instance.ref().child('Ask/');
    getAskData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      body:
          normalUserAskPostListDataFetched
              ? SizedBox(
                height: height,
                width: width,
                child: Column(
                  children: [
                    SizedBox(
                      height: height * 0.82,
                      // color: black,
                      child: Stack(
                        children: <Widget>[
                          normalUserAskPostListDataList.isEmpty
                              ? Align(
                                alignment: Alignment.center,
                                child: Text(
                                  "No Posts",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(color: black, fontSize: 18),
                                ),
                              )
                              : Container(),
                          ListView.builder(
                            itemCount: normalUserAskPostListDataList.length,
                            physics: const BouncingScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.only(
                              top: 10,
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom +
                                  height * 0.09,
                            ),
                            reverse: true,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => AskScreen(
                                            postObject: postObjectList[index],
                                            phone:
                                                profileDataModel?.mobileNumber,
                                          ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(
                                        left: 14,
                                        right: 14,
                                        top: 10,
                                        bottom: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            color: white.withOpacity(0.6),
                                            boxShadow:
                                                boxShadowCustomProfileWidget(),
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                width: width * 0.8,
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    SizedBox(
                                                      height: width * 0.15,
                                                      width: width * 0.15,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            const BorderRadius.all(
                                                              Radius.circular(
                                                                10,
                                                              ),
                                                            ),
                                                        child: CachedNetworkImage(
                                                          imageUrl:
                                                              normalUserAskPostListDataList[index]
                                                                  .url,
                                                          fit: BoxFit.cover,
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                error,
                                                              ) => const Icon(
                                                                Icons.error,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    SizedBox(
                                                      width: width * 0.6,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            normalUserAskPostListDataList[index]
                                                                .username,
                                                            style: TextStyle(
                                                              color: black,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            normalUserAskPostListDataList[index]
                                                                .caption,
                                                            style: TextStyle(
                                                              color: black,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            Jiffy.parse(
                                                              normalUserAskPostListDataList[index]
                                                                  .dateTime,
                                                            ).fromNow(),
                                                            style: TextStyle(
                                                              color: black,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              : buildCPIWidget(height, width),
    );
  }
}
