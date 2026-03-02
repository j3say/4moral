import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import '../../constants/colors.dart';
import '../../models/post_model.dart';
import '../../widgets/text_form_field.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.postObject,
    this.profileObject,
    this.type,
  });

  final PostModel? postObject;
  final ProfileModel? profileObject;
  final String? type;
  @override
  // ignore: library_private_types_in_public_api
  _ReportScreenState createState() =>
      // ignore: no_logic_in_create_state
      _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  _ReportScreenState();

  CollectionReference collectionReportReference = FirebaseFirestore.instance
      .collection('Reports');

  final FocusNode _reportFocusNode = FocusNode();

  final TextEditingController _reportController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  // ignore: must_call_super
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Report'), backgroundColor: blue),
      body: SizedBox(
        height: height,
        width: width,
        child: Column(
          children: [
            Column(
              children: [
                const SizedBox(height: 20),
                textFormFieldWidgetBigger(
                  'Complaint',
                  size,
                  context,
                  _reportController,
                  _reportFocusNode,
                  null,
                  'Enter Your Complaint',
                  true,
                  false,
                  (value) {
                    if (value.isEmpty) {
                      return 'Enter Complaint';
                    } else {
                      return null;
                    }
                  },
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    if (widget.type == "User") {
                      collectionReportReference.add({
                        'complaint': _reportController.text,
                        'userMobileNumber': widget.profileObject?.mobileNumber,
                        'number': profileDataModel?.mobileNumber,
                        'type': widget.type,
                        'dateTime': DateTime.now().toString(),
                        'profilePicture': widget.profileObject?.profilePicture,
                      });
                    } else {
                      collectionReportReference.add({
                        'complaint': _reportController.text,
                        'postMobileNumber': widget.postObject?.mobileNumber,
                        'number': profileDataModel?.mobileNumber,
                        'type': widget.type,
                        'dateTime': DateTime.now().toString(),
                        'postKey': widget.postObject?.key,
                        'urls':
                            widget.postObject?.type == "Photo"
                                ? widget.postObject!.urls.isNotEmpty
                                    ? widget.postObject?.urls[0]
                                    : ''
                                : widget.postObject?.thumbnail,
                      });
                    }

                    Navigator.pop(context);

                    _reportController.clear();
                    flutterShowToast("Report Sent");
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      child: Container(
                        height: height * 0.07,
                        width: width * 0.4,
                        color: blue,
                        child: Center(
                          child: Text(
                            "Report",
                            style: TextStyle(fontSize: 20, color: white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
