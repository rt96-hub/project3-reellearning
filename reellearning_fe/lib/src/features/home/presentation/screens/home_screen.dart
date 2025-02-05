import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_provider.dart';
import 'package:reellearning_fe/src/features/videos/presentation/widgets/video_player_widget.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/video_action_buttons.dart';
import '../widgets/video_understanding_buttons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentVideoIndex = 0;
  int _currentNavIndex = 0;
  bool _showFullDescription = false;
  
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
    if (_pageController.position.pixels == _pageController.position.maxScrollExtent) {
      return;
    }

    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex != _currentVideoIndex) {
      setState(() => _currentVideoIndex = newIndex);
      
      // Check if we need to load more videos
      final videos = ref.read(paginatedVideoProvider);
      if (videos.length - newIndex <= 2) {
        ref.read(paginatedVideoProvider.notifier).loadMore();
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentNavIndex = index);
    
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/classes');
        break;
      case 2:
        context.go('/search');
        break;
      case 3:
        context.go('/messages');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(paginatedVideoProvider);
    final userProfile = ref.watch(currentUserProvider);

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
                return Center(
                  child: VideoPlayerWidget(
                    video: videos[index],
                    autoPlay: index == _currentVideoIndex,
                    looping: true,
                  ),
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
                        // User Avatar
                        const CircleAvatar(
                          radius: 20,
                          backgroundImage: AssetImage('assets/placeholder.png'),
                        ),
                        const SizedBox(width: 12),
                        // Video Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                videos[_currentVideoIndex].title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showFullDescription = !_showFullDescription;
                                  });
                                },
                                child: Text(
                                  videos[_currentVideoIndex].description,
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
                    const SizedBox(height: 16),
                    const VideoUnderstandingButtons(),
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
                  videoId: videos[_currentVideoIndex].id,
                  likeCount: videos[_currentVideoIndex].engagement.likes,
                ),
          ),

          // Bottom Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
} 