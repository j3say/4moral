import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/group.dart';
import 'package:fourmoral/models/group_member.dart';
import 'package:fourmoral/models/group_user.dart';
import 'package:fourmoral/screens/chatScreen/chat_screen.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/group/group_media_page.dart';
import 'package:fourmoral/screens/group/group_security_settings_model.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class GroupInfoScreen extends StatefulWidget {
  final Group group;
  final String userMobile;
  const GroupInfoScreen({
    super.key,
    required this.group,
    required this.userMobile,
  });

  @override
  _GroupInfoScreenState createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late List<GroupMember> _groupMembers;
  late final Map<String, GroupUser> _usersMap = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  late bool isUserAdmin = false;
  late String _qrData;
  final GlobalKey _qrKey = GlobalKey();
  final ContactsScreenCnt contactsController = Get.put(ContactsScreenCnt());

  @override
  void initState() {
    super.initState();
    _groupMembers = List.from(widget.group.members);
    _qrData = 'fourmoral://group/join?groupId=${widget.group.id}';
    _initializeAdminStatus().then((_) {
      _loadUsers();
    });
  }

  Future<String?> getUsernameByDocId(String docId) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('Users').doc(docId).get();
      if (doc.exists) {
        return doc.data()?['username'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  void _showQrCodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Decorative header with brand colors
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/logo.png'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title with custom typography
                        Text(
                          'Join ${widget.group.name}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Subtitle with instruction
                        Text(
                          'Scan this QR code to join the group',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // QR Code with animated entrance
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(begin: 0.8, end: 1.0),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: RepaintBoundary(
                              key: _qrKey,
                              child: QrImageView(
                                data: _qrData,
                                version:
                                    QrVersions.isSupportedVersion(5)
                                        ? 5
                                        : QrVersions.auto,
                                size: 220,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: Theme.of(context).primaryColor,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.9),
                                ),
                                embeddedImage: const AssetImage(
                                  'assets/logo.png',
                                ),
                                embeddedImageStyle: const QrEmbeddedImageStyle(
                                  size: Size(50, 50),
                                ),
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action buttons with brand colors
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _shareQrCode, // You'd need to implement this method
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Add this method to implement sharing functionality
  void _shareQrCode() async {
    try {
      // First, save the QR code image
      final bytes = await _captureQrCode();

      // Create a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Join our group ${widget.group.name}!');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share QR code: $e')));
    }
  }

  // Modify this method to capture the QR code cleanly
  Future<Uint8List> _captureQrCode() async {
    RenderRepaintBoundary boundary =
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // Update your _saveQrCode method to use the captureQrCode function

  Future<void> _initializeAdminStatus() async {
    isUserAdmin = await _isCurrentUserAdmin();
    setState(() {});
  }

  Future<void> _loadUsers() async {
    try {
      if (_groupMembers.isEmpty) {
        print("No members to load");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<String> validUserIds =
          _groupMembers
              .map((m) => m.userId)
              .where((id) => id.isNotEmpty)
              .toList();

      print("Valid user IDs to load: ${validUserIds.length}");

      if (validUserIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Split into chunks if there are many members (Firestore limit)
      const int maxBatchSize = 10;
      for (int i = 0; i < validUserIds.length; i += maxBatchSize) {
        int end =
            (i + maxBatchSize < validUserIds.length)
                ? i + maxBatchSize
                : validUserIds.length;
        List<String> batch = validUserIds.sublist(i, end);

        final usersSnapshot =
            await _firestore
                .collection('Users')
                .where(FieldPath.documentId, whereIn: batch)
                .get();

        print("Fetched ${usersSnapshot.docs.length} users for batch $i-$end");

        for (var doc in usersSnapshot.docs) {
          _usersMap[doc.id] = GroupUser.fromMap(doc.data());
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading users: $e");
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: ${e.toString()}')),
      );
    }
  }

  Future<String?> getUserUniqueId(String userMobile) async {
    try {
      // Check both collections: 'users' and 'Users'
      // First check in 'users' collection
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('userMobile', isEqualTo: userMobile)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }

      // If not found, check in 'Users' collection
      querySnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('userMobile', isEqualTo: userMobile)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }

      // Try alternative field names
      QuerySnapshot altQuery =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('mobileNumber', isEqualTo: userMobile)
              .limit(1)
              .get();

      if (altQuery.docs.isNotEmpty) {
        return altQuery.docs.first.id;
      }

      print('User not found with mobile: $userMobile');
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<bool> _isCurrentUserAdmin() async {
    String? uniqueId = await getUserUniqueId(widget.userMobile);
    print("Current user unique ID: $uniqueId");

    if (uniqueId == null) return false;

    final currentUserMember = _groupMembers.firstWhere(
      (member) => member.userId == uniqueId,
      orElse:
          () => GroupMember(
            userId: '',
            role: MemberRole.normal,
            joinedAt: DateTime.now(),
          ),
    );

    return currentUserMember.role == MemberRole.admin;
  }

  Future<void> _addMember(String userId) async {
    if (!(await _isCurrentUserAdmin())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can add members')),
      );
      return;
    }

    try {
      // Check if user is already in the group
      if (_groupMembers.any((m) => m.userId == userId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User is already in the group')),
        );
        return;
      }

      final newMember = GroupMember(
        userId: userId,
        role: MemberRole.normal,
        joinedAt: DateTime.now(),
      );

      // Update Firestore
      await _firestore.collection('groups').doc(widget.group.id).update({
        'members': FieldValue.arrayUnion([newMember.toMap()]),
      });

      // Also add group to user's groups list
      await _firestore.collection('Users').doc(userId).update({
        'groups': FieldValue.arrayUnion([widget.group.id]),
      });

      // Update local state
      setState(() {
        _groupMembers.add(newMember);
      });

      // Load the new user's data
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      if (userDoc.exists) {
        setState(() {
          _usersMap[userId] = GroupUser.fromMap(
            userDoc.data() as Map<String, dynamic>,
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add member: ${e.toString()}')),
      );
    }
  }

  Future<void> _changeRole(String userId, MemberRole newRole) async {
    if (!(await _isCurrentUserAdmin())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can change roles')),
      );
      return;
    }

    try {
      // Create updated member list
      final updatedMembers =
          _groupMembers.map((member) {
            if (member.userId == userId) {
              return GroupMember(
                userId: userId,
                role: newRole,
                joinedAt: member.joinedAt,
              );
            }
            return member;
          }).toList();

      // Update Firestore
      await _firestore.collection('groups').doc(widget.group.id).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
      });

      // Update local state
      setState(() {
        _groupMembers = updatedMembers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change role: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteGroup() async {
    if (!(await _isCurrentUserAdmin())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can delete the group')),
      );
      return;
    }

    try {
      // Show confirmation dialog
      bool confirmDelete =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Delete Group'),
                  content: const Text(
                    'Are you sure you want to delete this group? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!confirmDelete) return;

      // Remove group from all members' group lists first
      for (var member in _groupMembers) {
        await _firestore.collection('Users').doc(member.userId).update({
          'groups': FieldValue.arrayRemove([widget.group.id]),
        });
      }

      // Delete the group document
      await _firestore.collection('groups').doc(widget.group.id).delete();

      // Navigate back with a result indicating the group was deleted
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(userMobile: widget.userMobile),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete group: ${e.toString()}')),
      );
    }
  }

  Future<void> _removeMember(String userId) async {
    if (!(await _isCurrentUserAdmin())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can remove members')),
      );
      return;
    }

    try {
      // Remove from group's members
      final memberToRemove = _groupMembers.firstWhere(
        (m) => m.userId == userId,
      );
      await _firestore.collection('groups').doc(widget.group.id).update({
        'members': FieldValue.arrayRemove([memberToRemove.toMap()]),
      });

      // Remove group from user's groups list
      await _firestore.collection('Users').doc(userId).update({
        'groups': FieldValue.arrayRemove([widget.group.id]),
      });

      // Update local state
      setState(() {
        _groupMembers.removeWhere((m) => m.userId == userId);
        _usersMap.remove(userId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove member: ${e.toString()}')),
      );
    }
  }

  Future<void> _showAddMemberDialog() async {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = "";
    List<ContactsModel> availableContacts = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading contacts..."),
            ],
          ),
        );
      },
    );

    // Fetch contacts that exist in both device and Firebase
    await contactsController.getDeviceContacts();
    availableContacts =
        contactsController.contactsDataList
            .where(
              (contact) =>
                  !_groupMembers.any(
                    (member) => member.userId == contact.uniqueId,
                  ),
            )
            .toList();

    // Close loading dialog
    Navigator.of(context).pop();

    // Function to filter contacts based on search query
    void filterContacts() {
      if (searchQuery.isEmpty) {
        availableContacts =
            contactsController.contactsDataList
                .where(
                  (contact) =>
                      !_groupMembers.any(
                        (member) => member.userId == contact.uniqueId,
                      ),
                )
                .toList();
      } else {
        availableContacts =
            contactsController.contactsDataList
                .where(
                  (contact) =>
                      (contact.name.toLowerCase().contains(searchQuery) ||
                          contact.mobileNumber.contains(searchQuery)) &&
                      !_groupMembers.any(
                        (member) => member.userId == contact.uniqueId,
                      ),
                )
                .toList();
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Member'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search contacts...",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {
                                      searchQuery = "";
                                      filterContacts();
                                    });
                                  },
                                )
                                : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                          filterContacts();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    if (contactsController.contactsDataFetched.value == false)
                      const Center(child: CircularProgressIndicator())
                    else if (availableContacts.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No contacts available to add'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableContacts.length,
                          itemBuilder: (context, index) {
                            final contact = availableContacts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    contact.profilePicture.isNotEmpty
                                        ? NetworkImage(contact.profilePicture)
                                        : null,
                                child:
                                    contact.profilePicture.isEmpty
                                        ? Text(
                                          contact.name.isNotEmpty
                                              ? contact.name[0]
                                              : '?',
                                        )
                                        : null,
                              ),
                              title: Text(contact.name),
                              subtitle: Text(contact.mobileNumber),
                              onTap: () {
                                Navigator.pop(context);
                                _addMember(contact.uniqueId);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Group Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isUserAdmin)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                // TODO: Implement group editing
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200, // Adjust height as needed
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image:
                                  widget.group.groupPicUrl.isNotEmpty
                                      ? NetworkImage(widget.group.groupPicUrl)
                                      : AssetImage('assets/default_cover.jpg')
                                          as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 210, 164, 255),
                            border: Border(
                              top: BorderSide(
                                width: 2.0,
                                color: Color.fromARGB(255, 73, 73, 73),
                              ), // Top border
                              bottom: BorderSide(
                                width: 2.0,
                                color: const Color.fromARGB(255, 73, 73, 73),
                              ), // Bottom border
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // For small screens, stack the content vertically
                                  if (constraints.maxWidth < 500) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildCreatorInfo(),
                                        const SizedBox(height: 12),
                                        _buildStatusBadge(),
                                      ],
                                    );
                                  } else {
                                    // For larger screens, use row layout
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildCreatorInfo(),
                                        _buildStatusBadge(),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        // Options Section
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  isUserAdmin
                                      ? _buildOptionButton(
                                        imagePath: 'assets/group/user.png',
                                        label: 'Add',
                                        onTap: () {
                                          if (isUserAdmin) {
                                            _showAddMemberDialog();
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Only admins can add members',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      )
                                      : _buildOptionButton(
                                        imagePath: 'assets/group/leave.png',
                                        label: 'Leave',
                                        onTap: () {
                                          // Search functionality
                                        },
                                      ),

                                  _buildOptionButton(
                                    imagePath: 'assets/group/search.png',
                                    label: 'Search',
                                    onTap: () {
                                      // Search functionality
                                    },
                                  ),
                                  _buildOptionButton(
                                    imagePath: 'assets/group/media.png',
                                    label: 'Media',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => GroupMediaPage(
                                                groupId: widget.group.id,
                                                usersMap: _usersMap,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildOptionButton(
                                    imagePath: 'assets/group/notification.png',
                                    label: 'Notification',
                                    onTap: () {
                                      // Notification functionality
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Second row of options
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildOptionButton(
                                    imagePath: 'assets/group/qr.png',
                                    label: 'QR',
                                    onTap: _showQrCodeDialog,
                                  ),
                                  _buildOptionButton(
                                    imagePath: 'assets/group/share.png',
                                    label: 'Share',
                                    onTap: () {
                                      // Share functionality
                                    },
                                  ),
                                  _buildOptionButton(
                                    imagePath: 'assets/group/security.png',
                                    label: 'Security',
                                    onTap: () {
                                      showGroupSecuritySettings(
                                        context,
                                        widget.group,
                                      );
                                    },
                                  ),
                                  _buildOptionButton(
                                    imagePath: 'assets/group/delete.png',
                                    label: 'Delete',
                                    onTap: _deleteGroup,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        // Members Section
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Members',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_groupMembers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('No members found')),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _groupMembers.length,
                            itemBuilder: (context, index) {
                              final member = _groupMembers[index];
                              final user = _usersMap[member.userId];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage:
                                      user?.profilePicture.isNotEmpty == true
                                          ? NetworkImage(user!.profilePicture)
                                          : null,
                                  child:
                                      user?.profilePicture.isEmpty != false
                                          ? Text(
                                            user?.name.isNotEmpty == true
                                                ? user!.name[0]
                                                : '?',
                                          )
                                          : null,
                                ),
                                title: Text(user?.name ?? 'Unknown User'),
                                subtitle: Text(
                                  member.role == MemberRole.admin
                                      ? 'Admin'
                                      : 'Member',
                                  style: TextStyle(
                                    color:
                                        member.role == MemberRole.admin
                                            ? Colors.deepPurple
                                            : Colors.grey,
                                  ),
                                ),
                                trailing:
                                    isUserAdmin &&
                                            member.userId !=
                                                _auth.currentUser?.uid
                                        ? PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'make_admin') {
                                              _changeRole(
                                                member.userId,
                                                MemberRole.admin,
                                              );
                                            } else if (value ==
                                                'remove_admin') {
                                              _changeRole(
                                                member.userId,
                                                MemberRole.normal,
                                              );
                                            } else if (value == 'remove') {
                                              _removeMember(member.userId);
                                            }
                                          },
                                          itemBuilder:
                                              (context) => [
                                                if (member.role !=
                                                    MemberRole.admin)
                                                  const PopupMenuItem(
                                                    value: 'make_admin',
                                                    child: Text('Make Admin'),
                                                  ),
                                                if (member.role ==
                                                        MemberRole.admin &&
                                                    widget.group.adminUid !=
                                                        member.userId)
                                                  const PopupMenuItem(
                                                    value: 'remove_admin',
                                                    child: Text('Remove Admin'),
                                                  ),
                                                const PopupMenuItem(
                                                  value: 'remove',
                                                  child: Text(
                                                    'Remove from Group',
                                                  ),
                                                ),
                                              ],
                                        )
                                        : null,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  // Extract widgets to improve readability
  Widget _buildCreatorInfo() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: [
        const Text(
          'Created By: ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        FutureBuilder<String?>(
          future: getUsernameByDocId(widget.group.adminUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            } else if (snapshot.hasError) {
              return const Text(
                'Error fetching username',
                style: TextStyle(color: Colors.red),
              );
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const Text(
                'Username not found',
                style: TextStyle(fontStyle: FontStyle.italic),
              );
            } else {
              return Text(
                snapshot.data!,
                style: const TextStyle(fontWeight: FontWeight.w500),
              );
            }
          },
        ),
        const SizedBox(width: 10),
        const Text('At: ', style: TextStyle(fontWeight: FontWeight.w600)),
        Text(
          DateFormat('dd MMM yyyy').format(widget.group.createdAt),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      decoration: BoxDecoration(
        color:
            widget.group.isPublic ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.group.isPublic ? Colors.green : Colors.blue,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.group.isPublic ? Icons.public : Icons.lock,
              size: 16,
              color: widget.group.isPublic ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 4),
            Text(
              widget.group.isPublic ? 'Public' : 'Private',
              style: TextStyle(
                color: widget.group.isPublic ? Colors.green : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 30, // size of the circle
            backgroundImage: AssetImage(imagePath), // or use NetworkImage
            backgroundColor: Colors.transparent,
          ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
