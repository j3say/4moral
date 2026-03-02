import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:get/get.dart';
import 'package:story_view/controller/story_controller.dart';
import 'package:story_view/widgets/story_view.dart';

import '../../constants/colors.dart';
import '../../models/story_model.dart';
import '../storyScreen/story_screen.dart';

class MoreStoriesScreen extends StatefulWidget {
  const MoreStoriesScreen({super.key, this.storiesList});
  final List<HomePageStoryModel>? storiesList;

  @override
  _MoreStoriesScreenState createState() => _MoreStoriesScreenState();
}

class _MoreStoriesScreenState extends State<MoreStoriesScreen> {
  final profileCnt = Get.put(ProfileController());
  final StoryController controller = StoryController();
  final PageController _pageController = PageController(viewportFraction: 0.8);

  @override
  void dispose() {
    _pageController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('More Stories'), backgroundColor: blue),
      body: SizedBox(
        height: height,
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount:
                      ((widget.storiesList?.length ?? 0) / 3)
                          .ceil(), // Show 3 stories per page
                  itemBuilder: (context, pageIndex) {
                    // Calculate the start and end index for the current page
                    int startIndex = pageIndex * 3;
                    int endIndex = startIndex + 3;
                    if (endIndex > widget.storiesList!.length) {
                      endIndex = widget.storiesList!.length;
                    }

                    // Get the stories for the current page
                    var storiesForPage = widget.storiesList?.sublist(
                      startIndex,
                      endIndex,
                    );

                    return Row(
                      children:
                          storiesForPage!.map((story) {
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  var mobileNumberKey =
                                      story.mobileNumber.toString();
                                  var storyNumberdata =
                                      valuesStory?[mobileNumberKey];

                                  print(
                                    "Fetching Story Data for: $mobileNumberKey",
                                  );
                                  print(
                                    "Retrieved Story Data: $storyNumberdata",
                                  );

                                  if (storyNumberdata != null &&
                                      storyNumberdata is Map) {
                                    List<StoryItem> storyShowList = [];

                                    // Access the nested "data" map
                                    var storyDataMap = storyNumberdata['data'];
                                    if (storyDataMap != null &&
                                        storyDataMap is Map) {
                                      storyDataMap.forEach((
                                        keyStory,
                                        valueStory,
                                      ) {
                                        if (valueStory is Map) {
                                          print("Processing Story: $keyStory");
                                          print("Story Data: $valueStory");

                                          if (valueStory['type'] == "Photo") {
                                            storyShowList.add(
                                              StoryItem.pageImage(
                                                caption:
                                                    valueStory['caption'] !=
                                                                null &&
                                                            valueStory['caption']
                                                                .isNotEmpty
                                                        ? Text(
                                                          valueStory['caption'],
                                                        ) // Wrap caption in a Text widget
                                                        : null, // Pass null if caption is empty
                                                url: valueStory['url'],
                                                controller: controller,
                                              ),
                                            );
                                          } else if (valueStory['type'] ==
                                              "Video") {
                                            storyShowList.add(
                                              StoryItem.pageVideo(
                                                valueStory['url'],
                                                caption:
                                                    valueStory['caption'] !=
                                                                null &&
                                                            valueStory['caption']
                                                                .isNotEmpty
                                                        ? Text(
                                                          valueStory['caption'],
                                                        ) // Wrap caption in a Text widget
                                                        : null, // Pass null if caption is empty
                                                controller: controller,
                                              ),
                                            );
                                          }
                                        }
                                      });
                                    }

                                    storyShowList =
                                        storyShowList.reversed.toList();

                                    // Debug: Print the storyShowList before navigation
                                    print("Story Show List: $storyShowList");

                                    if (storyShowList.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => StoryPageView(
                                                controller: controller,
                                                storyShowList: storyShowList,
                                              ),
                                        ),
                                      );
                                    } else {
                                      print(
                                        "No stories found for: $mobileNumberKey",
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text("No stories available"),
                                        ),
                                      );
                                    }
                                  } else {
                                    print(
                                      "No story data found for: $mobileNumberKey",
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("No story data found"),
                                      ),
                                    );
                                  }
                                },
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: height * 0.035,
                                      backgroundColor: Colors.white,
                                      backgroundImage: NetworkImage(
                                        story.profilePicture ?? "",
                                      ),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: AutoSizeText(
                                        story.username ?? '',
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: black,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
