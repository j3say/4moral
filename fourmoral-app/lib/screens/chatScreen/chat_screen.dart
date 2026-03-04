// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/chatScreen/chat_screen_services.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../constants/colors.dart';
import '../askPostListScreen/ask_postlist_screen.dart';
import '../contactsScreen/contacts_screen.dart';
import '../groupScreen/group_screen.dart';
import '../messageRequestScreen/message_request_screen.dart';
import '../messageScreen/message_screen.dart';
import '../normalUserAskListScreen/normal_user_ask_list_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userMobile;
  const ChatScreen({super.key, required this.userMobile});
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final chatScreenCnt = Get.put(ChatScreenCnt());

  @override
  void initState() {
    super.initState();
    chatScreenCnt.ref = FirebaseDatabase.instance.ref();
    chatScreenCnt.getList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    if (profileDataModel?.type == "Mentor") {
      return DefaultTabController(
        length: 3,
        child: Obx(
          () => Scaffold(
            appBar: AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: blue,
              flexibleSpace: SafeArea(
                child: Container(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back, color: white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              "Conversations",
                              style: TextStyle(
                                fontSize: 18,
                                color: black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ContactsScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [Icon(Icons.contacts, color: white)],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => MessageRequestScreen(
                                    list: chatScreenCnt.list2,
                                  ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              chatScreenCnt.list2.length.toString(),
                              style: TextStyle(
                                color: white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 1),
                            Icon(MdiIcons.messageBadge, color: white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: SizedBox(
              height: height,
              width: width,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      // height: size.height * 0.08,
                      child: TabBar(
                        labelStyle: TextStyle(
                          color: black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        labelColor: black,
                        unselectedLabelColor: vreyDarkGrayishBlue,
                        tabs: const [
                          Tab(text: "Messages"),
                          Tab(text: "Ask"),
                          Tab(text: "Groups"),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height * 0.83,
                      // color: black,
                      child: TabBarView(
                        children: [
                          chatScreenCnt.fetched.value
                              ? chatScreenCnt.list1.isNotEmpty
                                  ? ListView.builder(
                                    itemCount: chatScreenCnt.list1.length,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(top: 16),
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => Message(
                                                    profileuserphone:
                                                        "${chatScreenCnt.list1[index]["listphone"]}",
                                                    userimg:
                                                        "${chatScreenCnt.list1[index]["listimg"]}",
                                                    username:
                                                        "${chatScreenCnt.list1[index]["listname"]}",
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                            top: 10,
                                            bottom: 10,
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: Row(
                                                  children: <Widget>[
                                                    profileImageWidget(
                                                      size.height,
                                                      size.width,
                                                      "${chatScreenCnt.list1[index]["listimg"]}",
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Container(
                                                        color:
                                                            Colors.transparent,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: <Widget>[
                                                            Text(
                                                              "${chatScreenCnt.list1[index]["listname"]}",
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                            ),
                                                            Text(
                                                              "${chatScreenCnt.list1[index]["updatedText"]}",
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  : Center(
                                    child: Text(
                                      'No Messages',
                                      style: TextStyle(
                                        fontFamily: 'Neue',
                                        fontSize: 22,
                                        color: black,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                              : buildCPIWidget(height, width),
                          const AskPostListScreen(),
                          GroupScreen(userMobile: widget.userMobile),
                        ],
                      ),
                    ),
                    // : Container()
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return DefaultTabController(
        length: 3,
        child: Obx(
          () => Scaffold(
            appBar: AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: blue,
              flexibleSpace: SafeArea(
                child: Container(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back, color: white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              "Conversations",
                              style: TextStyle(
                                fontSize: 18,
                                color: white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => MessageRequestScreen(
                                    list: chatScreenCnt.list2,
                                  ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              chatScreenCnt.list2.length.toString(),
                              style: TextStyle(
                                color: white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 1),
                            Icon(MdiIcons.messageBadge, color: white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: SizedBox(
              height: height,
              width: width,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      // height: size.height * 0.08,
                      child: TabBar(
                        labelStyle: TextStyle(
                          color: black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        labelColor: black,
                        unselectedLabelColor: vreyDarkGrayishBlue,
                        tabs: const [
                          Tab(text: "Messages"),
                          Tab(text: "Ask"),
                          Tab(text: "Groups"),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: height * 0.83,
                      child: TabBarView(
                        children: [
                          Scaffold(
                            backgroundColor: white,
                            resizeToAvoidBottomInset: false,
                            floatingActionButton: FloatingActionButton(
                              backgroundColor: blue,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const ContactsScreen(),
                                  ),
                                );
                              },
                              child: const Icon(Icons.contacts),
                            ),
                            body:
                                chatScreenCnt.fetched.value
                                    ? chatScreenCnt.list1.isNotEmpty
                                        ? ListView.builder(
                                          itemCount: chatScreenCnt.list1.length,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) => Message(
                                                          profileuserphone:
                                                              "${chatScreenCnt.list1[index]["listphone"]}",
                                                          userimg:
                                                              "${chatScreenCnt.list1[index]["listimg"]}",
                                                          username:
                                                              "${chatScreenCnt.list1[index]["listname"]}",
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.only(
                                                  left: 16,
                                                  right: 16,
                                                  top: 10,
                                                  bottom: 10,
                                                ),
                                                child: Row(
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: Row(
                                                        children: <Widget>[
                                                          profileImageWidget(
                                                            size.height,
                                                            size.width,
                                                            "${chatScreenCnt.list1[index]["listimg"]}",
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              color:
                                                                  Colors
                                                                      .transparent,
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: <
                                                                  Widget
                                                                >[
                                                                  Text(
                                                                    "${chatScreenCnt.list1[index]["listname"]}",
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    "${chatScreenCnt.list1[index]["updatedText"]}",
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                        : Center(
                                          child: Text(
                                            'No Messages',
                                            style: TextStyle(
                                              fontFamily: 'Neue',
                                              fontSize: 22,
                                              color: black,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        )
                                    : buildCPIWidget(height, width),
                          ),
                          const NormalUserAskPostListScreen(),
                          GroupScreen(userMobile: widget.userMobile),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
