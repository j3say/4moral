import 'package:flutter/material.dart';

import '../constants/colors.dart';

OutlineInputBorder buildTextFieldOutlineInputBorder(size) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: BorderSide(
      width: 0,
      color: black.withOpacity(0.8),
    ),
  );
}
