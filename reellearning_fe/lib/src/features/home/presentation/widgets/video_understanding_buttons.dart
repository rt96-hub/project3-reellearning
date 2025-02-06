import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoUnderstandingButtons extends StatelessWidget {
  final String videoId;
  final String? classId;

  const VideoUnderstandingButtons({
    super.key, 
    required this.videoId,
    this.classId,
  });

  Future<void> _updateComprehension(String level) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = '${user.uid}_$videoId';
    final docRef = FirebaseFirestore.instance.collection('videoComprehension').doc(docId);
    
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);
        
        if (docSnapshot.exists) {
          // Update existing document
          final currentData = docSnapshot.data() as Map<String, dynamic>;
          final currentClassIds = List<String>.from(currentData['classId'] ?? []);
          
          // Only append classId if it's provided and not already in the array
          if (classId != null && !currentClassIds.contains(classId)) {
            currentClassIds.add(classId!);
          }
          
          transaction.update(docRef, {
            'comprehensionLevel': level,
            'updatedAt': now,
            'classId': currentClassIds,
            'nextRecommendedReview': _calculateNextReview(level, now),
          });
        } else {
          // Create new document
          final data = {
            'userId': user.uid,
            'videoId': videoId,
            'classId': classId != null ? [classId] : [],
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
          onPressed: () => _updateComprehension('not_understood'),
        ),
        _buildUnderstandingButton(
          emoji: '🤔',
          color: Colors.amber.shade400,
          onPressed: () => _updateComprehension('partially_understood'),
        ),
        _buildUnderstandingButton(
          emoji: '🧠',
          color: Colors.green.shade400,
          onPressed: () => _updateComprehension('fully_understood'),
        ),
      ],
    );
  }
}