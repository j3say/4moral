import 'package:flutter/material.dart';
import 'package:fourmoral/screens/groupInformationScreen/group_information_services.dart';
import 'package:get/get.dart';
import '../../constants/colors.dart';
import '../../widgets/box_shadow.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../homePageScreen/home_page_widgets.dart';
import '../otherProfileScreen/other_profile_screen.dart';

class GroupInformationScreen extends StatefulWidget {
  const GroupInformationScreen({super.key, this.information});

  final List? information;

  @override
  // ignore: library_private_types_in_public_api, no_logic_in_create_state
  _GroupInformationScreenState createState() =>
      // ignore: no_logic_in_create_state
      _GroupInformationScreenState();
}

class _GroupInformationScreenState extends State<GroupInformationScreen> {
  final groupInfoCnt = Get.put(GroupInformationCnt());

  @override
  void initState() {
    super.initState();
    groupInfoCnt.getGroupData(widget.information);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Group Information"),
        backgroundColor: blue,
      ),
      body: Obx(
        () =>
            groupInfoCnt.groupInfoFetched.value
                ? SizedBox(
                  height: height,
                  width: width,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                // ignore: prefer_interpolation_to_compose_strings
                                "Admin: " + widget.information?[0],
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: black,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                // ignore: prefer_interpolation_to_compose_strings
                                "Group Name: " + widget.information?[1],
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: black,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: <Widget>[
                            groupInfoCnt.groupInfo.isEmpty
                                ? Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    "No Contacts",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: black,
                                      fontSize: 18,
                                    ),
                                  ),
                                )
                                : Container(),
                            ListView.builder(
                              itemCount: groupInfoCnt.groupInfo.length,
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
                                                  groupInfoCnt
                                                      .groupInfo[index]
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
                                                  groupInfoCnt
                                                      .groupInfo[index]
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
                                                        groupInfoCnt
                                                            .groupInfo[index]
                                                            .username,
                                                        style: TextStyle(
                                                          color: black,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      Text(
                                                        groupInfoCnt
                                                            .groupInfo[index]
                                                            .mobileNumber,
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
                      ],
                    ),
                  ),
                )
                : buildCPIWidget(height, width),
      ),
    );
  }
}
