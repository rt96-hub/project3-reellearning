import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/video_comments_modal.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/class_selection_modal.dart';

class VideoActionButtons extends ConsumerStatefulWidget {
  final String videoId;

  const VideoActionButtons({
    super.key,
    required this.videoId,
  });

  @override
  ConsumerState<VideoActionButtons> createState() => _VideoActionButtonsState();
}

class _VideoActionButtonsState extends ConsumerState<VideoActionButtons> {
  bool isLiked = false;
  bool isBookmarked = false;
  
  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    _checkIfBookmarked();
  }
  
  @override
  void didUpdateWidget(VideoActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      // Reset state when video changes
      setState(() {
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

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isFilled = false,
    Color? fillColor,
  }) {
    return Container(
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
        // _buildActionButton(
        //   icon: Icons.share,
        //   onPressed: () {
        //     // Handle share action
        //   },
        // ),
      ],
    );
  }
}