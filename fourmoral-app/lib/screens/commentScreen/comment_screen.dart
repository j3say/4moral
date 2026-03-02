import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'comment_services.dart';

class CommentScreen extends StatefulWidget {
  final String? postId;

  const CommentScreen({super.key, this.postId});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final commentCnt = Get.put(CommentScreenCnt());

  @override
  void initState() {
    super.initState();
    commentCnt.getCommentData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Post Comments"), backgroundColor: blue),
      body: Obx(
        () =>
            commentCnt.commentDataFetched.value
                ? SizedBox(
                  height: height,
                  width: width,
                  child: Column(
                    children: [
                      SizedBox(
                        height: height * 0.85,
                        child: Stack(
                          children: <Widget>[
                            commentCnt.commentDataList.isEmpty
                                ? Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    "No Comments",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: black,
                                      fontSize: 18,
                                    ),
                                  ),
                                )
                                : Container(),
                            ListView.builder(
                              itemCount: commentCnt.commentDataList.length,
                              physics: const BouncingScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.only(
                                top: 10,
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom +
                                    height * 0.09,
                              ),
                              controller: commentCnt.scrollController,
                              reverse: true,
                              itemBuilder: (context, index) {
                                var time = Jiffy.parse(
                                  commentCnt.commentDataList[index].dateTime,
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            color: white.withOpacity(0.6),
                                            boxShadow:
                                                boxShadowCustomProfileWidget(),
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              profileImageWidget(
                                                height,
                                                width,
                                                commentCnt
                                                    .commentDataList[index]
                                                    .profilePicture,
                                              ),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                width: width * 0.6,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      commentCnt
                                                          .commentDataList[index]
                                                          .username,
                                                      style: TextStyle(
                                                        color: black,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    Text(
                                                      commentCnt
                                                          .commentDataList[index]
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
                                        style: TextStyle(color: black),
                                        decoration: InputDecoration(
                                          hintText: "Comment...",
                                          contentPadding: EdgeInsets.only(
                                            bottom: 10,
                                            top: 10,
                                            left: 10,
                                          ),
                                          hintStyle: TextStyle(color: black),
                                          border: InputBorder.none,
                                        ),
                                        controller:
                                            commentCnt.messageController,
                                        autofocus: false,
                                        onTap: commentCnt.scrolltobottom,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: FloatingActionButton(
                                        onPressed: () {
                                          if (commentCnt
                                                  .messageController
                                                  .text !=
                                              "") {
                                            commentCnt.addMessage(
                                              comment:
                                                  commentCnt
                                                      .messageController
                                                      .text,
                                              postId: widget.postId,
                                            );
                                            commentCnt.messageController
                                                .clear();
                                            commentCnt.scrolltobottom();
                                          }
                                        },
                                        backgroundColor: Colors.blue,
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
                    ],
                  ),
                )
                : buildCPIWidget(height, width),
      ),
    );
  }
}
