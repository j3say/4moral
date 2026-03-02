import 'package:flutter/material.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';

import '../../constants/colors.dart';
import '../messageScreen/message_screen.dart';

class MessageRequestScreen extends StatefulWidget {
  final List? list;

  const MessageRequestScreen({super.key, this.list});

  @override
  _MessageRequestScreenState createState() => _MessageRequestScreenState();
}

class _MessageRequestScreenState extends State<MessageRequestScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
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
                        "Requests",
                        style: TextStyle(
                          fontSize: 18,
                          color: white,
                          fontWeight: FontWeight.w600,
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
      body: SizedBox(
        height: height,
        width: width,
        child:
            widget.list?.isNotEmpty ?? false
                ? SingleChildScrollView(
                  child: Column(
                    children: [
                      ListView.builder(
                        itemCount: widget.list?.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                                            "${widget.list?[index]["listphone"]}",
                                        userimg:
                                            "${widget.list?[index]["listimg"]}",
                                        username:
                                            "${widget.list?[index]["listname"]}",
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
                                          "${widget.list?[index]["listimg"]}",
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Container(
                                            color: Colors.transparent,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  "${widget.list?[index]["listname"]}",
                                                  style: const TextStyle(
                                                    fontSize: 16,
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
                      ),

                      // : Container()
                    ],
                  ),
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
                ),
      ),
    );
  }
}
