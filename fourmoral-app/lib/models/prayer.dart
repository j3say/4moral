// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

class Prayer {
  final String id;
  final String title;
  final String audioUrl;
  final String userId;
  final List<String> subscribers; // Changed from nullable to empty list default
  final DateTime createdAt;
  final DateTime expiresAt;

  Prayer({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.userId,
    List<String>? subscribers, // Optional parameter
    required this.createdAt,
    required this.expiresAt,
  }) : subscribers = subscribers ?? []; // Default empty list

  factory Prayer.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Prayer(
      id: doc.id,
      title: data['title'] as String? ?? '', // Added type cast
      audioUrl: data['audioUrl'] as String? ?? '', // Added type cast
      userId: data['userId'] as String, // Added type cast
      subscribers: _parseSubscribers(data['subscribers']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  static List<String> _parseSubscribers(dynamic subscribers) {
    if (subscribers == null) return [];
    if (subscribers is List) {
      return subscribers.whereType<String>().toList();
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'audioUrl': audioUrl,
      'userId': userId,
      'subscribers': subscribers,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}