// Flutter imports:
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/navigationBar/navigation_bar.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';

class PageRouteNames {
  static const String login = '/navigationBar';
  static const String home = '/message';
}

const TextStyle textStyle = TextStyle(
  color: Colors.black,
  fontSize: 13.0,
  decoration: TextDecoration.none,
);

Map<String, WidgetBuilder> routes = {
  PageRouteNames.login:
      (context) => NavigationBarCustom(
        userPhoneNumber: AppPreference().getString(
          PreferencesKey.userPhoneNumber,
        ),
      ),
  // PageRouteNames.home:
  //     (context) => const ZegoUIKitPrebuiltCallMiniPopScope(child: Message()),
};

class UserInfo {
  String id = '';
  String name = '';

  UserInfo({required this.id, required this.name});

  bool get isEmpty => id.isEmpty;

  UserInfo.empty();

  get phone => null;
}

UserInfo currentUser = UserInfo.empty();
const String cacheUserIDKey = 'cache_user_id_key';
