import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/chatScreen/chat_screen.dart';
import 'package:fourmoral/screens/homePageScreen/home_controller.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/screens/mapScreen/map_screen_2.dart';
import 'package:fourmoral/screens/notificationScreen/notification_screen.dart';
import 'package:fourmoral/screens/profileScreen/profile_screen.dart';
import 'package:fourmoral/screens/searchScreen/search_screen.dart';
import 'package:fourmoral/screens/story/story2_controller.dart';
import 'package:fourmoral/screens/story/story_view_page.dart';
import 'package:fourmoral/screens/videoAndVoiceCall/constants.dart';
import 'package:fourmoral/widgets/box_decoration_widget.dart';
import 'package:fourmoral/widgets/post_view_widget.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomePageScreen extends StatefulWidget {
  final String? userPhoneNumber;

  const HomePageScreen({super.key, this.userPhoneNumber});

  @override
  // ignore: library_private_types_in_public_api
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen>
    with AutomaticKeepAliveClientMixin {
  final homeCnt = Get.put(HomeCnt());
  final Story2Controller story2Controller = Get.put(Story2Controller());
  final PageController _pageController = PageController(viewportFraction: 0.8);
  Timer? _singleTapTimer;
  TutorialCoachMark? tutorialCoachMark; // Add this variable
  GlobalKey profileKey = GlobalKey(); // Key for profile avatar
  GlobalKey storiesKey = GlobalKey(); // Key for stories section
  GlobalKey chatKey = GlobalKey(); // Key for chat icon
  GlobalKey searchKey = GlobalKey(); // Key for search icon
  GlobalKey mapKey = GlobalKey(); // Key for map icon
  GlobalKey normalKey = GlobalKey();
  // final callController = ZegoUIKitPrebuiltCallController();

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialShown = prefs.getBool('tutorialShown') ?? false;

    if (!tutorialShown && mounted) {
      // Only show tutorial if it hasn't been shown before
      await prefs.setBool('tutorialShown', true);
      _showTutorial();
    }
  }

  @override
  void initState() {
    super.initState();
    init();

    currentUser.id = widget.userPhoneNumber ?? "";
    currentUser.name = profileDataModel?.username.toString() ?? "";

    // Use a delayed execution to ensure widget tree is fully built
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkAndShowTutorial();
      }
    });
  }

  init() async {
    await homeCnt.getProfileData(userPhoneNumber: widget.userPhoneNumber);
    await homeCnt.getPostAndStoryData();
    await homeCnt.getUsersList();
    await story2Controller.initializeAndFetch();
  }

  void _showTutorial() {
    final targets = _createTargets();

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.blue,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Tutorial finished");
      },
      onSkip: () {
        print("Tutorial skipped");
        return true;
      },
    );

    // Ensure widget tree is completely built before showing tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        tutorialCoachMark?.show(context: context);
      }
    });
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "profile",
        keyTarget: profileKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Your Profile",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap once to view your profile, double tap to view your stories",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
      TargetFocus(
        identify: "stories",
        keyTarget: storiesKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Friends' Stories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "View your friends' stories here",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.RRect,
        radius: 10,
      ),
      TargetFocus(
        identify: "chat",
        keyTarget: chatKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Chat",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Message your friends here",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
      TargetFocus(
        identify: "search",
        keyTarget: searchKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Search",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Find people and content",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
      TargetFocus(
        identify: "map",
        keyTarget: mapKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Map",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Explore content on a map",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    story2Controller.onDelete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Obx(
      () => Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: blue,
        body:
            (homeCnt.postDataFetched.value &&
                    homeCnt.profileDataFetched.value &&
                    homeCnt.contactsDataFetched.value)
                ? Container(
                  height: height,
                  width: width,
                  color: white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: height * 0.20,
                        decoration: boxDecorationWidget(),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: height * 0.04),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 05),
                                      child: GestureDetector(
                                        key: profileKey,
                                        onTap: () {
                                          // Delay to check for double tap
                                          _singleTapTimer = Timer(
                                            const Duration(milliseconds: 300),
                                            () {
                                              // Navigate to ProfileScreen on single tap
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => ProfileScreen(
                                                        profileModel:
                                                            profileDataModel,
                                                      ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        onDoubleTap: () {
                                          // Cancel the single tap timer if double tap is detected
                                          if (_singleTapTimer != null &&
                                              _singleTapTimer!.isActive) {
                                            _singleTapTimer!.cancel();
                                          }

                                          // Check if user has stories
                                          final hasStories =
                                              story2Controller
                                                  .myStories
                                                  .isNotEmpty;

                                          if (hasStories) {
                                            // Navigate to StoryView on double tap
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => StoryViewPage(
                                                      userStory:
                                                          story2Controller
                                                              .myStories[0],
                                                      myStory: true,
                                                    ),
                                              ),
                                            );
                                          } else {
                                            // No stories, go to ProfileScreen instead
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => ProfileScreen(
                                                      profileModel:
                                                          profileDataModel,
                                                    ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border:
                                                story2Controller
                                                        .myStories
                                                        .isNotEmpty
                                                    ? Border.all(
                                                      color:
                                                          Colors
                                                              .blue, // Border color when story is available
                                                      width:
                                                          3.0, // Border thickness
                                                    )
                                                    : Border.all(
                                                      color:
                                                          Colors
                                                              .transparent, // No border when no story
                                                      width: 0.0,
                                                    ),
                                          ),
                                          child: CircleAvatar(
                                            radius: height * 0.04,
                                            backgroundColor:
                                                story2Controller
                                                        .myStories
                                                        .isNotEmpty
                                                    ? Colors.blue
                                                    : Colors.white,
                                            child: ClipOval(
                                              child: FadeInImage.assetNetwork(
                                                imageErrorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Image(
                                                      image: AssetImage(
                                                        "assets/profilePlaceHolder.png",
                                                      ),
                                                    ),
                                                placeholder:
                                                    "assets/profilePlaceHolder.png",
                                                image:
                                                    profileDataModel
                                                        ?.profilePicture ??
                                                    "",
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    key: storiesKey,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child:
                                        story2Controller.userStories.isEmpty
                                            ? const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: Text(
                                                  'No stories available',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            : SizedBox(
                                              height: 60,
                                              child: ListView.builder(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    story2Controller
                                                        .userStories
                                                        .length,
                                                itemBuilder: (context, index) {
                                                  final userStory =
                                                      story2Controller
                                                          .userStories[index];
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8.0,
                                                        ),
                                                    child: GestureDetector(
                                                      onTap:
                                                          () => Get.to(
                                                            () => StoryViewPage(
                                                              userStory:
                                                                  userStory,
                                                            ),
                                                          ),
                                                      child: Column(
                                                        children: [
                                                          Container(
                                                            width: 60,
                                                            height: 60,
                                                            decoration: BoxDecoration(
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
                                                              border: Border.all(
                                                                color:
                                                                    userStory
                                                                            .hasUnseenStories
                                                                        ? Colors
                                                                            .blue
                                                                        : Colors
                                                                            .grey,
                                                                width: 2,
                                                              ),
                                                              image: DecorationImage(
                                                                image: NetworkImage(
                                                                  userStory
                                                                      .profilePic,
                                                                ),
                                                                fit:
                                                                    BoxFit
                                                                        .cover,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                  ),
                                ),

                                SizedBox(width: 10),

                                iconButton(
                                  context,
                                  width,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const NotificationScreen(),
                                      ),
                                    );
                                  },
                                  Image.asset(
                                    'assets/bell.png', // Update with your image path
                                    width: 24, // Adjust size as needed
                                    height: 24,
                                  ),
                                  0.09,
                                  normalKey,
                                ),
                                Row(
                                  children: [
                                    const SizedBox(width: 20),
                                    iconButton(
                                      context,
                                      width,
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ChatScreen(
                                                  userMobile:
                                                      widget.userPhoneNumber ??
                                                      'Unknown',
                                                ),
                                          ),
                                        );
                                      },
                                      Image.asset(
                                        'assets/chat.png', // Update with your image path
                                        width: 24, // Adjust size as needed
                                        height: 24,
                                      ),
                                      0.09,
                                      chatKey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: height * 0.005),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (homeCnt.tabInt != 0) {
                                        setState(() {
                                          homeCnt.postDataList.value =
                                              homeCnt.realPostDataList;
                                          homeCnt.tabInt = 0;
                                        });
                                      }
                                    },
                                    child: AutoSizeText(
                                      'Moral 1',
                                      style: TextStyle(
                                        color:
                                            homeCnt.tabInt == 0
                                                ? black
                                                : Colors.black54,
                                        fontSize: 31,
                                        fontFamily: 'Righteous',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (homeCnt.tabInt != 1) {
                                        List<PostModel> temp = [];
                                        for (
                                          var i = 0;
                                          i < homeCnt.realPostDataList.length;
                                          i++
                                        ) {
                                          if (homeCnt
                                                  .realPostDataList[i]
                                                  .postCategory ==
                                              "following") {
                                            temp.add(
                                              homeCnt.realPostDataList[i],
                                            );
                                          }
                                        }
                                        setState(() {
                                          homeCnt.postDataList.value = temp;
                                          homeCnt.tabInt = 1;
                                        });
                                      }
                                    },
                                    child: AutoSizeText(
                                      'Following',
                                      maxFontSize: 15,
                                      minFontSize: 15,
                                      style: TextStyle(
                                        color:
                                            homeCnt.tabInt == 1
                                                ? black
                                                : Colors.black54,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (homeCnt.tabInt != 2) {
                                        List<PostModel> temp = [];
                                        for (
                                          var i = 0;
                                          i < homeCnt.realPostDataList.length;
                                          i++
                                        ) {
                                          if (homeCnt
                                                  .realPostDataList[i]
                                                  .postCategory ==
                                              "contacts") {
                                            temp.add(
                                              homeCnt.realPostDataList[i],
                                            );
                                          }
                                        }
                                        setState(() {
                                          homeCnt.postDataList.value = temp;
                                          // postDataList = temp;
                                          homeCnt.tabInt = 2;
                                        });
                                      }
                                    },
                                    child: AutoSizeText(
                                      'Contacts',
                                      maxFontSize: 15,
                                      minFontSize: 15,
                                      style: TextStyle(
                                        color:
                                            homeCnt.tabInt == 2
                                                ? black
                                                : Colors.black54,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      iconButton(
                                        context,
                                        width,
                                        () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const SearchScreen(),
                                            ),
                                          );
                                        },
                                        Image.asset(
                                          'assets/search.png', // Update with your image path
                                          width: 24, // Adjust size as needed
                                          height: 24,
                                        ),
                                        0.08,
                                        searchKey,
                                      ),
                                      const SizedBox(width: 20),
                                      iconButton(
                                        context,
                                        width,
                                        () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => MapScreen3(
                                                    ProfileUrl:
                                                        profileDataModel!
                                                            .profilePicture,
                                                  ),
                                            ),
                                          );
                                        },
                                        Image.asset(
                                          'assets/earth.png',
                                          width: 24,
                                          height: 24,
                                        ),
                                        0.08,
                                        mapKey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child:
                            homeCnt.postDataList.isNotEmpty
                                ? RefreshIndicator(
                                  onRefresh: homeCnt.pullRefresh,
                                  child: ListView.builder(
                                    itemCount: homeCnt.postDataList.length,
                                    physics: const BouncingScrollPhysics(),
                                    shrinkWrap: true,
                                    padding: EdgeInsets.only(
                                      top: 10,
                                      bottom:
                                          MediaQuery.of(
                                            context,
                                          ).viewInsets.bottom +
                                          height * 0.09,
                                    ),
                                    itemBuilder: (context, index) {
                                      PostModel postDataObject =
                                          homeCnt.postDataList[index];
                                      String postUsername =
                                          postDataObject.username;
                                      String currentUsername =
                                          profileDataModel!.username;
                                      bool isCurrentUser =
                                          postUsername == currentUsername;
                                      return PostViewWidget(
                                        postDataObject: postDataObject,
                                        isCurrentUser: isCurrentUser,
                                      );
                                    },
                                  ),
                                )
                                : const Center(
                                  child: Text(
                                    "No Post",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                      ),
                    ],
                  ),
                )
                : Center(child: CircularProgressIndicator()),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
