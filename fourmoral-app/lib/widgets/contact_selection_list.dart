// import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';
import 'package:get/get.dart';

class ContactModel {
  String name, phoneNumber;
  bool isSelected;

  ContactModel(this.name, this.phoneNumber, this.isSelected);
}

class ContactSelection extends StatefulWidget {
  final String profileuserphone;
  const ContactSelection({super.key, required this.profileuserphone});

  @override
  // ignore: library_private_types_in_public_api
  _ContactSelectionState createState() => _ContactSelectionState();
}

class _ContactSelectionState extends State<ContactSelection> {
  RxBool isLoading = false.obs;

  List<ContactModel> contacts = [];
  final messageCnt = Get.put(MessageCnt());

  List<ContactModel> selectedContacts = [];

  init() async {
    isLoading = true.obs;
    // final contactList = await ContactsService.getContacts(
    //     withThumbnails: false, photoHighResolution: false);

    // for (var i = 0; i < contactList.length; i++) {
    //   for (var j = 0; j < contactList[i].phones!.length; j++) {
    //     contacts.add(ContactModel("${contactList[i].displayName}",
    //         "${contactList[i].phones?[j].value}", false));
    //   }
    // }
    setState(() {});

    isLoading = false.obs;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton:
          selectedContacts.isNotEmpty
              ? FloatingActionButton(
                onPressed: () {
                  for (var element in selectedContacts) {
                    messageCnt.addMessage(
                      element.name,
                      profileuserphone: widget.profileuserphone,
                      contact: element.phoneNumber,
                      type: "contact",
                    );
                  }
                  Navigator.pop(context);
                },
                backgroundColor: blue,
                elevation: 0,
                child: Icon(Icons.send, color: white, size: 18),
              )
              : const SizedBox(),
      appBar: AppBar(
        title: const Text("Contact"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Center(
              child: Text(
                selectedContacts.length.toString(),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: SafeArea(
        child: Obx(
          () =>
              isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (BuildContext context, int index) {
                            return contactItem(
                              contacts[index].name,
                              contacts[index].phoneNumber,
                              contacts[index].isSelected,
                              index,
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

  Widget contactItem(
    String name,
    String phoneNumber,
    bool isSelected,
    int index,
  ) {
    return ListTile(
      leading: const CircleAvatar(
        // backgroundColor: Colors.green[700],
        child: Icon(Icons.person_outline_outlined, color: Colors.white),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(phoneNumber),
      trailing:
          isSelected
              ? Icon(Icons.check_circle, color: Colors.green[700])
              : const Icon(Icons.check_circle_outline, color: Colors.grey),
      onTap: () {
        setState(() {
          contacts[index].isSelected = !contacts[index].isSelected;
          if (contacts[index].isSelected == true) {
            selectedContacts.add(ContactModel(name, phoneNumber, true));
          } else if (contacts[index].isSelected == false) {
            selectedContacts.removeWhere(
              (element) => element.name == contacts[index].name,
            );
          }
        });
      },
    );
  }
}
