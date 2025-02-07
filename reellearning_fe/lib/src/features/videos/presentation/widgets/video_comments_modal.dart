import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
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
  String? _replyToCommentId;

  // Cache for optimistic updates
  final Map<String, int> _optimisticLikeCounts = {};
  final Map<String, bool> _optimisticLikeStates = {};
  final Map<String, int> _optimisticReplyCounts = {};

  // Track expanded replies
  final Set<String> _expandedReplies = {};

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

      final firestore = FirebaseFirestore.instance;

      if (_replyToCommentId != null) {
        // Optimistically update reply count
        setState(() {
          _optimisticReplyCounts[_replyToCommentId!] = (_optimisticReplyCounts[_replyToCommentId!] ?? 0) + 1;
        });

        // First create the reply
        final replyData = {
          'commentId': _replyToCommentId,
          'author': {
            'ref': firestore.collection('users').doc(user.uid),
            'uid': user.uid,
          },
          'content': {
            'text': _commentController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'attachments': []
          },
          'likeCount': 0,
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isEdited': false,
          },
        };

        // Create reply document first
        final replyRef = await firestore.collection('commentReplies').add(replyData);

        // Then update the parent comment
        final commentRef = firestore.collection('videoComments').doc(_replyToCommentId);
        await commentRef.update({
          'hasReplies': true,
          'replyCount': FieldValue.increment(1),
          'replies': FieldValue.arrayUnion([replyRef.id]),
        });

        if (mounted) {
          setState(() => _replyToCommentId = null);
        }
      } else {
        // Create a new comment
        final commentData = {
          'videoId': widget.videoId,
          'author': {
            'ref': firestore.collection('users').doc(user.uid),
            'uid': user.uid,
          },
          'content': {
            'text': _commentController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
            'attachments': []
          },
          'likeCount': 0,
          'hasReplies': false,
          'replyCount': 0,
          'replies': [],
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isEdited': false,
            'isPinned': false,
            'isResolved': false
          },
        };

        await firestore.collection('videoComments').add(commentData);
      }

      if (mounted) {
        _commentController.clear();
      }
    } catch (e) {
      // Revert optimistic updates on error
      if (_replyToCommentId != null) {
        setState(() {
          _optimisticReplyCounts.remove(_replyToCommentId);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting ${_replyToCommentId != null ? 'reply' : 'comment'}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleLike(String commentId, bool isLiked) async {
    // Optimistically update UI
    setState(() {
      _optimisticLikeStates[commentId] = isLiked;
      _optimisticLikeCounts[commentId] = (_optimisticLikeCounts[commentId] ?? 0) + (isLiked ? 1 : -1);
    });

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
          transaction.set(likeRef, {
            'userId': firestore.collection('users').doc(user.uid),
            'commentId': commentRef,
            'likedAt': FieldValue.serverTimestamp()
          });
          transaction.update(commentRef, {
            'likeCount': currentLikeCount + 1
          });
        } else {
          transaction.delete(likeRef);
          transaction.update(commentRef, {
            'likeCount': currentLikeCount - 1
          });
        }
      });
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _optimisticLikeStates.remove(commentId);
        _optimisticLikeCounts.remove(commentId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling like: $e')),
        );
      }
    }
  }

  Future<void> _toggleReplyLike(String replyId, bool isLiked) async {
    // Optimistically update UI
    setState(() {
      _optimisticLikeStates[replyId] = isLiked;
      _optimisticLikeCounts[replyId] = (_optimisticLikeCounts[replyId] ?? 0) + (isLiked ? 1 : -1);
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not authenticated');

      final firestore = FirebaseFirestore.instance;
      final replyRef = firestore.collection('commentReplies').doc(replyId);
      final likeId = '${user.uid}_$replyId';
      final likeRef = firestore.collection('commentReplyLikes').doc(likeId);

      await firestore.runTransaction((transaction) async {
        final replyDoc = await transaction.get(replyRef);

        if (!replyDoc.exists) {
          throw Exception('Reply not found');
        }

        final currentLikeCount = replyDoc.data()?['likeCount'] ?? 0;

        if (isLiked) {
          transaction.set(likeRef, {
            'userId': firestore.collection('users').doc(user.uid),
            'replyId': replyRef,
            'likedAt': FieldValue.serverTimestamp()
          });
          transaction.update(replyRef, {
            'likeCount': currentLikeCount + 1
          });
        } else {
          transaction.delete(likeRef);
          transaction.update(replyRef, {
            'likeCount': currentLikeCount - 1
          });
        }
      });
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _optimisticLikeStates.remove(replyId);
        _optimisticLikeCounts.remove(replyId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling reply like: $e')),
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                        final authorData = authorSnapshot.hasData
                            ? ((authorSnapshot.data!.data() as Map<String, dynamic>)?['profile'] as Map<String, dynamic>?) ?? {}
                            : <String, dynamic>{};
                        final authorName = authorData['displayName'] ?? 'Anonymous';
                        final authorId = (commentData['author']['ref'] as DocumentReference).id;

                        return StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('commentLikes')
                              .doc('${ref.read(currentUserProvider)?.uid}_${comment.id}')
                              .snapshots(),
                          builder: (context, likeSnapshot) {
                            final isLiked = _optimisticLikeStates[comment.id] ??
                                (likeSnapshot.hasData && likeSnapshot.data!.exists);
                            final likeCount = _optimisticLikeCounts[comment.id] ?? (commentData['likeCount'] ?? 0);

                            return Card(
                              color: Colors.grey[900],
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => context.go('/profile/$authorId'),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundImage: authorData['avatarUrl'] != null
                                                    ? NetworkImage(authorData['avatarUrl'] as String)
                                                    : null,
                                                child: authorData['avatarUrl'] == null
                                                    ? const Icon(Icons.person, size: 16)
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                authorName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '$likeCount likes',
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
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.reply, size: 16),
                                          label: const Text('Reply'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey[400],
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          onPressed: () {
                                            setState(() => _replyToCommentId = comment.id);
                                            _commentController.text = '';
                                            FocusScope.of(context).requestFocus(FocusNode());
                                          },
                                        ),
                                        if (commentData['hasReplies'] == true)
                                          TextButton.icon(
                                            icon: Icon(
                                              _expandedReplies.contains(comment.id)
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              size: 16
                                            ),
                                            label: Text('${_optimisticReplyCounts[comment.id] ?? commentData['replyCount']} Replies'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.grey[400],
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (_expandedReplies.contains(comment.id)) {
                                                  _expandedReplies.remove(comment.id);
                                                } else {
                                                  _expandedReplies.add(comment.id);
                                                }
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                    if (_expandedReplies.contains(comment.id))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Container(
                                          margin: const EdgeInsets.only(left: 16),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: Colors.grey[800]!,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          child: _CommentRepliesList(
                                            commentId: comment.id,
                                            optimisticLikeCounts: _optimisticLikeCounts,
                                            optimisticLikeStates: _optimisticLikeStates,
                                            onToggleLike: _toggleReplyLike,
                                            onReply: () {
                                              setState(() => _replyToCommentId = comment.id);
                                              _commentController.text = '';
                                              FocusScope.of(context).requestFocus(FocusNode());
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToCommentId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Replying to comment',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          color: Colors.white70,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _replyToCommentId = null),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: _replyToCommentId != null ? 'Write a reply...' : 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.grey),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRepliesList extends ConsumerWidget {
  final String commentId;
  final Map<String, int> optimisticLikeCounts;
  final Map<String, bool> optimisticLikeStates;
  final Future<void> Function(String, bool) onToggleLike;
  final VoidCallback onReply;

  const _CommentRepliesList({
    required this.commentId,
    required this.optimisticLikeCounts,
    required this.optimisticLikeStates,
    required this.onToggleLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('commentReplies')
          .where('commentId', isEqualTo: commentId)
          .orderBy('likeCount', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final replies = snapshot.data!.docs;

        if (replies.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No replies yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(right: 16),
          itemCount: replies.length,
          itemBuilder: (context, index) {
            final reply = replies[index];
            final replyData = reply.data();

            return FutureBuilder(
              future: (replyData['author']['ref'] as DocumentReference).get(),
              builder: (context, authorSnapshot) {
                final authorData = authorSnapshot.hasData
                    ? ((authorSnapshot.data!.data() as Map<String, dynamic>)?['profile'] as Map<String, dynamic>?) ?? {}
                    : <String, dynamic>{};
                final authorName = authorData['displayName'] ?? 'Anonymous';
                final authorId = (replyData['author']['ref'] as DocumentReference).id;

                return Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/profile/$authorId'),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: authorData['avatarUrl'] != null
                                    ? NetworkImage(authorData['avatarUrl'] as String)
                                    : null,
                                child: authorData['avatarUrl'] == null
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                authorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          replyData['content']['text'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            StreamBuilder(
                              stream: FirebaseFirestore.instance
                                  .collection('commentReplyLikes')
                                  .doc('${ref.read(currentUserProvider)?.uid}_${reply.id}')
                                  .snapshots(),
                              builder: (context, likeSnapshot) {
                                final isLiked = optimisticLikeStates[reply.id] ??
                                    (likeSnapshot.hasData && likeSnapshot.data!.exists);
                                final likeCount = optimisticLikeCounts[reply.id] ??
                                    (replyData['likeCount'] ?? 0);

                                return Row(
                                  children: [
                                    Text(
                                      '$likeCount likes',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : Colors.grey[400],
                                      ),
                                      onPressed: () => onToggleLike(reply.id, !isLiked),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}