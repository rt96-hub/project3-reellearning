import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';

class VideoCommentsModal extends ConsumerStatefulWidget {
  final String videoId;

  const VideoCommentsModal({
    super.key,
    required this.videoId,
  });

  @override
  ConsumerState<VideoCommentsModal> createState() => _VideoCommentsModalState();
}

class _VideoCommentsModalState extends ConsumerState<VideoCommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not authenticated');

      // Create the comment
      final commentData = {
        'videoId': widget.videoId,
        'author': {
          'ref': FirebaseFirestore.instance.collection('users').doc(user.uid),
          'uid': user.uid,  // Store UID directly for easier rule validation
        },
        'content': {
          'text': _commentController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),  // Use server timestamp
          'attachments': []
        },
        'likeCount': 0,
        'metadata': {
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isEdited': false,
          'isPinned': false,
          'isResolved': false
        },
      };

      await FirebaseFirestore.instance.collection('videoComments').add(commentData);

      if (mounted) {
        _commentController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleLike(String commentId, bool isLiked) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not authenticated');

      final firestore = FirebaseFirestore.instance;
      final commentRef = firestore.collection('videoComments').doc(commentId);
      final likeId = '${user.uid}_$commentId';
      final likeRef = firestore.collection('commentLikes').doc(likeId);

      await firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final currentLikeCount = commentDoc.data()?['likeCount'] ?? 0;
        
        if (isLiked) {
          // Add like
          transaction.set(likeRef, {
            'userId': firestore.collection('users').doc(user.uid),
            'commentId': commentRef,
            'likedAt': FieldValue.serverTimestamp()
          });
          transaction.update(commentRef, {
            'likeCount': currentLikeCount + 1
          });
        } else {
          // Remove like
          transaction.delete(likeRef);
          transaction.update(commentRef, {
            'likeCount': currentLikeCount - 1
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling like: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Comments List
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('videoComments')
                  .where('videoId', isEqualTo: widget.videoId)
                  .orderBy('likeCount', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;
                
                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final commentData = comment.data() as Map<String, dynamic>;
                    
                    return FutureBuilder(
                      future: (commentData['author']['ref'] as DocumentReference).get(),
                      builder: (context, authorSnapshot) {
                        final authorName = authorSnapshot.hasData
                            ? (authorSnapshot.data!.data() as Map<String, dynamic>)?['profile']?['displayName'] ?? 'Anonymous'
                            : 'Loading...';

                        return StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('commentLikes')
                              .doc('${ref.read(currentUserProvider)?.uid}_${comment.id}')
                              .snapshots(),
                          builder: (context, likeSnapshot) {
                            final isLiked = likeSnapshot.hasData && likeSnapshot.data!.exists;

                            return Card(
                              color: Colors.grey[900],
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          authorName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${commentData['likeCount']} likes',
                                          style: TextStyle(color: Colors.grey[400]),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isLiked ? Icons.favorite : Icons.favorite_border,
                                            color: isLiked ? Colors.red : Colors.grey[400],
                                          ),
                                          onPressed: () => _toggleLike(comment.id, !isLiked),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      commentData['content']['text'],
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        );
                      }
                    );
                  },
                );
              },
            ),
          ),

          // Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                top: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: _isSubmitting ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 