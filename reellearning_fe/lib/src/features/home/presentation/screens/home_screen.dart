import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_provider.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_state_provider.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/video_player_widget.dart';
import 'package:reellearning_fe/src/features/questions/models/question_model.dart';
import 'package:reellearning_fe/src/features/questions/widgets/question_card.dart';
import '../widgets/video_action_buttons.dart';
import '../widgets/video_understanding_buttons.dart';
import '../widgets/feed_selection_pill.dart';
import '../../../videos/data/providers/video_controller_provider.dart';
import '../../../../core/navigation/route_observer.dart';
import '../../../../features/navigation/providers/tab_state_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  final PageController _pageController = PageController();
  bool _showFullDescription = false;
  bool _isMuted = false;
  Timer? _questionTimer;  // Add timer for question generation
  List<String> _recentVideoIds = [];  // Track recent video IDs

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageChange);
    
    // Initialize personal feed when user logs in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = ref.read(currentUserProvider);
      if (userProfile != null) {
        ref.read(currentChannelIdProvider.notifier).state = null;
        ref.read(selectedFeedProvider.notifier).state = 'personal';
        ref.read(paginatedVideoProvider.notifier).refresh();
      }
    });

    // Initialize question timer
    _questionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndGenerateQuestion();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRouteObservers.rootObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppRouteObservers.rootObserver.unsubscribe(this);
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    _questionTimer?.cancel();  // Cancel timer on dispose
    super.dispose();
  }

  @override
  void didPushNext() {
    debugPrint('HomeScreen - Leaving screen');
    ref.read(videoControllerProvider.notifier).pauseAndRemember();
  }

  @override
  void didPopNext() {
    debugPrint('HomeScreen - Returning to screen');
    ref.read(videoControllerProvider.notifier).resumeIfNeeded();
  }

  // Add method to track video IDs
  void _updateRecentVideos(String videoId) {
    final now = DateTime.now();
    
    // Only add if not already in the list
    if (!_recentVideoIds.contains(videoId)) {
      setState(() {
        _recentVideoIds.add(videoId);
        
        // Keep only videos from last 2 minutes
        final twoMinutesAgo = now.subtract(const Duration(minutes: 2));
        _recentVideoIds = _recentVideoIds.where((id) {
          final watchTime = now;  // For now, just use current time
          return watchTime.isAfter(twoMinutesAgo);
        }).toList();
      });
      
      debugPrint('[HomeScreen] Added video $videoId to recent videos. Total: ${_recentVideoIds.length}');
    }
  }

  // Add method to reset video list
  void _resetRecentVideos() {
    if (_recentVideoIds.isNotEmpty) {
      setState(() {
        _recentVideoIds = [];
      });
      debugPrint('[HomeScreen] Reset recent videos list due to feed change');
    }
  }

  // Add method to check and generate question
  Future<void> _checkAndGenerateQuestion() async {
    /**************************************************************************
     * IN-FEED QUESTION GENERATION LOGIC
     * 
     * This method is called periodically (currently every 30 seconds, will be 
     * changed to 2 minutes in production) to potentially generate a question
     * based on recently watched videos.
     * 
     * Conditions for generating a question:
     * 1. Must have at least one video in _recentVideoIds
     * 2. Videos must have been watched to 80% completion (handled by VideoPlayerWidget)
     * 3. User must be authenticated
     * 
     * After a successful request:
     * - The list of watched videos is cleared to start fresh
     * - A new question will be inserted into the feed (TODO)
     * 
     * Future improvements:
     * - Increase timer to 2 minutes
     * - Add minimum number of watched videos requirement
     * - Add cooldown period between questions
     * - Add maximum questions per session limit
     **************************************************************************/

    // Check if we have any watched videos
    if (_recentVideoIds.isEmpty) {
      debugPrint('[Question Generation] No watched videos available, skipping question generation');
      return;
    }

    try {
      final userProfile = ref.read(currentUserProvider);
      if (userProfile == null) {
        debugPrint('[Question Generation] No authenticated user, skipping question generation');
        return;
      }

      final currentIndex = ref.read(currentVideoIndexProvider);
      debugPrint('[Question Generation] Current video index: $currentIndex');
      debugPrint('[Question Generation] Generating question for ${_recentVideoIds.length} videos: ${_recentVideoIds.join(", ")}');

      // Store video IDs before clearing them
      final videoIdsForQuestion = List<String>.from(_recentVideoIds);
      
      // Clear the list before making the request to prevent duplicate questions
      setState(() {
        _recentVideoIds = [];
      });
      debugPrint('[Question Generation] Cleared watched videos list before making request');

      // Get Firebase auth token
      final token = await userProfile.getIdToken();
      
      // Call the question generation endpoint
      final response = await http.post(
        Uri.parse('https://us-central1-reellearning-prj3.cloudfunctions.net/generate_in_feed_question'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'videoIds': videoIdsForQuestion,
        }),
      );

      if (response.statusCode == 200) {
        final questionData = json.decode(response.body);
        debugPrint('[Question Generation] Successfully generated question: ${questionData['questionId']}');
        
        // Create question model from response
        final question = QuestionModel.fromJson(questionData);
        
        // Get the current index again to insert question 2 positions after
        final insertIndex = ref.read(currentVideoIndexProvider) + 2;
        debugPrint('[Question Generation] Inserting question at index: $insertIndex (current index: ${ref.read(currentVideoIndexProvider)})');
        
        // Insert question into feed
        ref.read(paginatedVideoProvider.notifier).insertQuestion(
          question,
          insertIndex,
        );
      } else {
        debugPrint('[Question Generation] Failed to generate question. Status: ${response.statusCode}, Body: ${response.body}');
        // Restore the video IDs if request failed
        setState(() {
          _recentVideoIds = videoIdsForQuestion;
        });
        debugPrint('[Question Generation] Restored video IDs due to failed request');
      }
    } catch (e) {
      debugPrint('[Question Generation] Error generating question: $e');
      // Don't restore video IDs on error to prevent infinite retry loops
    }
  }

  void _handlePageChange() {
    if (_pageController.position.pixels == _pageController.position.maxScrollExtent) {
      return;
    }

    final newIndex = _pageController.page?.round() ?? 0;
    final items = ref.read(paginatedVideoProvider);
    
    // Ensure the new index is within bounds and the feed is not empty
    if (items.isNotEmpty && newIndex >= 0 && newIndex < items.length) {
      debugPrint('[HomeScreen] Updating index to: $newIndex (total items: ${items.length})');
      
      // Remove tracking video ID here since we only want to track completed videos
      // final currentItem = items[newIndex];
      // if (currentItem is VideoFeedItem) {
      //   _updateRecentVideos(currentItem.video.id);
      // }
      
      // Only update if we're not in the middle of an index adjustment
      final notifier = ref.read(paginatedVideoProvider.notifier) as PaginatedVideoNotifier;
      if (!notifier.isAdjustingIndex) {
        // Update the current index in the provider
        ref.read(currentVideoIndexProvider.notifier).state = newIndex;
      }

      // Check if we need to load more items
      if (items.length - newIndex <= 4) {
        debugPrint('[HomeScreen] Near end of feed, loading more items');
        ref.read(paginatedVideoProvider.notifier).loadMore();
      }
    } else {
      debugPrint('[HomeScreen] Invalid index $newIndex for feed of size ${items.length}');
      // If the index is invalid, try to recover by jumping to the last valid index
      if (items.isNotEmpty) {
        final lastValidIndex = items.length - 1;
        debugPrint('[HomeScreen] Recovering by jumping to index $lastValidIndex');
        _pageController.jumpToPage(lastValidIndex);
        ref.read(currentVideoIndexProvider.notifier).state = lastValidIndex;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to tab changes
    ref.listen(tabStateProvider, (previous, next) {
      if (previous != null && next == 0) {
        // We're returning to the home tab
        ref.read(videoControllerProvider.notifier).resumeIfNeeded();
      }
    });

    // Listen for feed changes in build method
    ref.listen(currentChannelIdProvider, (previous, next) {
      print('[HomeScreen] Feed changed from $previous to $next');
      // Reset page controller when feed changes
      _pageController.jumpToPage(0);
      // Reset recent videos list when feed changes
      _resetRecentVideos();
    });

    // Listen to forced page jumps
    ref.listen(forcePageJumpProvider, (previous, next) {
      if (next != null && _pageController.hasClients) {
        print('[HomeScreen] Forced jump to page $next');
        _pageController.jumpToPage(next);
        // Reset the force jump provider
        ref.read(forcePageJumpProvider.notifier).state = null;
      }
    });

    final videos = ref.watch(paginatedVideoProvider);
    final currentIndex = ref.watch(currentVideoIndexProvider);
    final userProfile = ref.watch(currentUserProvider);
    
    if (videos.isEmpty || currentIndex >= videos.length || userProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentItem = videos[currentIndex];
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video PageView
          if (videos.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final item = videos[index];
                
                // Handle different feed item types
                if (item is VideoFeedItem) {
                  return VideoPlayerWidget(
                    video: item.video,
                    autoPlay: index == currentIndex,
                    isMuted: _isMuted,
                    onMuteChanged: (muted) => setState(() => _isMuted = muted),
                    userId: userProfile.uid,
                    onVideoWatched: _updateRecentVideos,
                  );
                } else if (item is QuestionFeedItem) {
                  return QuestionCard(
                    question: item.question,
                    onAnswer: (selectedAnswer) {
                      // TODO: Handle answer selection
                      if (selectedAnswer == item.question.correctAnswer) {
                        // TODO: Show explanation
                      }
                    },
                  );
                } else {
                  return const SizedBox.shrink();  // Fallback
                }
              },
            ),

          // Feed Selection Pill (Overlay)
          if (userProfile != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: MediaQuery.of(context).size.width * 0.18,
              right: MediaQuery.of(context).size.width * 0.18,
              child: FeedSelectionPill(userId: userProfile.uid),
            ),

          // Video Actions and Info (Only show for video items)
          if (currentItem is VideoFeedItem) ...[
            // Video Actions (Overlay)
            Positioned(
              right: 8,
              bottom: 80,
              child: SizedBox(
                width: 72,
                child: VideoActionButtons(
                  videoId: currentItem.video.id,
                ),
              ),
            ),

            // Video Info Overlay
            Positioned(
              left: 16,
              right: 88,
              bottom: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Avatar
                      StreamBuilder<DocumentSnapshot>(
                        stream: currentItem.video.creator.snapshots(),
                        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const CircleAvatar(
                              radius: 20,
                              child: Icon(Icons.person),
                            );
                          }

                          final userData = snapshot.data!.data() as Map<String, dynamic>?;
                          if (userData == null) {
                            return const CircleAvatar(
                              radius: 20,
                              child: Icon(Icons.person),
                            );
                          }

                          final profile = userData['profile'] as Map<String, dynamic>? ?? {};
                          final creatorId = snapshot.data!.id;

                          return GestureDetector(
                            onTap: () => context.go('/profile/$creatorId'),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: profile['avatarUrl'] != null
                                  ? NetworkImage(profile['avatarUrl'])
                                  : null,
                              child: profile['avatarUrl'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      // Text Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentItem.video.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Creator Name
                            StreamBuilder<DocumentSnapshot>(
                              stream: currentItem.video.creator.snapshots(),
                              builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return const Text(
                                    'Unknown User',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  );
                                }

                                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                if (userData == null) {
                                  return const Text(
                                    'Unknown User',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  );
                                }

                                final profile = userData['profile'] as Map<String, dynamic>? ?? {};
                                final creatorId = snapshot.data!.id;

                                return GestureDetector(
                                  onTap: () => context.go('/profile/$creatorId'),
                                  child: Text(
                                    profile['displayName'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => setState(() => _showFullDescription = !_showFullDescription),
                              child: Text(
                                currentItem.video.description,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: _showFullDescription ? null : 2,
                                overflow: _showFullDescription ? null : TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Understanding Buttons (Overlay)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: VideoUnderstandingButtons(
                videoId: currentItem.video.id,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
