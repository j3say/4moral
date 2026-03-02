import 'package:flutter/material.dart';
import 'package:fourmoral/screens/followingScreen/following_screen_services.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:get/get.dart';

import '../../constants/colors.dart';
import '../otherProfileScreen/other_profile_screen.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final exploreCnt = Get.put(FollowingCnt());

  @override
  void initState() {
    super.initState();
    exploreCnt.getFollowingData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Following"), backgroundColor: blue),
      body: Obx(
        () =>
            exploreCnt.followingDataFetched.value
                ? exploreCnt.followingDataList.isEmpty
                    ? Center(
                      child: Text(
                        "No Following",
                        textAlign: TextAlign.start,
                        style: TextStyle(color: black, fontSize: 18),
                      ),
                    )
                    : ListView.builder(
                      itemCount: exploreCnt.followingDataList.length,
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
                                    (context) => OtherProfileScreen(
                                      mobileNumber:
                                          exploreCnt
                                              .followingDataList[index]
                                              .mobileNumber,
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
                                      borderRadius: BorderRadius.circular(20),
                                      color: white.withOpacity(0.6),
                                      boxShadow: boxShadowCustomProfileWidget(),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        profileImageWidget(
                                          height,
                                          width,
                                          exploreCnt
                                              .followingDataList[index]
                                              .profilePicture,
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: width * 0.6,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                exploreCnt
                                                    .followingDataList[index]
                                                    .uniqueId,
                                                style: TextStyle(
                                                  color: black,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                exploreCnt
                                                    .followingDataList[index]
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
                    )
                : buildCPIWidget(height, width),
      ),
    );
  }
}
