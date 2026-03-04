import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/models/post_model.dart';
import 'package:fourmoral/screens/postViewScreen/post_view_screen.dart';
import 'package:intl/intl.dart';

class HashtagPage extends StatefulWidget {
  final String hashtag;

  const HashtagPage({super.key, required this.hashtag});

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _postsStream;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;
  final List<PostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
  }

  void _loadInitialPosts() {
    _postsStream =
        _firestore
            .collection('Posts')
            .where('caption', isGreaterThanOrEqualTo: '#${widget.hashtag}')
            .where('caption', isLessThan: '#${widget.hashtag}z')
            .orderBy('caption')
            .limit(10)
            .snapshots();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        !_isLoading) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || _lastDocument == null) return;
    setState(() => _isLoading = true);

    try {
      final query = _firestore
          .collection('Posts')
          .where('caption', isGreaterThanOrEqualTo: '#${widget.hashtag}')
          .where('caption', isLessThan: '#${widget.hashtag}z')
          .orderBy('caption')
          .startAfterDocument(_lastDocument!)
          .limit(10);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newPosts =
            snapshot.docs.map((doc) {
              return PostModel.fromJson({...doc.data(), 'key': doc.id});
            }).toList();

        setState(() {
          _posts.addAll(newPosts);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading more posts: $e');
    }
  }

  bool _containsHashtag(String caption) {
    if (caption.isEmpty) return false;
    final hashtags =
        caption
            .split(' ')
            .where((word) => word.startsWith('#'))
            .map((hashtag) => hashtag.toLowerCase())
            .toList();
    return hashtags.contains('#${widget.hashtag.toLowerCase()}');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '#${widget.hashtag}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found for this hashtag'));
          }

          // Filter posts to ensure they contain the exact hashtag
          final filteredDocs =
              snapshot.data!.docs.where((doc) {
                final caption = doc['caption'] as String? ?? '';
                return _containsHashtag(caption);
              }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('No posts found for this hashtag'));
          }

          // Update last document for pagination
          _lastDocument = filteredDocs.last;

          // Convert to PostModel list
          final posts =
              filteredDocs.map((doc) {
                return PostModel.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'key': doc.id,
                });
              }).toList();

          // Add to existing posts if not already present
          for (final post in posts) {
            if (!_posts.any((p) => p.key == post.key)) {
              _posts.add(post);
            }
          }

          return ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: _posts.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _posts.length) {
                return const Center(child: CircularProgressIndicator());
              }

              final post = _posts[index];
              return _PostCard(post: post);
            },
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostViewScreen(postId: post.key),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: 6,
              color: Colors.grey.withOpacity(0.2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.urls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: CachedNetworkImage(
                  imageUrl: post.urls.first,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, size: 50),
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            post.profilePicture != null
                                ? CachedNetworkImageProvider(
                                  post.profilePicture,
                                )
                                : null,
                        child:
                            post.profilePicture == null
                                ? const Icon(Icons.person, size: 16)
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.username ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.caption ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 20),
                      const SizedBox(width: 4),
                      const SizedBox(width: 16),
                      const Icon(Icons.comment_outlined, size: 20),
                      const SizedBox(width: 4),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
