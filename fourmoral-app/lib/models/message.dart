import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, file }

class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final String? mediaUrl;
  final String? fileInfo;
  final bool isDeleted;
  final bool deletedForEveryone;
  final Message? repliedTo;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.sentAt,
    this.mediaUrl,
    this.fileInfo,
    this.isDeleted = false,
    this.deletedForEveryone = false,
    this.repliedTo,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      sentAt: (map['sentAt'] as Timestamp).toDate(),
      mediaUrl: map['mediaUrl'],
      fileInfo: map['fileInfo'],
      isDeleted: map['isDeleted'] ?? false,
      deletedForEveryone: map['deletedForEveryone'] ?? false,
      repliedTo:
          map['repliedTo'] != null
              ? Message.fromMap(map['repliedTo'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'content': content,
      'type': type.toString().split('.').last,
      'sentAt': sentAt,
      'isDeleted': isDeleted,
      'deletedForEveryone': deletedForEveryone,
      'repliedTo': repliedTo?.toMap(),
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (fileInfo != null) 'fileInfo': fileInfo,
    };
  }
}
