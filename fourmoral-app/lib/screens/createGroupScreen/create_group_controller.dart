import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/groupMessagesScreen/group_messages_screen.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

// Using the external ProfileModel
// External variable: ProfileModel? profileDataModel;

class CreateGroupCnt extends GetxController {
  final formKey = GlobalKey<FormState>();
  DatabaseReference? refGroups;
  final FocusNode groupNameFocusNode = FocusNode();
  final TextEditingController groupNameController = TextEditingController();

  RxBool contactsDataFetched = false.obs;
  RxList<ContactsModel> contactsDataList = <ContactsModel>[].obs;
  RxString contactGroup = "".obs;

  // Track selected contacts
  RxList<String> selectedContactIds = <String>[].obs;

  // We'll use the existing profileDataModel instead of fetching it again
  bool isProfileDataLoaded() {
    // Check if the global profileDataModel is loaded
    return profileDataModel != null &&
        profileDataModel!.mobileNumber.isNotEmpty;
  }

  Future<void> getDeviceContacts() async {
    try {
      contactsDataList.clear();
      contactsDataFetched.value = false;

      if (!await Permission.contacts.request().isGranted) {
        print("Contacts permission denied");
        contactsDataFetched.value = true;
        return;
      }

      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      // Use a Set to track already added numbers
      final addedNumbers = <String>{};

      for (final contact in deviceContacts) {
        if (contact.displayName.isEmpty || contact.phones.isEmpty) continue;

        // Normalize phone number
        String phone = contact.phones.first.number.replaceAll(
          RegExp(r'[^\d+]'),
          '',
        );

        // Optional: Add country code if missing
        if (!phone.startsWith('+')) {
          phone = '+91$phone'; // Change based on your region
        }

        // Skip if already added
        if (addedNumbers.contains(phone)) continue;

        final result =
            await FirebaseFirestore.instance
                .collection('Users')
                .where('mobileNumber', isEqualTo: phone)
                .get();

        if (result.docs.isNotEmpty) {
          addedNumbers.add(phone); // Mark this number as added

          contactsDataList.add(
            ContactsModel(
              result.docs.first.data()['name'] ?? "",
              contact.displayName,
              result.docs.first.data()['profilePicture'] ?? "",
              phone,
              result.docs.first.id,
            ),
          );
        }
      }

      // Sort the final filtered list
      contactsDataList.sort((a, b) => a.username.compareTo(b.username));
      contactsDataFetched.value = true;
    } catch (e) {
      print("Error getting device contacts: $e");
      contactsDataFetched.value = true;
    }
  }

  // Toggle contact selection
  void toggleContactSelection(String mobileNumber) {
    if (selectedContactIds.contains(mobileNumber)) {
      selectedContactIds.remove(mobileNumber);
    } else {
      selectedContactIds.add(mobileNumber);
    }

    // Update contactGroup string
    updateContactGroupString();
  }

  // Update the contact group string based on selected contacts
  void updateContactGroupString() {
    contactGroup.value = "";

    for (String mobileNumber in selectedContactIds) {
      contactGroup.value += "$mobileNumber--";
    }
  }

  void createGroup({required BuildContext context}) async {
    if (selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    if (groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    try {
      // Add current user to group members if not already included
      if (profileDataModel?.mobileNumber != null) {
        if (!selectedContactIds.contains(profileDataModel!.mobileNumber)) {
          selectedContactIds.add(profileDataModel!.mobileNumber);
          updateContactGroupString();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not loaded yet')),
        );
        return;
      }

      DatabaseReference rootRef = FirebaseDatabase.instance.ref();
      String groupKey = rootRef.child('Groups').push().key!;

      // Ensure refGroups is properly initialized
      final refGroups = FirebaseDatabase.instance.ref().child('Groups');

      await refGroups.child(groupKey).set({
        'members': contactGroup.value,
        'admin': profileDataModel?.mobileNumber,
        'dateTime': DateTime.now().toString(),
        'groupName': groupNameController.text.trim(),
        'updatedTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'updatedText': "",
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder:
              (context) => GroupMessagesScreen(
                groupKey: groupKey,
                groupMembers: contactGroup.value,
              ),
        ),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    }
  }

  @override
  void onInit() {
    super.onInit();
    getDeviceContacts(); // Auto-fetch contacts when controller initializes
  }

  @override
  void onClose() {
    groupNameController.dispose();
    groupNameFocusNode.dispose();
    super.onClose();
  }
}
