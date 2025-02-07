import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/video_model.dart';
import './video_state_provider.dart';

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
      engagement: video.engagement,
      duration: video.duration,
      uploadedAt: video.uploadedAt,
      updatedAt: video.updatedAt,
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
  PaginatedVideoNotifier(this.ref) : super([]) {
    _fetchNextBatch();
  }

  final Ref ref;
  bool _isLoading = false;
  final int _batchSize = 5;
  static const int _maxQueueSize = 50;  // Maximum number of videos to keep in queue
  
  // TODO: Move this to a configuration file
  static const String _functionUrl = 'https://us-central1-reellearning-prj3.cloudfunctions.net/get_videos';

  Future<void> _fetchNextBatch() async {
    if (_isLoading) return;
    
    try {
      _isLoading = true;
      
      // Get the current user's ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final token = await user.getIdToken();
      
      // Make request to our cloud function
      final response = await http.get(
        Uri.parse('$_functionUrl?limit=$_batchSize'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = (data['videos'] as List).map((videoJson) async {
          // If the video URL is a gs:// URL, convert it to a download URL
          String videoUrl = videoJson['videoUrl'];
          if (videoUrl.startsWith('gs://')) {
            videoUrl = await getVideoUrl(videoUrl);
          }
          
          final engagement = videoJson['engagement'] as Map<String, dynamic>;
          final creatorData = videoJson['creator'] as Map<String, dynamic>;
          
          // Create a valid Firestore document reference
          DocumentReference creatorRef;
          try {
            var creatorPath = creatorData['path'] as String;
            // Remove any leading or trailing slashes and spaces
            creatorPath = creatorPath.trim().replaceAll(RegExp(r'^/+|/+$'), '');
            creatorRef = FirebaseFirestore.instance.doc(creatorPath);
          } catch (e) {
            // If there's any issue, fallback to a default user reference
            creatorRef = FirebaseFirestore.instance.doc('users/unknown');
            print('Error creating creator reference: $e');
          }
          
          return VideoModel(
            id: videoJson['id'],
            title: videoJson['title'],
            description: videoJson['description'],
            videoUrl: videoUrl,
            thumbnailUrl: videoJson['thumbnailUrl'],
            duration: videoJson['duration'].toDouble(),
            uploadedAt: DateTime.parse(videoJson['uploadedAt']),
            updatedAt: DateTime.parse(videoJson['updatedAt']),
            creator: creatorRef,
            engagement: VideoEngagement(
              views: engagement['views'] ?? 0,
              likes: engagement['likes'] ?? 0,
              shares: engagement['shares'] ?? 0,
              completionRate: (engagement['completionRate'] ?? 0).toDouble(),
              averageWatchTime: (engagement['averageWatchTime'] ?? 0).toDouble(),
            ),
          );
        }).toList();
        
        // Wait for all video URL conversions to complete
        final resolvedVideos = await Future.wait(videos);
        
        if (state.length >= _maxQueueSize) {
          // Remove oldest batch of videos when adding new ones
          state = [...state.sublist(_batchSize), ...resolvedVideos];
        } else {
          state = [...state, ...resolvedVideos];
        }
      } else {
        print('Error fetching videos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching videos: $e');
    } finally {
      _isLoading = false;
    }
  }

  // Helper method to get current video index
  int _getCurrentVideoIndex() {
    return ref.read(currentVideoIndexProvider);
  }

  Future<void> loadMore() async {
    await _fetchNextBatch();
  }
  
  Future<void> refresh() async {
    state = [];
    await _fetchNextBatch();
  }
}

final paginatedVideoProvider = StateNotifierProvider<PaginatedVideoNotifier, List<VideoModel>>(
  (ref) => PaginatedVideoNotifier(ref),
); 