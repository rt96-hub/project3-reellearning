import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_provider.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_state_provider.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/video_player_widget.dart';
import '../widgets/video_action_buttons.dart';
import '../widgets/video_understanding_buttons.dart';
import '../widgets/feed_selection_pill.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController();
  bool _showFullDescription = false;
  bool _isMuted = false;

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

      // Listen for feed changes
      ref.listen(currentChannelIdProvider, (previous, next) {
        print('[HomeScreen] Feed changed from $previous to $next');
        // Reset page controller when feed changes
        _pageController.jumpToPage(0);
      });
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChange() {
    if (_pageController.position.pixels == _pageController.position.maxScrollExtent) {
      return;
    }

    final newIndex = _pageController.page?.round() ?? 0;
    final videos = ref.read(paginatedVideoProvider);
    
    // Ensure the new index is within bounds
    if (newIndex >= 0 && newIndex < videos.length) {
      print('[HomeScreen] Updating video index to: $newIndex (total videos: ${videos.length})');
      // Update the current video index in the provider
      ref.read(currentVideoIndexProvider.notifier).state = newIndex;

      // Check if we need to load more videos
      if (videos.length - newIndex <= 2) {
        print('[HomeScreen] Near end of feed, loading more videos');
        ref.read(paginatedVideoProvider.notifier).loadMore();
      }
    } else {
      print('[HomeScreen] Invalid index $newIndex for video list of size ${videos.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(paginatedVideoProvider);
    final userProfile = ref.watch(currentUserProvider);
    final currentIndex = ref.watch(currentVideoIndexProvider);

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
                return VideoPlayerWidget(
                  video: videos[index],
                  autoPlay: index == currentIndex,
                  isMuted: _isMuted,
                  onMuteChanged: (muted) => setState(() => _isMuted = muted),
                );
              },
            ),

          // Feed Selection Pill (Overlay)
          if (userProfile != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: MediaQuery.of(context).size.width * 0.18, // 30% from left
              right: MediaQuery.of(context).size.width * 0.18, // 30% from right
              child: FeedSelectionPill(userId: userProfile.uid),
            ),

          // Video Actions (Overlay)
          if (videos.isNotEmpty)
            Positioned(
              right: 8,
              bottom: 80,
              child: VideoActionButtons(
                videoId: videos[currentIndex].id,
                likeCount: videos[currentIndex].engagement.likes,
              ),
            ),

          // Video Info Overlay
          if (videos.isNotEmpty)
            Positioned(
              left: 16,
              right: 48, // Leave space for action buttons
              bottom: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    videos[currentIndex].title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showFullDescription = !_showFullDescription),
                    child: Text(
                      videos[currentIndex].description,
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

          // Understanding Buttons (Overlay)
          if (videos.isNotEmpty && userProfile != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: VideoUnderstandingButtons(
                videoId: videos[currentIndex].id,
              ),
            ),
        ],
      ),
    );
  }
}
