import 'package:fourmoral/models/message.dart';

class MediaItem {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String fileName;
  final MessageType type;
  final DateTime sentAt;
  final String senderId;

  MediaItem({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.fileName,
    required this.type,
    required this.sentAt,
    required this.senderId,
  });

  factory MediaItem.fromMessage(Message message) {
    return MediaItem(
      id: message.id,
      url: message.mediaUrl ?? '',
      fileName: message.fileInfo ?? 'Unknown',
      type: message.type,
      sentAt: message.sentAt,
      senderId: message.senderId,
    );
  }
}
