import 'package:flutter/material.dart';

List<BoxShadow> boxShadowCustom() {
  return const [
    BoxShadow(
      color: Colors.grey,
      blurRadius: 20.0,
    ),
  ];
}

List<BoxShadow> boxShadowCustomProfileWidget() {
  return [
    BoxShadow(
      color: Colors.grey.withOpacity(0.4),
      blurRadius: 50.0,
    ),
  ];
}
