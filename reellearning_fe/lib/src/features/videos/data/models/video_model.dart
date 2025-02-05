import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final DocumentReference creator;
  final DateTime uploadedAt;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.creator,
    required this.uploadedAt,
  });

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Safely access nested metadata
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final videoUrl = metadata['videoUrl'] as String? ?? '';
    
    print('Raw videoUrl from Firestore: $videoUrl'); // Debug log
    
    return VideoModel(
      id: doc.id,
      title: metadata['title'] ?? '',
      description: metadata['description'] ?? '',
      videoUrl: videoUrl,
      thumbnailUrl: metadata['thumbnailUrl'] ?? '',
      creator: data['creator'] as DocumentReference,
      uploadedAt: (metadata['uploadedAt'] as Timestamp).toDate(),
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