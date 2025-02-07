import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoUnderstandingButtons extends StatefulWidget {
  final String videoId;
  final String? classId;

  const VideoUnderstandingButtons({
    super.key, 
    required this.videoId,
    this.classId,
  });

  @override
  State<VideoUnderstandingButtons> createState() => _VideoUnderstandingButtonsState();
}

class _VideoUnderstandingButtonsState extends State<VideoUnderstandingButtons> {
  final Map<String, bool> _buttonCooldowns = {};
  final List<OverlayEntry> _activeOverlays = [];

  @override
  void dispose() {
    // Clean up any active overlays when the widget is disposed
    for (final overlay in _activeOverlays) {
      overlay.remove();
    }
    _activeOverlays.clear();
    super.dispose();
  }

  void _showFloatingEmoji(String emoji, Offset startPosition) {
    late final OverlayEntry overlay;
    
    overlay = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (context, value, child) {
            return Positioned(
              left: startPosition.dx,
              top: startPosition.dy - (value * 100), // Float upwards
              child: Opacity(
                opacity: 1.0 - value, // Fade out
                child: Transform.scale(
                  scale: 1.0 + (value * 0.5), // Slightly scale up
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            );
          },
          onEnd: () {
            overlay.remove();
            _activeOverlays.remove(overlay);
          },
        );
      },
    );

    _activeOverlays.add(overlay);
    Overlay.of(context).insert(overlay);
  }

  Future<void> _handleButtonPress(String level, String emoji, Offset position) async {
    // Check cooldown
    if (_buttonCooldowns[level] == true) return;

    // Set cooldown
    setState(() => _buttonCooldowns[level] = true);
    
    // Show floating emoji
    _showFloatingEmoji(emoji, position);
    
    // Update comprehension
    await _updateComprehension(level);
    
    // Reset cooldown after delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _buttonCooldowns[level] = false);
    }
  }

  Future<void> _updateComprehension(String level) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = '${user.uid}_${widget.videoId}';
    final docRef = FirebaseFirestore.instance.collection('videoComprehension').doc(docId);
    
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);
        
        if (docSnapshot.exists) {
          final currentData = docSnapshot.data() as Map<String, dynamic>;
          final currentClassIds = List<String>.from(currentData['classId'] ?? []);
          
          if (widget.classId != null && !currentClassIds.contains(widget.classId)) {
            currentClassIds.add(widget.classId!);
          }
          
          transaction.update(docRef, {
            'comprehensionLevel': level,
            'updatedAt': now,
            'classId': currentClassIds,
            'nextRecommendedReview': _calculateNextReview(level, now),
          });
        } else {
          final data = {
            'userId': user.uid,
            'videoId': widget.videoId,
            'classId': widget.classId != null ? [widget.classId] : [],
            'comprehensionLevel': level,
            'assessedAt': now,
            'updatedAt': now,
            'nextRecommendedReview': _calculateNextReview(level, now),
          };
          
          transaction.set(docRef, data);
        }
      });
    } catch (e) {
      debugPrint('Error updating comprehension: $e');
    }
  }

  Timestamp _calculateNextReview(String level, Timestamp now) {
    final DateTime currentTime = now.toDate();
    switch (level) {
      case 'not_understood':
        return Timestamp.fromDate(currentTime.add(const Duration(hours: 4)));
      case 'partially_understood':
        return Timestamp.fromDate(currentTime.add(const Duration(days: 1)));
      case 'fully_understood':
        return Timestamp.fromDate(currentTime.add(const Duration(days: 3)));
      default:
        return Timestamp.fromDate(currentTime.add(const Duration(days: 1)));
    }
  }

  Widget _buildUnderstandingButton({
    required String emoji,
    required Color color,
    required String level,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: _buttonCooldowns[level] == true
                ? null
                : () {
                    final RenderBox renderBox = context.findRenderObject() as RenderBox;
                    final position = renderBox.localToGlobal(Offset.zero);
                    _handleButtonPress(level, emoji, position);
                  },
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
          );
        }
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
          level: 'not_understood',
        ),
        _buildUnderstandingButton(
          emoji: '🤔',
          color: Colors.amber.shade400,
          level: 'partially_understood',
        ),
        _buildUnderstandingButton(
          emoji: '🧠',
          color: Colors.green.shade400,
          level: 'fully_understood',
        ),
      ],
    );
  }
}