import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/video_model.dart';
import './video_state_provider.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:reellearning_fe/src/features/questions/models/question_model.dart';

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

// Provider to track current channel ID (null means personal feed)
final currentChannelIdProvider = StateProvider<String?>((ref) => null);

// Create a union type for feed items
abstract class FeedItem {
  String get id;
  DateTime get createdAt;
}

// Make VideoModel implement FeedItem
class VideoFeedItem implements FeedItem {
  final VideoModel video;
  VideoFeedItem(this.video);

  @override
  String get id => video.id;

  @override
  DateTime get createdAt => video.uploadedAt;

  // Forward common video properties
  DocumentReference get creator => video.creator;
  String get title => video.title;
  String get description => video.description;
}

// Make QuestionModel implement FeedItem
class QuestionFeedItem implements FeedItem {
  final QuestionModel question;
  QuestionFeedItem(this.question);

  @override
  String get id => question.id;

  @override
  DateTime get createdAt => question.createdAt;
}

class PaginatedVideoNotifier extends StateNotifier<List<FeedItem>> {
  PaginatedVideoNotifier(this.ref) : super([]) {
    _fetchNextBatch();
  }

  final Ref ref;
  bool _isLoading = false;
  final int _batchSize = 10;
  static const int _maxQueueSize = 50;
  bool _isAdjustingIndex = false;
  
  bool get isAdjustingIndex => _isAdjustingIndex;

  // Method to insert a question into the feed
  void insertQuestion(QuestionModel question, int currentIndex) {
    debugPrint('[PaginatedVideoNotifier] Current index: $currentIndex, Feed length: ${state.length}');
    
    if (currentIndex + 2 >= state.length) {
      // If we're too close to the end, just append it
      state = [...state, QuestionFeedItem(question)];
      debugPrint('[PaginatedVideoNotifier] Appended question to end of feed');
    } else {
      // Replace the video 2 items ahead with the question
      final newState = List<FeedItem>.from(state);
      newState[currentIndex + 2] = QuestionFeedItem(question);
      state = newState;
      debugPrint('[PaginatedVideoNotifier] Replaced item at index ${currentIndex + 2} with question');
    }
  }

  // TODO: Move this to a configuration file
  static const String _functionUrl = 'https://us-central1-reellearning-prj3.cloudfunctions.net/get_videos';

  Future<void> _fetchNextBatch() async {
    if (_isLoading) {
      print('[PaginatedVideoNotifier] Already loading, skipping fetch');
      return;
    }
    
    try {
      _isLoading = true;
      print('[PaginatedVideoNotifier] Starting to fetch next batch');
      
      // Get the current user's ID token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final token = await user.getIdToken();
      
      // Get current channel ID
      final channelId = ref.read(currentChannelIdProvider);
      print('[PaginatedVideoNotifier] Fetching for channel: ${channelId ?? "personal feed"}');
      
      // Build URL with channel ID if present
      var url = Uri.parse('$_functionUrl?limit=$_batchSize');
      if (channelId != null) {
        url = Uri.parse('$_functionUrl?limit=$_batchSize&source_type=class&source_id=$channelId');
      }
      print('[PaginatedVideoNotifier] Requesting URL: $url');
      
      // Make request to our cloud function
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Log debug information
        if (data['debug_info'] != null) {
          print('\n[PaginatedVideoNotifier] Debug Info:');
          
          // Log decision path first
          final decisionPath = data['debug_info']['decision_path'];
          print('Decision Path:');
          print('  Case: ${decisionPath['case']}');
          print('  Reason: ${decisionPath['reason']}');
          print('  Details: ${json.encode(decisionPath['details'])}');
          
          print('\nRecommendation Type: ${data['debug_info']['recommendation_type']}');
          print('Source Vector Info: ${json.encode(data['debug_info']['source_vector_info'])}');
          print('Total Candidates: ${data['debug_info']['total_candidates']}');
          print('Final Selected: ${data['debug_info']['final_selected']}');
          print('Excluded Videos: ${data['debug_info']['excluded_videos'].length}');
          
          // Print similarity scores for top 5 videos
          final scores = data['debug_info']['similarity_scores'];
          if (scores.isNotEmpty) {
            print('\nTop 5 Similarity Scores:');
            final sortedScores = List.from(scores)
              ..sort((a, b) => (b['combined_score'] as num).compareTo(a['combined_score'] as num));
            for (var i = 0; i < math.min(5, sortedScores.length); i++) {
              print('Video ${sortedScores[i]['video_id']}: '
                  'Combined: ${sortedScores[i]['combined_score'].toStringAsFixed(3)}, '
                  'Vector: ${sortedScores[i]['vector_similarity'].toStringAsFixed(3)}, '
                  'Tag: ${sortedScores[i]['tag_similarity'].toStringAsFixed(3)}');
            }
          }
          print(''); // Empty line for readability
        }
        
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
        print('[PaginatedVideoNotifier] Fetched ${resolvedVideos.length} new videos');
        
        if (state.length >= _maxQueueSize) {
          print('[PaginatedVideoNotifier] Queue full (${state.length} videos), removing oldest batch');
          
          // Get current index before modifying state
          final currentIndex = ref.read(currentVideoIndexProvider);
          
          // Calculate new index after removing batch
          final newIndex = currentIndex >= _batchSize ? currentIndex - _batchSize : 0;
          print('[PaginatedVideoNotifier] Adjusting index from $currentIndex to $newIndex');
          
          // Update state first
          state = [...state.sublist(_batchSize), ...resolvedVideos.map((v) => VideoFeedItem(v))];
          
          // Set flag to prevent index updates from page controller
          _isAdjustingIndex = true;
          
          // Then update the index to ensure it's valid for the new state
          if (newIndex < state.length) {
            ref.read(currentVideoIndexProvider.notifier).state = newIndex;
            // Notify that page controller needs to update
            ref.read(forcePageJumpProvider.notifier).state = newIndex;
          }
          
          // Reset flag after a short delay to allow page controller to update
          Future.delayed(const Duration(milliseconds: 100), () {
            _isAdjustingIndex = false;
          });
        } else {
          print('[PaginatedVideoNotifier] Adding videos to queue (current size: ${state.length})');
          state = [...state, ...resolvedVideos.map((v) => VideoFeedItem(v))];
        }
        print('[PaginatedVideoNotifier] New queue size: ${state.length}');
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
    final index = ref.read(currentVideoIndexProvider);
    print('[PaginatedVideoNotifier] Current video index: $index');
    return index;
  }

  Future<void> loadMore() async {
    print('[PaginatedVideoNotifier] Loading more videos');
    await _fetchNextBatch();
  }
  
  Future<void> refresh() async {
    print('[PaginatedVideoNotifier] Starting refresh');
    print('[PaginatedVideoNotifier] Current state size: ${state.length}');
    state = [];
    print('[PaginatedVideoNotifier] Cleared state, new size: ${state.length}');
    
    // Reset current video index when switching feeds
    final oldIndex = ref.read(currentVideoIndexProvider);
    ref.read(currentVideoIndexProvider.notifier).state = 0;
    print('[PaginatedVideoNotifier] Reset video index from $oldIndex to 0');
    
    print('[PaginatedVideoNotifier] Fetching new batch after refresh');
    await _fetchNextBatch();
    print('[PaginatedVideoNotifier] Refresh complete, new state size: ${state.length}');
  }
}

// Provider to force page jumps
final forcePageJumpProvider = StateProvider<int?>((ref) => null);

final paginatedVideoProvider = StateNotifierProvider<PaginatedVideoNotifier, List<FeedItem>>(
  (ref) => PaginatedVideoNotifier(ref),
); 