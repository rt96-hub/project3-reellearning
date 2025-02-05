import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final double duration;
  final DateTime uploadedAt;
  final DateTime updatedAt;
  final DocumentReference creator;
  final VideoEngagement engagement;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.uploadedAt,
    required this.updatedAt,
    required this.creator,
    required this.engagement,
  });

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Safely access nested metadata
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final videoUrl = metadata['videoUrl'] as String? ?? '';
    
    print('Raw videoUrl from Firestore: $videoUrl'); // Debug log
    print('Raw engagement data: ${data['engagement']}'); // Debug engagement data
    
    return VideoModel(
      id: doc.id,
      title: metadata['title'] ?? '',
      description: metadata['description'] ?? '',
      videoUrl: videoUrl,
      thumbnailUrl: metadata['thumbnailUrl'] ?? '',
      duration: (metadata['duration'] ?? 0).toDouble(),
      uploadedAt: (metadata['uploadedAt'] as Timestamp).toDate(),
      updatedAt: (metadata['updatedAt'] as Timestamp).toDate(),
      creator: data['creator'] as DocumentReference? ?? FirebaseFirestore.instance.doc('users/unknown'),
      engagement: VideoEngagement.fromMap(data['engagement'] as Map<String, dynamic>? ?? {
        'views': 0,
        'likes': 0,
        'shares': 0,
        'completionRate': 0.0,
        'averageWatchTime': 0.0,
      }),
    );
  }

  // Helper method to get the actual download URL when needed
  Future<String> getDownloadUrl() async {
    if (videoUrl.isEmpty) {
      print('Empty video URL');
      return '';
    }
    
    if (!videoUrl.startsWith('gs://')) {
      return videoUrl;
    }
    
    try {
      print('Converting gs:// URL to download URL: $videoUrl'); // Debug log
      final storage = FirebaseStorage.instance;
      final gsReference = storage.refFromURL(videoUrl);
      final downloadUrl = await gsReference.getDownloadURL();
      print('Generated download URL: $downloadUrl'); // Debug log
      return downloadUrl;
    } catch (e) {
      print('Error getting download URL: $e');
      return '';
    }
  }

  // Comment out local testing constructor
  /*
  factory VideoModel.local({
    String id = 'local_1',
    String title = 'Sample Video',
    String description = 'This is a local test video',
  }) {
    return VideoModel(
      id: id,
      title: title,
      description: description,
      videoUrl: 'assets/videos/sample_phone.mp4',  // Local asset path
      thumbnailUrl: '',
      creator: FirebaseFirestore.instance.doc('users/test_user'),
      uploadedAt: DateTime.now(),
    );
  }
  */

  bool get isPlayable {
    return videoUrl.isNotEmpty && (
      // videoUrl.startsWith('assets/') || 
      videoUrl.startsWith('http') || 
      videoUrl.startsWith('https') || 
      videoUrl.startsWith('gs://')
    );
  }
}

class VideoEngagement {
  final int views;
  final int likes;
  final int shares;
  final double completionRate;
  final double averageWatchTime;

  VideoEngagement({
    required this.views,
    required this.likes,
    required this.shares,
    required this.completionRate,
    required this.averageWatchTime,
  });

  factory VideoEngagement.fromMap(Map<String, dynamic> map) {
    return VideoEngagement(
      views: map['views'] ?? 0,
      likes: map['likes'] ?? 0,
      shares: map['shares'] ?? 0,
      completionRate: (map['completionRate'] ?? 0).toDouble(),
      averageWatchTime: (map['averageWatchTime'] ?? 0).toDouble(),
    );
  }
} 