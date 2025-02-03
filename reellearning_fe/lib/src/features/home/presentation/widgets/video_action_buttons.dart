import 'package:flutter/material.dart';

class VideoActionButtons extends StatefulWidget {
  const VideoActionButtons({super.key});

  @override
  State<VideoActionButtons> createState() => _VideoActionButtonsState();
}

class _VideoActionButtonsState extends State<VideoActionButtons> {
  bool isLiked = false;
  bool isBookmarked = false;

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isFilled = false,
    Color? fillColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          onPressed: () => setState(() => isLiked = !isLiked),
          isFilled: isLiked,
          fillColor: Colors.red,
        ),
        _buildActionButton(
          icon: Icons.comment,
          onPressed: () {
            // Handle comment action
          },
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