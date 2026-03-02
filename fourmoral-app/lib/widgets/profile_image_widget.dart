import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../widgets/box_shadow.dart';

Container profileScreenImageWidget(height, width, profilePicture, size) {
  return Container(
    decoration: BoxDecoration(boxShadow: boxShadowCustomProfileWidget()),
    child: CircleAvatar(
      radius: height * size,
      backgroundColor: white,
      child: ClipOval(
          child: FadeInImage.assetNetwork(
        imageErrorBuilder: (i, j, k) =>
            const Image(image: AssetImage("assets/profilePlaceHolder.png")),
        placeholder: "assets/profilePlaceHolder.png",
        image: "$profilePicture",
        fit: BoxFit.cover,
      )),
    ),
  );
}
