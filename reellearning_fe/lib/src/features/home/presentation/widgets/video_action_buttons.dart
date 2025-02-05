import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/video_comments_modal.dart';

class VideoActionButtons extends ConsumerStatefulWidget {
  final String videoId;
  final int likeCount;

  const VideoActionButtons({
    super.key,
    required this.videoId,
    required this.likeCount,
  });

  @override
  ConsumerState<VideoActionButtons> createState() => _VideoActionButtonsState();
}

class _VideoActionButtonsState extends ConsumerState<VideoActionButtons> {
  bool isLiked = false;
  late int currentLikeCount;
  bool isBookmarked = false;
  
  @override
  void initState() {
    super.initState();
    currentLikeCount = widget.likeCount;
    _checkIfLiked();
  }
  
  @override
  void didUpdateWidget(VideoActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      // Reset state when video changes
      setState(() {
        currentLikeCount = widget.likeCount;
        isLiked = false;
        isBookmarked = false;
      });
      _checkIfLiked();
    }
  }

  Future<void> _checkIfLiked() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    final likeDoc = await FirebaseFirestore.instance
        .collection('userLikes')
        .doc('${userId}_${widget.videoId}')
        .get();

    if (mounted) {
      setState(() => isLiked = likeDoc.exists);
    }
  }

  Future<void> _handleLike() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    final likeId = '${userId}_${widget.videoId}';
    final likeRef = FirebaseFirestore.instance.collection('userLikes').doc(likeId);
    final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoId);

    // Start a batch write
    final batch = FirebaseFirestore.instance.batch();

    if (!isLiked) {
      // Add like document
      batch.set(likeRef, {
        'userId': userId,
        'videoId': widget.videoId,
        'likedAt': FieldValue.serverTimestamp(),
        // TODO: Implement class selection for likes
        // 'classId': selectedClassId,
      });

      // Get current video data first
      final videoDoc = await videoRef.get();
      final videoData = videoDoc.data() as Map<String, dynamic>;
      final engagement = videoData['engagement'] ?? {
        'likes': 0,
        'views': 0,
        'shares': 0,
        'completionRate': 0.0,
        'averageWatchTime': 0.0,
      };
      
      // Update entire engagement object
      batch.update(videoRef, {
        'engagement': {
          ...engagement,
          'likes': (engagement['likes'] ?? 0) + 1,
        }
      });

      setState(() {
        isLiked = true;
        currentLikeCount++;
      });
    } else {
      // Remove like document
      batch.delete(likeRef);

      // Get current video data first
      final videoDoc = await videoRef.get();
      final videoData = videoDoc.data() as Map<String, dynamic>;
      final engagement = videoData['engagement'] ?? {
        'likes': 0,
        'views': 0,
        'shares': 0,
        'completionRate': 0.0,
        'averageWatchTime': 0.0,
      };
      
      // Update entire engagement object
      batch.update(videoRef, {
        'engagement': {
          ...engagement,
          'likes': math.max<int>(0, (engagement['likes'] ?? 0) - 1),
        }
      });

      setState(() {
        isLiked = false;
        currentLikeCount--;
      });
    }

    // Commit the batch
    await batch.commit();
  }

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: VideoCommentsModal(videoId: widget.videoId),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isFilled = false,
    Color? fillColor,
    String? count,
  }) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isFilled ? fillColor ?? Colors.white : Colors.white,
              size: 28,
            ),
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        if (count != null)
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          onPressed: _handleLike,
          isFilled: isLiked,
          fillColor: Colors.red,
          count: currentLikeCount.toString(),
        ),
        _buildActionButton(
          icon: Icons.comment,
          onPressed: _showCommentsModal,
        ),
        _buildActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          onPressed: () => setState(() => isBookmarked = !isBookmarked),
          isFilled: isBookmarked,
          fillColor: Colors.white,
        ),
        _buildActionButton(
          icon: Icons.share,
          onPressed: () {
            // Handle share action
          },
        ),
      ],
    );
  }
} 