import 'package:flutter/material.dart';

class VideoUnderstandingButtons extends StatelessWidget {
  const VideoUnderstandingButtons({super.key});

  Widget _buildUnderstandingButton({
    required String emoji,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildUnderstandingButton(
          emoji: '❓',
          color: Colors.red.shade400,
          onPressed: () {
            // Handle question button press
          },
        ),
        _buildUnderstandingButton(
          emoji: '🤔',
          color: Colors.amber.shade400,
          onPressed: () {
            // Handle thinking button press
          },
        ),
        _buildUnderstandingButton(
          emoji: '🧠',
          color: Colors.green.shade400,
          onPressed: () {
            // Handle understanding button press
          },
        ),
      ],
    );
  }
} 