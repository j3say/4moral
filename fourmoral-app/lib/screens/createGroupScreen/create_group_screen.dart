// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/createGroupScreen/create_group_controller.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/widgets/box_shadow.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';
import 'package:fourmoral/widgets/text_form_field.dart';
import 'package:get/get.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final createGroupCnt = Get.put(CreateGroupCnt());

  @override
  void initState() {
    super.initState();
    createGroupCnt.refGroups = FirebaseDatabase.instance.ref().child('Groups');
    createGroupCnt.getDeviceContacts();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(title: const Text('Create Group'), backgroundColor: blue),
      body: Obx(
        () => SizedBox(
          height: height,
          width: width,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: createGroupCnt.formKey,
                  child: Column(
                    children: [
                      textFormFieldWidget(
                        'Group Name',
                        size,
                        context,
                        createGroupCnt.groupNameController,
                        createGroupCnt.groupNameFocusNode,
                        null,
                        'Enter Your Group Name',
                        true,
                        false,
                        (value) {
                          if (value.isEmpty) {
                            return 'Enter Group Name';
                          } else {
                            return null;
                          }
                        },
                        (value) {},
                      ),
                      const SizedBox(height: 10),
                      Obx(
                        () => Text(
                          "${createGroupCnt.selectedContactIds.length} contacts selected",
                          style: TextStyle(
                            color: blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (createGroupCnt.formKey.currentState!.validate() &&
                              createGroupCnt.selectedContactIds.isNotEmpty) {
                            createGroupCnt.createGroup(context: context);
                          } else if (createGroupCnt
                              .selectedContactIds
                              .isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select at least one contact',
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          minimumSize: Size(width * 0.4, height * 0.07),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Create Group",
                          style: TextStyle(fontSize: 18, color: white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(thickness: 1),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select Contacts",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child:
                    createGroupCnt.contactsDataFetched.value
                        ? createGroupCnt.contactsDataList.isEmpty
                            ? Center(
                              child: Text(
                                "No Contacts Found",
                                style: TextStyle(color: black, fontSize: 18),
                              ),
                            )
                            : ContactsList(createGroupCnt: createGroupCnt)
                        : buildCPIWidget(height, width),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactsList extends StatelessWidget {
  final CreateGroupCnt createGroupCnt;

  const ContactsList({super.key, required this.createGroupCnt});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return ListView.builder(
      itemCount: createGroupCnt.contactsDataList.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final contact = createGroupCnt.contactsDataList[index];

        return Obx(() {
          final isSelected = createGroupCnt.selectedContactIds.contains(
            contact.mobileNumber,
          );

          return GestureDetector(
            onTap: () {
              createGroupCnt.toggleContactSelection(contact.mobileNumber);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? blue.withOpacity(0.15) : white,
                boxShadow: boxShadowCustomProfileWidget(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    profileImageWidget(height, width, contact.profilePicture),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.username,
                            style: TextStyle(
                              color: black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            contact.mobileNumber,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      activeColor: blue,
                      onChanged: (_) {
                        createGroupCnt.toggleContactSelection(
                          contact.mobileNumber,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
