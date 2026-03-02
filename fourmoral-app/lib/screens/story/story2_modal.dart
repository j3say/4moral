import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Story2Model {
  final String id;
  final String userId;
  final String mobileNumber;
  final String mediaUrl;
  final StoryType type;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String caption; // Added caption field
  final List<String> viewedBy;
  final List<String> restrictedUsers;
  final String? thumbnailUrl;

  Story2Model({
    required this.id,
    required this.userId,
    required this.mobileNumber,
    required this.mediaUrl,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    this.thumbnailUrl,
    this.caption = '', // Added with default empty string
    this.viewedBy = const [],
    this.restrictedUsers = const [],
  });

  factory Story2Model.fromJson(Map<String, dynamic> json) {
    try {
      // Parse with null checks and fallback values
      return Story2Model(
        id: _parseString(json['id'], fallback: ''),
        userId: _parseString(json['userId'], fallback: ''),
        mobileNumber: _parseString(json['mobileNumber'], fallback: ''),
        mediaUrl: _parseString(json['mediaUrl'], fallback: ''),
        type: _parseStoryType(json['type']),
        thumbnailUrl: json['thumbnailUrl'],
        createdAt: _parseDateTime(json['createdAt']),
        expiresAt: _parseDateTime(json['expiresAt'], 
                   fallback: DateTime.now().add(const Duration(hours: 24))),
        caption: _parseString(json['caption']), // Added caption parsing
        viewedBy: _parseStringList(json['viewedBy']),
        restrictedUsers: _parseStringList(json['restrictedUsers']),
      );
    } catch (e) {
      debugPrint('Error parsing Story2Model: $e');
      // Return a default valid story model if parsing fails
      return Story2Model(
        id: '',
        userId: '',
        mobileNumber: '',
        mediaUrl: '',
        type: StoryType.image,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        caption: '', // Added to default
        viewedBy: const [],
        restrictedUsers: const [],
      );
    }
  }

  // Helper methods for safe parsing
  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static StoryType _parseStoryType(dynamic value) {
    if (value == null) return StoryType.image;
    if (value.toString().toLowerCase() == 'video') return StoryType.video;
    return StoryType.image;
  }

  static DateTime _parseDateTime(dynamic value, {DateTime? fallback}) {
    try {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return fallback ?? DateTime.now();
    } catch (e) {
      return fallback ?? DateTime.now();
    }
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    try {
      return List<String>.from(value);
    } catch (e) {
      return const [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mobileNumber': mobileNumber,
      'mediaUrl': mediaUrl,
      'thumbnailUrl' : thumbnailUrl,
      'type': type == StoryType.image ? 'image' : 'video',
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'caption': caption, // Added caption to JSON
      'viewedBy': viewedBy,
      'restrictedUsers': restrictedUsers,
    };
  }

  Story2Model copyWith({
    String? id,
    String? userId,
    String? mobileNumber,
    String? mediaUrl,
    StoryType? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? caption, // Added caption to copyWith
    List<String>? viewedBy,
    List<String>? restrictedUsers,
    String? thumbnailUrl
  }) {
    return Story2Model(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      caption: caption ?? this.caption, // Added caption
      viewedBy: viewedBy ?? this.viewedBy,
      restrictedUsers: restrictedUsers ?? this.restrictedUsers,
    );
  }
}

enum StoryType { image, video }