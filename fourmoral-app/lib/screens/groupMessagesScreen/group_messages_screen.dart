// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/groupInformationScreen/group_information_screen.dart';
import 'package:fourmoral/screens/groupMessagesScreen/group_message_controller.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import '../../constants/colors.dart';
import '../../widgets/confirm_dialogue_box.dart';
import '../../widgets/flutter_toast.dart';

class GroupMessagesScreen extends StatefulWidget {
  const GroupMessagesScreen({
    super.key,
    required this.groupKey,
    required this.groupMembers,
  });

  final String groupKey;
  final String groupMembers;

  @override
  _GroupMessagesScreenState createState() => _GroupMessagesScreenState();
}

class _GroupMessagesScreenState extends State<GroupMessagesScreen> {
  final groupMessageCnt = Get.put(GroupMessageScreenCnt());
  final _messageFocusNode = FocusNode();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeGroupChat();
    _setupTypingListener();
  }

  void _initializeGroupChat() {
    groupMessageCnt.refGroups = FirebaseDatabase.instance.ref().child('Groups');
    groupMessageCnt.getGroupData(groupKey: widget.groupKey);
    groupMessageCnt.scrollController.addListener(_scrollListener);
  }

  void _setupTypingListener() {
    groupMessageCnt.messageController.addListener(() {
      setState(() {
        _isTyping = groupMessageCnt.messageController.text.isNotEmpty;
      });
    });
  }

  void _scrollListener() {
    // Handle scroll events if needed
  }

  @override
  void dispose() {
    groupMessageCnt.scrollController.removeListener(_scrollListener);
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(context),
      body: Column(
        children: [Expanded(child: _buildMessageList()), _buildMessageInput()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 1,
      backgroundColor: blue,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: white),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: _navigateToGroupInfo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              groupMessageCnt.groupName.value,
              style: TextStyle(
                fontSize: 16,
                color: white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Obx(
              () => Text(
                '${groupMessageCnt.groupDataText.length} messages',
                style: TextStyle(fontSize: 12, color: white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (groupMessageCnt.admin.value != groupMessageCnt.profileUserPhone)
          IconButton(
            icon: Icon(Icons.exit_to_app, color: white),
            onPressed: _showLeaveGroupDialog,
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: white),
          onSelected: (value) {
            if (value == 'info') {
              _navigateToGroupInfo();
            } else if (value == 'leave') {
              _showLeaveGroupDialog();
            }
          },
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(value: 'info', child: Text('Group Info')),
              PopupMenuItem(value: 'leave', child: Text('Leave Group')),
            ];
          },
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return Obx(() {
      if (!groupMessageCnt.groupDataFetched.value) {
        return Center(child: CircularProgressIndicator());
      }

      if (groupMessageCnt.groupDataText.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum, size: 60, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                "No messages yet",
                style: TextStyle(color: Colors.grey[600], fontSize: 18),
              ),
              Text(
                "Send the first message!",
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        );
      }

      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView.builder(
          itemCount: groupMessageCnt.groupDataText.length,
          shrinkWrap: true,
          padding: EdgeInsets.only(top: 10, bottom: 10),
          controller: groupMessageCnt.scrollController,
          reverse: true,
          itemBuilder: (context, index) {
            return _buildMessageBubble(index);
          },
        ),
      );
    });
  }

  Widget _buildMessageBubble(int index) {
    final isCurrentUser =
        groupMessageCnt.groupDataText[index]["userMobilenumber"] ==
        groupMessageCnt.profileUserPhone;
    final message = groupMessageCnt.groupDataText[index];
    final timestamp = Jiffy.parse(message["dateTime"]);

    return Column(
      children: [
        // Date divider if needed
        if (_shouldShowDateDivider(index))
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              timestamp.format(pattern: 'MMMM d, yyyy'),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

        Container(
          padding: EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 4),
          child: Align(
            alignment:
                isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment:
                    isCurrentUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        message["username"],
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Material(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isCurrentUser ? 20 : 0),
                      topRight: Radius.circular(isCurrentUser ? 0 : 20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    elevation: 2,
                    color: isCurrentUser ? blue : white,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: GestureDetector(
                        onLongPress: () {
                          if (isCurrentUser) {
                            _showDeleteDialog(message);
                          }
                        },
                        child: Text(
                          message["message"],
                          style: TextStyle(
                            color: isCurrentUser ? white : black,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      timestamp.format(pattern: "hh:mm a"),
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowDateDivider(int index) {
    if (index == groupMessageCnt.groupDataText.length - 1) return false;

    final currentDate = Jiffy.parse(
      groupMessageCnt.groupDataText[index]["dateTime"],
    ).startOf(Unit.day);

    final prevDate = Jiffy.parse(
      groupMessageCnt.groupDataText[index + 1]["dateTime"],
    ).startOf(Unit.day);

    return !currentDate.isSame(prevDate);
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(left: 10, right: 10, bottom: 10, top: 10),
      decoration: BoxDecoration(
        color: white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: groupMessageCnt.messageController,
                focusNode: _messageFocusNode,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: InputBorder.none,
                  suffixIcon:
                      _isTyping
                          ? IconButton(
                            icon: Icon(Icons.close, size: 20),
                            onPressed: () {
                              groupMessageCnt.messageController.clear();
                              setState(() {
                                _isTyping = false;
                              });
                            },
                          )
                          : null,
                ),
                maxLines: 5,
                minLines: 1,
                onTap: groupMessageCnt.scrolltobottom,
              ),
            ),
          ),
          SizedBox(width: 8),
          Material(
            elevation: 2,
            shape: CircleBorder(),
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: _sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _isTyping ? blue : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isTyping ? Icons.send : Icons.mic,
                  color: white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (groupMessageCnt.messageController.text.trim().isEmpty) return;

    groupMessageCnt.addMessage(
      message: groupMessageCnt.messageController.text.trim(),
      groupKey: widget.groupKey,
    );
    groupMessageCnt.messageController.clear();
    groupMessageCnt.scrolltobottom();
    setState(() {
      _isTyping = false;
    });
  }

  void _navigateToGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GroupInformationScreen(
              information: [
                groupMessageCnt.admin.value,
                groupMessageCnt.groupName.value,
                widget.groupKey,
              ],
            ),
      ),
    );
  }

  void _showLeaveGroupDialog() {
    confirmDialogue(
      context,
      "Leave Group?",
      "Are you sure you want to leave this group?",
      _leaveGroup,
      () => Navigator.pop(context),
    );
  }

  void _leaveGroup() {
    if (profileDataModel?.mobileNumber == groupMessageCnt.admin.value) {
      flutterShowToast("Admins can't leave the group");
      Navigator.pop(context);
      return;
    }

    final updatedMembers = widget.groupMembers.replaceAll(
      "${profileDataModel?.mobileNumber}--",
      "",
    );

    groupMessageCnt.refGroups
        ?.child(widget.groupKey)
        .update({'members': updatedMembers})
        .then((_) {
          flutterShowToast("Group Left");
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(builder: (context) => const ChatScreen()),
          // );
        });
  }

  void _showDeleteDialog(Map message) {
    confirmDialogue(
      context,
      "Delete Message?",
      "Are you sure you want to delete this message?",
      () => _deleteMessage(message),
      () => Navigator.pop(context),
    );
  }

  void _deleteMessage(Map message) {
    groupMessageCnt.ref
        .child(widget.groupKey)
        .child('data')
        .child(message['messageKey'])
        .remove()
        .then((_) {
          flutterShowToast("Message Deleted");
          Navigator.pop(context);
          groupMessageCnt.getGroupData(groupKey: widget.groupKey);
        });
  }
}
