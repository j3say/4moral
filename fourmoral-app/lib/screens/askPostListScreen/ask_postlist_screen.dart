import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import '../../constants/colors.dart';
import '../mentorAskScreen/mentor_ask_screen.dart';
import 'ask_postlist_services.dart';

class AskPostListScreen extends StatefulWidget {
  const AskPostListScreen({super.key});

  @override
  State<AskPostListScreen> createState() => _AskPostListScreenState();
}

class _AskPostListScreenState extends State<AskPostListScreen> {
  final askPostListCnt = Get.put(AskPostListCnt());

  @override
  void initState() {
    super.initState();
    askPostListCnt.refMentorAsk = FirebaseDatabase.instance
        .ref()
        .child('Ask/')
        .child(profileDataModel!.mobileNumber);
    askPostListCnt.getAskData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Obx(
      () => Scaffold(
        backgroundColor: white,
        resizeToAvoidBottomInset: false,
        body:
            askPostListCnt.askPostListDataFetched.value
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
                            askPostListCnt.askPostListDataList.isEmpty
                                ? Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    "No Posts",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: black,
                                      fontSize: 18,
                                    ),
                                  ),
                                )
                                : Container(),
                            ListView.builder(
                              itemCount:
                                  askPostListCnt.askPostListDataList.length,
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
                                            (context) => MentorAskScreen(
                                              postObject:
                                                  askPostListCnt.postObject!,
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
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                                        CrossAxisAlignment
                                                            .start,
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
                                                                askPostListCnt
                                                                    .askPostListDataList[index]
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
                                                              askPostListCnt
                                                                  .askPostListDataList[index]
                                                                  .caption,
                                                              style: TextStyle(
                                                                color: black,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            Text(
                                                              Jiffy.parse(
                                                                askPostListCnt
                                                                    .askPostListDataList[index]
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
      ),
    );
  }
}
