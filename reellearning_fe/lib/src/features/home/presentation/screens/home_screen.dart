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

// Add this provider at the top of the file with other providers
final currentVideoIndexProvider = StateProvider<int>((ref) => 0);

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
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChange() {
    if (_pageController.position.pixels ==
        _pageController.position.maxScrollExtent) {
      return;
    }

    final newIndex = _pageController.page?.round() ?? 0;
    // Update the current video index in the provider
    ref.read(currentVideoIndexProvider.notifier).state = newIndex;

    // Check if we need to load more videos
    final videos = ref.read(paginatedVideoProvider);
    if (videos.length - newIndex <= 2) {
      ref.read(paginatedVideoProvider.notifier).loadMore();
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
                return Stack(
                  children: [
                    Center(
                      child: VideoPlayerWidget(
                        video: videos[index],
                        autoPlay: index == currentIndex,
                        looping: true,
                        isMuted: _isMuted,
                        onMuteChanged: (muted) => setState(() => _isMuted = muted),
                      ),
                    ),
                    // Add feed selection pill at the top
                    if (userProfile != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 0,
                        right: 0,
                        child: FeedSelectionPill(userId: userProfile.uid),
                      ),
                  ],
                );
              },
            ),

          // Video Info Overlay
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: videos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Avatar and Profile Section
                            StreamBuilder<DocumentSnapshot>(
                              stream: (videos[currentIndex].creator
                                      as DocumentReference)
                                  .snapshots(),
                              builder: (context,
                                  AsyncSnapshot<DocumentSnapshot> snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircleAvatar(
                                    radius: 20,
                                    child: Icon(Icons.person),
                                  );
                                }

                                final userData = snapshot.data!.data()
                                    as Map<String, dynamic>;
                                final profile = userData['profile']
                                        as Map<String, dynamic>? ??
                                    {};
                                final creatorId = snapshot.data!.id;

                                return GestureDetector(
                                  onTap: () =>
                                      context.go('/profile/$creatorId'),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: profile['avatarUrl'] !=
                                                null
                                            ? NetworkImage(profile['avatarUrl'])
                                            : null,
                                        child: profile['avatarUrl'] == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            // Video Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    videos[currentIndex].title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Creator Name
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: (videos[currentIndex].creator
                                            as DocumentReference)
                                        .snapshots(),
                                    builder: (context,
                                        AsyncSnapshot<DocumentSnapshot>
                                            snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox.shrink();
                                      }

                                      final userData = snapshot.data!.data()
                                          as Map<String, dynamic>;
                                      final profile = userData['profile']
                                              as Map<String, dynamic>? ??
                                          {};
                                      final creatorId = snapshot.data!.id;

                                      return GestureDetector(
                                        onTap: () =>
                                            context.go('/profile/$creatorId'),
                                        child: Text(
                                          profile['displayName'] ??
                                              'Unknown User',
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
                                    onTap: () {
                                      setState(() {
                                        _showFullDescription =
                                            !_showFullDescription;
                                      });
                                    },
                                    child: Text(
                                      videos[currentIndex].description,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      maxLines: _showFullDescription ? null : 2,
                                      overflow: _showFullDescription
                                          ? null
                                          : TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        VideoUnderstandingButtons(
                          videoId: videos[currentIndex].id,
                          // at some point we will pass classId here (if we create a separate class feed file we need to look at it)
                        ),
                      ],
                    ),
            ),
          ),

          // Right Side Action Buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: videos.isEmpty
                ? const SizedBox()
                : VideoActionButtons(
                    videoId: videos[currentIndex].id,
                    likeCount: videos[currentIndex].engagement.likes,
                  ),
          ),
        ],
      ),
    );
  }
}
