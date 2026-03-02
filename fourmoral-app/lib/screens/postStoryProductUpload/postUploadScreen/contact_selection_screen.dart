import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/postStoryProductUpload/controller/add_post_controller.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:get/get.dart';

class ContactSelectionScreen extends StatelessWidget {
  final ProfileModel? profileModel;
  final ContactsScreenCnt contactsController;
  final ProfileController profileController;

  const ContactSelectionScreen({
    super.key,
    this.profileModel,
    required this.contactsController,
    required this.profileController,
    required,
  });

  @override
  Widget build(BuildContext context) {
    contactsController.initializeSelection(
      contactsController.selectedContacts,
      profileModel,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: blue,
        title: Obx(
          () => Text(
            'Select Contacts (${contactsController.contactsDataList.where((contact) => contact.isSelected).length})',
            style: const TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Update selectedContacts in AddPostTextController
              contactsController.selectedContacts.value =
                  contactsController.contactsDataList
                      .where((contact) => contact.isSelected)
                      .toList();

              // Save selected contacts to Firestore
              if (profileModel?.mobileNumber != null) {
                profileController.saveSelectedContacts(
                  contactsController.selectedContacts,
                );
              }

              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Obx(
        () => Column(
          children: [
            // Selected Contacts Horizontal List
            if (contactsController.contactsDataList.any(
              (contact) => contact.isSelected,
            ))
              Container(
                height: 90,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      contactsController.contactsDataList
                          .where((contact) => contact.isSelected)
                          .length,
                  itemBuilder: (context, index) {
                    final selectedContacts =
                        contactsController.contactsDataList
                            .asMap()
                            .entries
                            .where((entry) => entry.value.isSelected)
                            .toList();
                    final contact = selectedContacts[index].value;
                    final contactIndex = selectedContacts[index].key;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                child: Text(contact.name[0]),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  contact.name,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                contactsController
                                    .contactsDataList[contactIndex] = contact
                                    .copyWith(isSelected: false);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const Divider(height: 1, color: Colors.grey),
            // All Contacts Vertical List
            Expanded(
              child:
                  contactsController.isLoadingNewContacts.value
                      ? const Center(child: CircularProgressIndicator())
                      : contactsController.hasError.value
                      ? Center(
                        child: Text(contactsController.errorMessage.value),
                      )
                      : contactsController.contactsDataList.isEmpty
                      ? const Center(child: Text('No contacts found'))
                      : ListView.builder(
                        itemCount: contactsController.contactsDataList.length,
                        itemBuilder: (context, index) {
                          final contact =
                              contactsController.contactsDataList[index];
                          return ListTile(
                            onTap: () {
                              contactsController
                                  .contactsDataList[index] = contact.copyWith(
                                isSelected: !contact.isSelected,
                              );
                              contactsController.contactsDataList
                                  .where((contact) => contact.isSelected)
                                  .toList();
                            },
                            leading: CircleAvatar(child: Text(contact.name[0])),
                            title: Text(contact.name),
                            subtitle: Text(contact.mobileNumber),
                            trailing: Checkbox(
                              value: contact.isSelected,
                              onChanged: (value) {
                                contactsController
                                    .contactsDataList[index] = contact.copyWith(
                                  isSelected: value ?? false,
                                );
                                contactsController.contactsDataList
                                    .where((contact) => contact.isSelected)
                                    .toList();
                              },
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
