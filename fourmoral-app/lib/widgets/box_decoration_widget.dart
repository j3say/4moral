import 'package:flutter/material.dart';

import '../constants/colors.dart';

BoxDecoration boxDecorationWidget() {
  return BoxDecoration(
    color: blue,
    border: Border(
      bottom: BorderSide(
        color: Colors.black, // Color of the border
        width: 2.0, // Thickness of the border (2px)
      ),
    ),
  );
}
