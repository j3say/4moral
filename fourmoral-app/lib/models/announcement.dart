// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

class Announcement {
  final String id;
  final String title;
  final String audioUrl;
  final String userId;
  final List<String> subscribers; // Changed from nullable to empty list default
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic>? schedule;

  Announcement({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.userId,
    List<String>? subscribers, // Optional parameter
    required this.createdAt,
    required this.expiresAt,
    this.schedule,
  }) : subscribers = subscribers ?? []; // Default empty list

  factory Announcement.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Announcement(
      id: doc.id,
      title: data['title'] as String? ?? '', // Added type cast
      audioUrl: data['audioUrl'] as String? ?? '', // Added type cast
      userId: data['userId'] as String? ?? '',
      subscribers: _parseSubscribers(data['subscribers']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      schedule: data['schedule'] as Map<String, dynamic>? ?? {},
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
      'schedule': schedule,
    };
  }

  bool isScheduled() {
    return schedule != null;
  }

  bool shouldShowToday() {
    if (schedule == null) return true;

    final now = DateTime.now();
    if (schedule!['type'] == 'dates') {
      final dates = (schedule!['dates'] as List).map(
        (t) => (t as Timestamp).toDate(),
      );
      return dates.any((date) => _isSameDay(date, now));
    } else {
      final days = schedule!['days'] as List<dynamic>;
      return days.contains(now.weekday);
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
