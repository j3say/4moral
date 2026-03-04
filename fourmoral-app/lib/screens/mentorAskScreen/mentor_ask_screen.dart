// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';

import '../../constants/colors.dart';
import '../../models/ask_mentor_model.dart';
import '../askScreen/ask_screen.dart';
import 'mentor_ask_screen_services.dart';

class MentorAskScreen extends StatefulWidget {
  const MentorAskScreen({super.key, this.postObject});

  final PostModel? postObject;

  @override
  // ignore: library_private_types_in_public_api, no_logic_in_create_state
  _MentorAskScreenState createState() =>
      // ignore: no_logic_in_create_state
      _MentorAskScreenState();
}

class _MentorAskScreenState extends State<MentorAskScreen> {
  var askMentorDataFetched = false;

  List<AskMentorModel> askMentorDataList = [];

  DatabaseReference? refMentorAsk;

  getAskData() {
    refMentorAsk?.onValue.listen((event) async {
      askMentorDataList.clear();
      if (event.snapshot.value != null) {
        Map? values = event.snapshot.value as Map?;

        values?.forEach((key, value) {
          FirebaseFirestore.instance
              .collection('Users')
              .where('mobileNumber', isEqualTo: key)
              .snapshots()
              .listen((snapshots) {
                askMentorDataList.add(
                  askMentorServicesDataServices(key, snapshots.docs[0]),
                );
                setState(() {
                  askMentorDataFetched = true;
                });
              });
        });
      } else {
        setState(() {
          askMentorDataFetched = true;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    refMentorAsk = FirebaseDatabase.instance
        .ref()
        .child('Ask/')
        .child(widget.postObject?.mobileNumber ?? "")
        .child(widget.postObject?.key ?? "");
    getAskData();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text("Ask Mentors"), backgroundColor: blue),
      body:
          askMentorDataFetched
              ? SizedBox(
                height: height,
                width: width,
                child: SizedBox(
                  height: height * 0.9 - 12,
                  child: Stack(
                    children: <Widget>[
                      askMentorDataList.isEmpty
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
                        itemCount: askMentorDataList.length,
                        physics: const BouncingScrollPhysics(),
                        shrinkWrap: true,
                        padding: EdgeInsets.only(
                          top: 10,
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom +
                              height * 0.09,
                        ),
                        reverse: true,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AskScreen(
                                        postObject: widget.postObject,
                                        phone:
                                            askMentorDataList[index]
                                                .mobileNumber,
                                      ),
                                ),
                              );
                            },
                            child: Column(
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
                                          profileImageWidget(
                                            height,
                                            width,
                                            askMentorDataList[index]
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
                                                  askMentorDataList[index]
                                                      .username,
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
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
              : buildCPIWidget(height, width),
    );
  }
}
