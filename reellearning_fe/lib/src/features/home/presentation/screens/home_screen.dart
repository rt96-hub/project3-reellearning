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
import '../../../videos/data/providers/video_controller_provider.dart';
import '../../../../core/navigation/route_observer.dart';
import '../../../../features/navigation/providers/tab_state_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
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

  void _handlePageChange() {
    if (_pageController.position.pixels == _pageController.position.maxScrollExtent) {
      return;
    }

    final newIndex = _pageController.page?.round() ?? 0;
    final videos = ref.read(paginatedVideoProvider);
    
    // Ensure the new index is within bounds and the videos list is not empty
    if (videos.isNotEmpty && newIndex >= 0 && newIndex < videos.length) {
      print('[HomeScreen] Updating video index to: $newIndex (total videos: ${videos.length})');
      
      // Only update if we're not in the middle of an index adjustment
      final notifier = ref.read(paginatedVideoProvider.notifier) as PaginatedVideoNotifier;
      if (!notifier.isAdjustingIndex) {
        // Update the current video index in the provider
        ref.read(currentVideoIndexProvider.notifier).state = newIndex;
      }

      // Check if we need to load more videos
      if (videos.length - newIndex <= 2) {
        print('[HomeScreen] Near end of feed, loading more videos');
        ref.read(paginatedVideoProvider.notifier).loadMore();
      }
    } else {
      print('[HomeScreen] Invalid index $newIndex for video list of size ${videos.length}');
      // If the index is invalid, try to recover by jumping to the last valid index
      if (videos.isNotEmpty) {
        final lastValidIndex = videos.length - 1;
        print('[HomeScreen] Recovering by jumping to index $lastValidIndex');
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Avatar
                      StreamBuilder<DocumentSnapshot>(
                        stream: (videos[currentIndex].creator as DocumentReference).snapshots(),
                        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                          if (!snapshot.hasData) {
                            return const CircleAvatar(
                              radius: 20,
                              child: Icon(Icons.person),
                            );
                          }

                          final userData = snapshot.data!.data() as Map<String, dynamic>;
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
                              videos[currentIndex].title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Creator Name
                            StreamBuilder<DocumentSnapshot>(
                              stream: (videos[currentIndex].creator as DocumentReference).snapshots(),
                              builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final userData = snapshot.data!.data() as Map<String, dynamic>;
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
                    ],
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
