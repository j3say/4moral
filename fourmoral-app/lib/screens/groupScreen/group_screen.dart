// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/group.dart';
import 'package:fourmoral/models/group_member.dart';
import 'package:fourmoral/screens/group/group_chat_screen.dart';
import 'package:fourmoral/screens/group/create_group_screen.dart';
import 'package:fourmoral/widgets/circular_progress_indicator.dart';

class GroupScreen extends StatefulWidget {
  final String userMobile;

  const GroupScreen({super.key, required this.userMobile});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _groupsStream = const Stream.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

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

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    String? uniqueId = await getUserUniqueId(widget.userMobile);

    if (uniqueId != null) {
      print('Found user ID: $uniqueId');

      try {
        // First, get all groups
        QuerySnapshot allGroups =
            await _firestore
                .collection('groups')
                .orderBy('createdAt', descending: true)
                .get();

        // Then filter locally for groups where the user is a member
        List<String> groupIds = [];

        for (var doc in allGroups.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          List<dynamic> members = data['members'] ?? [];

          // Check if any member has the matching userId
          bool isMember = members.any(
            (member) =>
                member is Map<String, dynamic> && member['userId'] == uniqueId,
          );

          if (isMember) {
            groupIds.add(doc.id);
          }
        }

        if (groupIds.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _groupsStream =
                _firestore
                    .collection('groups')
                    .where(FieldPath.documentId, whereIn: groupIds)
                    .snapshots();
            _isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _groupsStream = const Stream.empty();
            _isLoading = false;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _groupsStream = const Stream.empty();
          _isLoading = false;
        });
      }
    } else {
      print('User ID not found for mobile: ${widget.userMobile}');
      setState(() {
        _groupsStream = const Stream.empty();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: blue,
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        CreateGroupScreen2(userMobile: widget.userMobile),
              ),
            ),
        child: const Icon(Icons.group_add),
      ),
      body:
          _isLoading
              ? buildCPIWidget(size.height, size.width)
              : StreamBuilder<QuerySnapshot>(
                stream: _groupsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return buildCPIWidget(size.height, size.width);
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildGroupList(snapshot.data!.docs);
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No groups yet', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Create your first group by tapping the + button',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        try {
          Map<String, dynamic> data =
              docs[index].data() as Map<String, dynamic>;
          // If the document doesn't have an id field, add it from the document ID
          if (!data.containsKey('id') ||
              data['id'] == null ||
              data['id'].isEmpty) {
            data['id'] = docs[index].id;
          }

          final group = Group.fromMap(data);
          return _buildGroupItem(group);
        } catch (e) {
          print('Error parsing group at index $index: $e');
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildGroupItem(Group group) {
    // Count admins and normal members
    int adminCount =
        group.members.where((m) => m.role == MemberRole.admin).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: blue.withOpacity(0.2),
          backgroundImage:
              group.groupPicUrl.isNotEmpty
                  ? NetworkImage(group.groupPicUrl)
                  : null,
          child:
              group.groupPicUrl.isEmpty ? Icon(Icons.group, color: blue) : null,
        ),
        title: Text(group.name),
        subtitle: Text(
          '${group.members.length} members • $adminCount admin${adminCount != 1 ? 's' : ''} • ${group.isPublic ? 'Public' : 'Private'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => GroupChatScreen(
                      group: group,
                      userMobile: widget.userMobile,
                    ),
              ),
            ),
      ),
    );
  }
}
