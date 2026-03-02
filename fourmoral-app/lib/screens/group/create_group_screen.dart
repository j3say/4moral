import 'package:flutter/material.dart';
import 'package:fourmoral/models/group.dart';
import 'package:fourmoral/models/group_member.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/group/group_chat_screen.dart';
import 'package:get/get.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGroupScreen2 extends StatefulWidget {
  const CreateGroupScreen2({super.key, required this.userMobile});
  final String userMobile;
  @override
  // ignore: library_private_types_in_public_api
  _CreateGroupScreen2State createState() => _CreateGroupScreen2State();
}

class _CreateGroupScreen2State extends State<CreateGroupScreen2> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<ContactsModel> _selectedContacts = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isPublic = true;
  final ContactsScreenCnt _contactsController = Get.put(ContactsScreenCnt());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isCreatingGroup = false;

  Future<String?> getUserUniqueId(String userMobile) async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('userMobile', isEqualTo: userMobile)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Return the document ID
        return querySnapshot.docs.first.id;
      } else {
        // Try alternative field names if needed
        QuerySnapshot altQuery =
            await FirebaseFirestore.instance
                .collection('Users')
                .where('mobileNumber', isEqualTo: userMobile)
                .limit(1)
                .get();

        if (altQuery.docs.isNotEmpty) {
          return altQuery.docs.first.id;
        }
        return null;
      }
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _toggleContactSelection(ContactsModel contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  List<ContactsModel> _getFilteredContacts() {
    if (_searchQuery.isEmpty) {
      return _contactsController.contactsDataList;
    }

    return _contactsController.contactsDataList
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(_searchQuery) ||
              contact.username.toLowerCase().contains(_searchQuery) ||
              contact.mobileNumber.contains(_searchQuery),
        )
        .toList();
  }

  Widget _buildSelectedContactsChips() {
    if (_selectedContacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            _selectedContacts.map((contact) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundImage:
                      contact.profilePicture.isNotEmpty
                          ? NetworkImage(contact.profilePicture)
                          : null,
                  backgroundColor: Colors.blue.shade100,
                  child:
                      contact.profilePicture.isEmpty
                          ? Text(contact.name[0].toUpperCase())
                          : null,
                ),
                label: Text(contact.name),
                deleteIcon: const Icon(Icons.cancel, size: 18),
                onDeleted: () => _toggleContactSelection(contact),
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              );
            }).toList(),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingGroup = true;
    });

    try {
      final groupRef = _firestore.collection('groups').doc();
      String? uniqueId = await getUserUniqueId(widget.userMobile);

      // Enhanced error handling for user identification
      if (uniqueId == null || uniqueId.isEmpty) {
        // Try getting current user from FirebaseAuth as fallback
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          uniqueId = currentUser.uid;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to create a group'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      // Verify all selected contacts have valid uniqueIds
      final invalidContacts =
          _selectedContacts.where((c) => c.uniqueId.isEmpty).toList();
      if (invalidContacts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${invalidContacts.length} contacts are missing user IDs',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final members = [
        GroupMember(
          userId: uniqueId,
          role: MemberRole.admin,
          joinedAt: DateTime.now(),
        ),
        ..._selectedContacts.map(
          (contact) => GroupMember(
            userId: contact.uniqueId,
            role: MemberRole.normal,
            joinedAt: DateTime.now(),
          ),
        ),
      ];
      // Rest of your group creation logic...
      final group = Group(
        id: groupRef.id,
        name: _groupNameController.text.trim(),
        groupPicUrl: '',
        createdBy: uniqueId,
        createdAt: DateTime.now(),
        members: members,
        memberIds: members.map((m) => m.userId).toList(),
        isPublic: _isPublic,
        adminUid: uniqueId,
        adminOnlyChat: false,
      );

      // Convert the group to a map
      final groupData = group.toMap();

      // Save to Firestore
      await groupRef.set(groupData);

      // Add group reference to each member's document
      final batch = _firestore.batch();

      // Add to current user's groups
      final currentUserRef = _firestore.collection('Users').doc(uniqueId);
      batch.set(currentUserRef, {
        'groups': FieldValue.arrayUnion([group.id]),
      }, SetOptions(merge: true));

      // Then handle other members
      for (final member in group.members) {
        if (member.userId == uniqueId) {
          continue; // Skip current user (already handled)
        }

        final userRef = _firestore.collection('Users').doc(member.userId);
        batch.set(userRef, {
          'groups': FieldValue.arrayUnion([group.id]),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Navigate to the group chat screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  GroupChatScreen(group: group, userMobile: widget.userMobile),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create group: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isCreatingGroup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredContacts = _getFilteredContacts();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search contacts...",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                )
                : const Text(
                  'Create Group',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            color: theme.primaryColor,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Icon(Icons.group, color: theme.primaryColor),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      hintText: 'Group Name',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _isPublic ? Icons.public : Icons.lock,
                  color: _isPublic ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPublic ? 'Public Group' : 'Private Group',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _isPublic
                            ? 'Anyone can join this group'
                            : 'Members need an invitation to join',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  activeColor: theme.primaryColor,
                ),
              ],
            ),
          ),

          _buildSelectedContactsChips(),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Text(
                  'Select Contacts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: Colors.grey.shade300)),
                if (_selectedContacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '${_selectedContacts.length} selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Obx(() {
              if (!_contactsController.contactsDataFetched.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: theme.primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading contacts...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              if (_contactsController.contactsDataList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts found that use this app',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (filteredContacts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts match your search',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredContacts[index];
                  final isSelected = _selectedContacts.contains(contact);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color:
                          isSelected
                              ? theme.primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              isSelected
                                  ? theme.primaryColor
                                  : Colors.grey.shade200,
                          backgroundImage:
                              contact.profilePicture.isNotEmpty
                                  ? NetworkImage(contact.profilePicture)
                                  : null,
                          child:
                              contact.profilePicture.isEmpty
                                  ? Text(
                                    contact.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          contact.username,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? CircleAvatar(
                                  radius: 14,
                                  backgroundColor: theme.primaryColor,
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                )
                                : Icon(
                                  Icons.circle_outlined,
                                  color: Colors.grey.shade400,
                                ),
                        onTap: () => _toggleContactSelection(contact),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton:
          _isCreatingGroup
              ? FloatingActionButton.extended(
                onPressed: null,
                icon: const CircularProgressIndicator(color: Colors.white),
                label: const Text('CREATING...'),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              )
              : FloatingActionButton.extended(
                onPressed: _createGroup,
                icon: const Icon(Icons.check),
                label: const Text('CREATE GROUP'),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
    );
  }
}
