import 'package:flutter/material.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:get/get.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import '../../constants/colors.dart';
import '../messageScreen/message_screen.dart';
import '../otherProfileScreen/other_profile_screen.dart';
import 'contacts_services.dart';

class ContactsScreen extends StatefulWidget {
  final String? cameFrom;
  const ContactsScreen({super.key, this.cameFrom});

  @override
  // ignore: library_private_types_in_public_api
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsScreenCnt controller = Get.put(ContactsScreenCnt());
  final TextEditingController searchController = TextEditingController();
  RxList<ContactsModel> filteredContacts = <ContactsModel>[].obs;
  bool isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterContacts);
    _initializeContacts();
  }

  Future<void> _initializeContacts() async {
    // First try to load cached contacts
    if (controller.contactsDataList.isEmpty) {
      await controller.getDeviceContacts();
    }
    isInitialLoad = false;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterContacts() {
    final query = searchController.text.toLowerCase();
    filteredContacts.value =
        query.isEmpty
            ? controller.contactsDataList
            : controller.contactsDataList.where((contact) {
              return contact.name.toLowerCase().contains(query) ||
                  contact.username.toLowerCase().contains(query) ||
                  contact.mobileNumber.toLowerCase().contains(query);
            }).toList();
  }

  Future<void> _refreshContacts() async {
    await controller.refreshContacts();
    _filterContacts(); // Re-apply search filter after refresh
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: const Text("Contacts"),
        backgroundColor: blue,
        elevation: 0,
      ),
      body: Obx(() {
        if (isInitialLoad && controller.contactsDataList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading contacts...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (controller.hasError.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _refreshContacts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        // Initialize filtered contacts
        if (filteredContacts.isEmpty &&
            controller.contactsDataList.isNotEmpty) {
          filteredContacts.value = controller.contactsDataList;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search contacts...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (controller.isLoadingNewContacts.value)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: Obx(() {
                if (filteredContacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.contacts,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          controller.contactsDataList.isEmpty
                              ? "No contacts found"
                              : "No matching contacts",
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        if (controller.contactsDataList.isEmpty)
                          TextButton(
                            onPressed: _refreshContacts,
                            child: const Text("Refresh Contacts"),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshContacts,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: filteredContacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      return _buildContactItem(context, size, contact);
                    },
                  ),
                );
              }),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    Size size,
    ContactsModel contact,
  ) {
    return GestureDetector(
      onTap: () {
        final screen =
            widget.cameFrom != "Profile"
                ? Message(
                  profileuserphone: contact.mobileNumber,
                  userimg: contact.profilePicture,
                  username: contact.username,
                )
                : OtherProfileScreen(mobileNumber: contact.mobileNumber);
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                profileImageWidget(
                  size.height,
                  size.width,
                  contact.profilePicture,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.username,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.mobileNumber,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
