import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_model.dart';
import 'package:firebase_storage/firebase_storage.dart';

final videoProvider = StreamProvider.autoDispose((ref) {
  return FirebaseFirestore.instance
      .collection('videos')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => VideoModel.fromFirestore(doc))
          .toList());
});

// Provider for a single random video
final randomVideoProvider = FutureProvider.autoDispose((ref) async {
  final querySnapshot = await FirebaseFirestore.instance
      .collection('videos')
      .get();
  
  if (querySnapshot.docs.isEmpty) {
    throw Exception('No videos found');
  }

  final randomIndex = DateTime.now().millisecondsSinceEpoch % querySnapshot.docs.length;
  final randomDoc = querySnapshot.docs[randomIndex];
  
  // Debug log the raw document
  print('Raw Firestore doc: ${randomDoc.data()}');
  
  final video = VideoModel.fromFirestore(randomDoc);
  
  if (video.videoUrl.isEmpty) {
    throw Exception('Video URL is empty');
  }
  
  // Get the actual download URL before returning the video
  if (video.videoUrl.startsWith('gs://')) {
    print('Converting gs:// URL for video ${video.id}');
    final downloadUrl = await getVideoUrl(video.videoUrl);
    
    if (downloadUrl.isEmpty) {
      throw Exception('Failed to get download URL for video ${video.id}');
    }
    
    return VideoModel(
      id: video.id,
      title: video.title,
      description: video.description,
      videoUrl: downloadUrl,
      thumbnailUrl: video.thumbnailUrl,
      creator: video.creator,
      uploadedAt: video.uploadedAt,
    );
  }
  
  return video;
});

Future<String> getVideoUrl(String videoPath) async {
  try {
    // If it's already an HTTPS URL, return it directly
    if (videoPath.startsWith('http')) {
      return videoPath;
    }
    
    // If it's a gs:// URL, extract just the path
    if (videoPath.startsWith('gs://')) {
      videoPath = videoPath.replaceFirst(RegExp(r'gs://[^/]+/'), '');
    }
    
    // Now use just the path with Firebase Storage
    final ref = FirebaseStorage.instance.ref(videoPath);
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  } catch (e) {
    throw Exception('Failed to get video URL: $e');
  }
}

class PaginatedVideoNotifier extends StateNotifier<List<VideoModel>> {
  PaginatedVideoNotifier() : super([]) {
    // _fetchNextBatch();
    _loadLocalVideos();
  }

  void _loadLocalVideos() {
    state = [
      VideoModel.local(id: 'local_1', title: 'Sample Video 1'),
      VideoModel.local(id: 'local_2', title: 'Sample Video 2'),
    ];
  }

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  final int _limit = 5;

  Future<void> _fetchNextBatch() async {
    if (!_hasMore) return;

    // This is probably where we need to select "random" videos
    Query collectionQuery = FirebaseFirestore.instance.collection('videos').orderBy('metadata.uploadedAt', descending: true).limit(_limit);

    if (_lastDoc != null) {
      collectionQuery = collectionQuery.startAfterDocument(_lastDoc!);
    }

    final querySnapshot = await collectionQuery.get();
    if (querySnapshot.docs.isNotEmpty) {
      _lastDoc = querySnapshot.docs.last;
      final videos = querySnapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();
      state = [...state, ...videos];
      if (videos.length < _limit) _hasMore = false;
    } else {
      _hasMore = false;
    }
  }

  // This can be called externally when the user nears the end.
  Future<void> loadMore() async {
    await _fetchNextBatch();
  }
}

final paginatedVideoProvider = StateNotifierProvider<PaginatedVideoNotifier, List<VideoModel>>(
  (ref) => PaginatedVideoNotifier(),
); 