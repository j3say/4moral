import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:get/get.dart';
import '../../constants/colors.dart';

final profileCnt = Get.put(ProfileController());

CircleAvatar profileImageWidget(height, width, profilePicture) {
  return CircleAvatar(
    radius: height * 0.03,
    backgroundColor: white,
    child: ClipOval(
      child: FadeInImage.assetNetwork(
        imageErrorBuilder:
            (i, j, k) =>
                const Image(image: AssetImage("assets/profilePlaceHolder.png")),
        placeholder: "assets/profilePlaceHolder.png",
        image: "$profilePicture",
        fit: BoxFit.cover,
      ),
    ),
  );
}

Widget storyImageWidget(height, width, picture, username) {
  return Column(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage("$picture"),
      ),
      SizedBox(
        width: 40,
        child: AutoSizeText(
          username,
          maxLines: 1,
          style: TextStyle(color: white, fontSize: 10),
        ),
      ),
    ],
  );
}

GestureDetector iconButton(
  BuildContext context,
  double width,
  VoidCallback onTap,
  Widget icon,
  double size,
  GlobalKey? key,
) {
  return GestureDetector(
    key: key,
    onTap: onTap,
    child: SizedBox(
      width: width * size,
      height: width * size,
      child: icon, // Accepts any widget (Icon or Image)
    ),
  );
}

class ButtonPosts extends StatelessWidget {
  const ButtonPosts({super.key, required this.width, required this.img});

  final double width;
  final String img;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      width: width * 0.08,
      height: width * 0.08,
      child: Image.asset(img),
    );
  }
}
