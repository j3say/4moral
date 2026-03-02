import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/models/group.dart';

class GroupSecuritySettingsModal extends StatefulWidget {
  final Group group;
  final Function(bool isPublic, bool adminOnlyChat) onSave;

  const GroupSecuritySettingsModal({
    super.key,
    required this.group,
    required this.onSave,
  });

  @override
  State<GroupSecuritySettingsModal> createState() =>
      _GroupSecuritySettingsModalState();
}

class _GroupSecuritySettingsModalState
    extends State<GroupSecuritySettingsModal> {
  late bool _isPublic;
  late bool _adminOnlyChat;
  int _pendingRequests =
      0; // To display number of pending requests when private

  @override
  void initState() {
    super.initState();
    _isPublic = widget.group.isPublic;
    _adminOnlyChat = widget.group.adminOnlyChat;
    if (!_isPublic) {
      _fetchPendingRequests();
    }
  }

  Future<void> _fetchPendingRequests() async {
    try {
      // Fetch pending requests from Firestore
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.group.id)
              .collection('requests')
              .where('status', isEqualTo: 'pending')
              .get();

      setState(() {
        _pendingRequests = snapshot.docs.length;
      });
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  Widget contentBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Security Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Group Privacy Setting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group Privacy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _isPublic ? Icons.public : Icons.lock,
                            color:
                                _isPublic
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isPublic
                                  ? 'Public: Anyone can join'
                                  : 'Private: Request to join required',
                              style: Theme.of(context).textTheme.bodyMedium,
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
                          if (!value) {
                            _fetchPendingRequests();
                          }
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),

                // Show pending requests section when private
                if (!_isPublic) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pending Join Requests',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to pending requests page
                          Navigator.of(
                            context,
                          ).pop(); // Close this dialog first
                          // Then navigate to requests page
                          // Navigator.push(...);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$_pendingRequests',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Admin Only Chat Setting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Permissions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _adminOnlyChat
                                ? Icons.admin_panel_settings
                                : Icons.chat,
                            color:
                                _adminOnlyChat
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _adminOnlyChat
                                  ? 'Only admin can send messages'
                                  : 'All members can send messages',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _adminOnlyChat,
                      onChanged: (value) {
                        setState(() {
                          _adminOnlyChat = value;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  widget.onSave(_isPublic, _adminOnlyChat);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Example of how to use this modal:
void showGroupSecuritySettings(BuildContext context, Group group) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return GroupSecuritySettingsModal(
        group: group,
        onSave: (isPublic, adminOnlyChat) async {
          // Update the group in Firestore
          try {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(group.id)
                .update({'isPublic': isPublic, 'adminOnlyChat': adminOnlyChat});

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Group settings updated successfully'),
              ),
            );
          } catch (e) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating group settings: $e')),
            );
          }
        },
      );
    },
  );
}
