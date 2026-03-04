import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart'
;import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/postStoryProductUpload/add_post_story_product_screen.dart';
import 'package:fourmoral/screens/product/shop_page.dart';
import 'package:fourmoral/screens/videoAndVoiceCall/call_manager.dart';
import 'package:get/get.dart';

import '../../constants/colors.dart';
import '../explorePageScreen/explore_page_screen.dart';
import '../homePageScreen/home_page_screen.dart';

class NavigationBarCustom extends StatefulWidget {
  const NavigationBarCustom({super.key, this.userPhoneNumber, this.indexSent});
  final String? userPhoneNumber;
  final int? indexSent;
  @override
  _NavigationBarCustomState createState() => _NavigationBarCustomState();
}

class _NavigationBarCustomState extends State<NavigationBarCustom>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  List<Widget>? _dynamicPageList;
  int _index = 0;

  final CallManager _callManager = CallManager();

  final iconList = [
    {"assetName": 'assets/home.png'},
    {"assetName": 'assets/explore.png'},
  ];

  @override
  void initState() {
    super.initState();
    // ZegoUIKitPrebuiltCallInvitationService().init(
    //   appID: 1957560413,
    //   appSign:
    //       "c82453a02ba65ed5df2b0c564ed9cf585254a2d98622f0db9c3a37798b32936a",
    //   userID: currentUser.id,
    //   userName: currentUser.name,
    //   plugins: [ZegoUIKitSignalingPlugin()],
    //   invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
    //     onOutgoingCallAccepted: (String callID, ZegoCallUser acceptor) {
    //       log('Outgoing call accepted by: ${acceptor.id}');
    //       _callManager.startWalletTimerIfNeeded(context, 10.0, acceptor.id);
    //     },
    //   ),
    //   events: ZegoUIKitPrebuiltCallEvents(
    //     onCallEnd: (event, defaultAction) {
    //       // Handle call end
    //       log('Call ended: ${event.callID}');
    //       defaultAction();
    //       _callManager.endCall(context);
    //     },
    //   ),
    //   notificationConfig: ZegoCallInvitationNotificationConfig(
    //     androidNotificationConfig: ZegoCallAndroidNotificationConfig(
    //       channelID: "Callinvitation",
    //       channelName: "Call Notifications",
    //       sound: "zego_incoming",
    //       showFullScreen: true,
    //       callIDVisibility: true,

    //       certificateIndex:
    //           ZegoSignalingPluginMultiCertificate.firstCertificate,
    //       fullScreenBackgroundAssetURL: 'assets/image/call.png',
    //       callChannel: ZegoCallAndroidNotificationChannelConfig(
    //         channelID: "Callinvitation",
    //         channelName: "Call Notifications",
    //         sound: "zego_incoming",
    //         icon: "call",
    //       ),
    //       missedCallChannel: ZegoCallAndroidNotificationChannelConfig(
    //         channelID: "MissedCall",
    //         channelName: "Missed Call",
    //         sound: "missed_call",
    //         icon: "missed_call",
    //         vibrate: false,
    //       ),
    //     ),
    //     iOSNotificationConfig: ZegoCallIOSNotificationConfig(
    //       systemCallingIconName: 'CallKitIcon',
    //     ),
    //   ),

    //   requireConfig: (ZegoCallInvitationData data) {
    //     final config =
    //         (data.invitees.length > 1)
    //             ? ZegoCallInvitationType.videoCall == data.type
    //                 ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
    //                 : ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
    //             : ZegoCallInvitationType.videoCall == data.type
    //             ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
    //             : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    //     config.avatarBuilder = customAvatarBuilder;
    //     config.topMenuBar.isVisible = true;
    //     // config.screenSharing.defaultFullScreen = true;
    //     config.topMenuBar.buttons = [
    //       ZegoCallMenuBarButtonName.minimizingButton,
    //       ZegoCallMenuBarButtonName.showMemberListButton,
    //       ZegoCallMenuBarButtonName.soundEffectButton,
    //       ZegoCallMenuBarButtonName.toggleScreenSharingButton,
    //     ];
    //     // ⚡️ Add onCallEnd callback to the config

    //     return config;
    //   },
    // );

    if (widget.indexSent != null) {
      _index = widget.indexSent ?? 0;
    }
    _dynamicPageList = [
      HomePageScreen(userPhoneNumber: widget.userPhoneNumber),
      ExplorePageScreen(userPhoneNumber: widget.userPhoneNumber),
      ShopPage(),
    ];
  }

  _onNavBarTapped(index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      // extendBody: true,
      body: _dynamicPageList?[_index],
      floatingActionButton: Container(
        width: 75, // Adjust size to accommodate the border
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 0), // 3px white border
        ),
        child: FloatingActionButton(
          shape: CircleBorder(),
          onPressed: () {
            if (_index == 1) {
              setState(() {
                _index = 2;
              });
            } else {
              Get.to(() => AddPostStoryProductScreen(profileModel: profileDataModel));

              // showModalBottomSheet<void>(
              //   context: context,
              //   isDismissible: true,
              //   builder: (BuildContext context) {
              //     return SizedBox(
              //       height:
              //           height *
              //           (profileDataModel?.type == "Business" ? 0.2 : 0.15),
              //       child: Column(
              //         crossAxisAlignment: CrossAxisAlignment.start,
              //         children: [
              //           postScreen.sheetOptions(
              //             "Create Post",
              //             false,
              //             () {
              //               Navigator.push(
              //                 context,
              //                 MaterialPageRoute(
              //                   builder:
              //                       (context) => postScreen.PostScreen(
              //                         profileModel: profileDataModel,
              //                       ),
              //                 ),
              //               );
              //             },
              //             Icons.photo,
              //             height,
              //           ),
              //           postScreen.sheetOptions(
              //             "Post Story",
              //             false,
              //             () {
              //               Navigator.push(
              //                 context,
              //                 MaterialPageRoute(
              //                   builder:
              //                       (context) => StoryCreatePage(
              //                         profileModel: profileDataModel!,
              //                       ),
              //                 ),
              //               );
              //             },
              //             Icons.photo_camera_back,
              //             height,
              //           ),
              //           if (profileDataModel?.type == "Business")
              //             postScreen.sheetOptions(
              //               "Create product",
              //               false,
              //               () {
              //                 Navigator.push(
              //                   context,
              //                   MaterialPageRoute(
              //                     builder:
              //                         (context) =>
              //                             ProductEditPage(userId: user!.uid),
              //                   ),
              //                 );
              //               },
              //               Icons.add_box,
              //               height,
              //             ),
              //         ],
              //       ),
              //     );
              //   },
              // );
            }
          }, // Increase icon size
          backgroundColor: blue,
          child: Icon(
            _index == 1 ? Icons.storefront_outlined : Icons.camera_alt,
            color: black,
            size: 36,
          ), // Customize the color
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: iconList.length,
        tabBuilder: (int index, bool isActive) {
          final color = isActive ? black : black;
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: Image.asset(
                    iconList[index]['assetName'] ?? '',
                    color: color,
                  ),
                ),
              ),

              // Expanded(
              //   child: SizedBox(
              //     height: 28,
              //     child: Text(
              //       iconList[index]['name'] ?? '',
              //       style: TextStyle(color: color),
              //     ),
              //   ),
              // ),
            ],
          );
        },
        backgroundColor: Colors.grey[200],
        height: 70,
        activeIndex: _index,
        splashColor: Colors.transparent,
        splashRadius: 0,
        splashSpeedInMilliseconds: 0,
        notchSmoothness: NotchSmoothness.defaultEdge,
        gapLocation: GapLocation.none,
        leftCornerRadius: 10,
        rightCornerRadius: 10,
        onTap: _onNavBarTapped,
      ),
    );
  }
}
