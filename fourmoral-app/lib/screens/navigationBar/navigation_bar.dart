import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
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
  // 1. REMOVED Firebase user initialization here.
  // If you need the user ID later, fetch it from SharedPreferences.

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
      body: _dynamicPageList?[_index],
      floatingActionButton: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 0),
        ),
        child: FloatingActionButton(
          shape: CircleBorder(),
          onPressed: () {
            if (_index == 1) {
              setState(() {
                _index = 2; // Goes to Shop Page
              });
            } else {
              // Ensure profileDataModel is globally available or fetched beforehand
              Get.to(
                () => AddPostStoryProductScreen(profileModel: profileDataModel),
              );
            }
          },
          backgroundColor: blue,
          child: Icon(
            _index == 1 ? Icons.storefront_outlined : Icons.camera_alt,
            color: black,
            size: 36,
          ),
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
            ],
          );
        },
        backgroundColor: Colors.grey[200],
        height: 70,
        // 2. FIX: Prevent out-of-bounds crash when _index is 2 (ShopPage)
        activeIndex: _index < iconList.length ? _index : 0,
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
