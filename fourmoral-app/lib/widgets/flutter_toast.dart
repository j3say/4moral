import 'package:fluttertoast/fluttertoast.dart';

import '../constants/colors.dart';

flutterShowToast(text) {
  Fluttertoast.showToast(
      msg: "$text",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: white,
      textColor: black,
      fontSize: 16.0);
}
