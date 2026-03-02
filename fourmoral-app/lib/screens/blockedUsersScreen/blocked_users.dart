import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/services/set_or_remove_like.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:get/get.dart';

import '../../constants/colors.dart';
import '../../widgets/confirm_dialogue_box.dart';
import 'blocked_users_services.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final blockUserCnt = Get.put(BlockUserCnt());

  @override
  void initState() {
    super.initState();
    blockUserCnt.getBlockUsersData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Blocked Users"), backgroundColor: blue),
      body: Obx(
        () =>
            blockUserCnt.blockedDataFetched.value
                ? SizedBox(
                  height: height,
                  width: width,
                  child: Column(
                    children: [
                      SizedBox(
                        height: height * 0.9 - 12,
                        child: Stack(
                          children: <Widget>[
                            blockUserCnt.blockedDataList.isEmpty
                                ? Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    "No Users Blocked",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: black,
                                      fontSize: 18,
                                    ),
                                  ),
                                )
                                : Container(),
                            ListView.builder(
                              itemCount: blockUserCnt.blockedDataList.length,
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
                                    confirmDialogue(
                                      context,
                                      "Unblock this User",
                                      "Do you really want to go to Unblock this User?",
                                      () async {
                                        removeBlock(
                                          blockUserCnt
                                              .blockedDataList[index]
                                              .mobileNumber,
                                          profileDataModel!,
                                          blockUserCnt.collectionUserReference,
                                          setState,
                                        );
                                        Navigator.pop(context);
                                      },
                                      () {
                                        Navigator.pop(context);
                                      },
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
                                                profileImageWidget(
                                                  height,
                                                  width,
                                                  blockUserCnt
                                                      .blockedDataList[index]
                                                      .profilePicture,
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
                                                        blockUserCnt
                                                            .blockedDataList[index]
                                                            .username,
                                                        style: TextStyle(
                                                          color: black,
                                                          fontSize: 15,
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
