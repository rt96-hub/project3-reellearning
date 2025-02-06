import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/video_comments_modal.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/class_selection_modal.dart';

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
    _checkIfBookmarked();
    _setupLikeCountListener();
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
      _checkIfBookmarked();
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

  Future<void> _checkIfBookmarked() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    final bookmarkDoc = await FirebaseFirestore.instance
        .collection('userBookmarks')
        .doc('${userId}_${widget.videoId}')
        .get();

    if (mounted) {
      setState(() => isBookmarked = bookmarkDoc.exists);
    }
  }

  Future<void> _handleLike() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => ClassSelectionModal(
        videoId: widget.videoId,
        interactionType: InteractionType.like,
        onInteractionChanged: (isSelected) {
          setState(() {
            isLiked = isSelected;
          });
        },
      ),
    );
  }

  Future<void> _handleBookmark() async {
    final userId = ref.read(currentUserProvider)?.uid;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => ClassSelectionModal(
        videoId: widget.videoId,
        interactionType: InteractionType.bookmark,
        onInteractionChanged: (isSelected) {
          setState(() {
            isBookmarked = isSelected;
          });
        },
      ),
    );
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

  void _setupLikeCountListener() {
    FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final engagement = data['engagement'] ?? {};
        setState(() {
          currentLikeCount = engagement['likes'] ?? 0;
        });
      }
    });
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
          count: currentLikeCount > 0 ? currentLikeCount.toString() : null,
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          onPressed: _handleBookmark,
          isFilled: isBookmarked,
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          icon: Icons.comment,
          onPressed: _showCommentsModal,
        ),
        const SizedBox(height: 8),
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