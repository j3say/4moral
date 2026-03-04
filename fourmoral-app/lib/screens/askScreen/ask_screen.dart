// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/screens/askScreen/ask_screen_services.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key, this.postObject, this.phone});

  final PostModel? postObject;
  final String? phone;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final askCnt = Get.put(AskScreenCnt());

  @override
  void initState() {
    super.initState();

    askCnt.refAsk = FirebaseDatabase.instance
        .ref()
        .child('Ask/')
        .child(widget.postObject!.mobileNumber)
        .child(widget.postObject!.key)
        .child(widget.phone.toString());

    askCnt.getAskData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Ask Mentors"),
        backgroundColor: blue,
        actionsPadding: EdgeInsets.symmetric(horizontal: 10),
        actions: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Ask Encryption'),
                      content: const Text(
                        'Messages in this chat are protected with end-to-end encryption. '
                        'This means only you and the person you\'re communicating with can read or listen to them. '
                        'Not even the app or server can access your messages.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
              );
            },
            child: Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Obx(
        () =>
            askCnt.askDataFetched.value
                ? SizedBox(
                  height: height,
                  width: width,
                  child: SizedBox(
                    height: height * 0.9 - 12,
                    child: Stack(
                      children: <Widget>[
                        askCnt.askDataList.isEmpty
                            ? Align(
                              alignment: Alignment.center,
                              child: Text(
                                "No Questions",
                                textAlign: TextAlign.start,
                                style: TextStyle(color: black, fontSize: 18),
                              ),
                            )
                            : Container(),
                        ListView.builder(
                          itemCount: askCnt.askDataList.length,
                          physics: const BouncingScrollPhysics(),
                          shrinkWrap: true,
                          padding: EdgeInsets.only(
                            top: 10,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom +
                                height * 0.09,
                          ),
                          controller: askCnt.scrollController,
                          reverse: true,
                          itemBuilder: (context, index) {
                            var time = Jiffy.parse(
                              askCnt.askDataList[index].dateTime,
                            ).format(pattern: "hh:mm a, MMM dd");

                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.only(
                                    left: 14,
                                    right: 14,
                                    top: 10,
                                    bottom: 10,
                                  ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: white.withOpacity(0.6),
                                        boxShadow:
                                            boxShadowCustomProfileWidget(),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            child: Image.asset(
                                              'assets/ask_emoji.png',
                                            ),
                                          ),
                                          // profileImageWidget(
                                          //   height,
                                          //   width,
                                          //   askCnt
                                          //       .askDataList[index]
                                          //       .profilePicture,
                                          // ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: width * 0.6,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Text(
                                                //   askCnt
                                                //       .askDataList[index]
                                                //       .username,
                                                //   style: TextStyle(
                                                //     color: black,
                                                //     fontSize: 12,
                                                //   ),
                                                // ),
                                                Text(
                                                  askCnt
                                                      .askDataList[index]
                                                      .comment,
                                                  style: TextStyle(
                                                    color: black,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      time,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        color: black,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: size.height * 0.1),
                        Positioned(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                          right: 0.01,
                          child: Container(
                            height: 60,
                            width: width,
                            color: blue,
                            child: Row(
                              children: <Widget>[
                                const SizedBox(width: 15),
                                Expanded(
                                  child: TextFormField(
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: "Comment...",
                                      contentPadding: EdgeInsets.only(
                                        bottom: 10,
                                        top: 10,
                                        left: 10,
                                      ),
                                      hintStyle: TextStyle(color: Colors.white),
                                      border: InputBorder.none,
                                    ),
                                    controller: askCnt.messageController,
                                    autofocus: false,
                                    onTap: askCnt.scrolltobottom,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: FloatingActionButton(
                                    onPressed: () {
                                      if (askCnt.messageController.text != "") {
                                        askCnt.addMessage(
                                          comment:
                                              askCnt.messageController.text,
                                          phone: widget.phone,
                                          postObject: widget.postObject,
                                        );
                                        askCnt.messageController.clear();
                                        askCnt.scrolltobottom();
                                      }
                                    },
                                    backgroundColor: white,
                                    elevation: 0,
                                    child: Icon(
                                      Icons.send,
                                      color: blue,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : buildCPIWidget(height, width),
      ),
    );
  }
}
