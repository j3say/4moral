import 'dart:developer';

// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/announcement.dart';
import 'package:fourmoral/services/announcement_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timeago/timeago.dart' as timeago;

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  _AnnouncementListScreenState createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  final _announcementService = AnnouncementService();
  final _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    // Set up task to check for expired announcements
    _announcementService.setupExpirationTask();

    // Listen for audio player completion
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentlyPlayingId = null;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio(String announcementId, String audioUrl) async {
    if (_currentlyPlayingId == announcementId) {
      // Stop playing
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingId = null;
      });
    } else {
      // Start playing
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
      setState(() {
        _currentlyPlayingId = announcementId;
      });
    }
  }

  String _getExpiryText(DateTime expiresAt) {
    final duration = expiresAt.difference(DateTime.now());
    if (duration.inHours > 0) {
      return 'Expires in ${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return 'Expires in ${duration.inMinutes}m';
    } else {
      return 'Expiring soon';
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    try {
      await _announcementService.deleteAnnouncement(announcementId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Announcement deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete announcement: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: StreamBuilder<List<Announcement>>(
        stream: _announcementService.getActiveAnnouncementsForUser(
          currentUserId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final announcements = snapshot.data ?? [];

          if (announcements.isEmpty) {
            return const Center(child: Text('No active announcements'));
          }

          return ListView.builder(
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              log("announcement $announcement");
              final isPlaying = _currentlyPlayingId == announcement.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                        announcement.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Created ${timeago.format(announcement.createdAt)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getExpiryText(announcement.expiresAt),
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                () => _deleteAnnouncement(announcement.id),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 48,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed:
                                () => _playAudio(
                                  announcement.id,
                                  announcement.audioUrl,
                                ),
                          ),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  isPlaying
                                      ? LinearProgressIndicator(
                                        backgroundColor: Colors.grey[300],
                                        color: Theme.of(context).primaryColor,
                                      )
                                      : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
