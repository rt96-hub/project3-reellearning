import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import 'package:reellearning_fe/src/features/videos/data/providers/video_provider.dart';
import 'package:reellearning_fe/src/shared/widgets/video_player_widget.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/video_action_buttons.dart';

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
  
  void _onTabTapped(int index) {
    setState(() => _currentNavIndex = index);
    
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/messages');
        break;
      case 2:
        context.go('/classes');
        break;
      case 3:
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
          // Video Container
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) async {
              setState(() {
                _currentVideoIndex = index;
              });
              // If the user is near the end, load more videos
              if (index >= videos.length - 2) {
                await ref.read(paginatedVideoProvider.notifier).loadMore();
              }
            },
            itemBuilder: (context, index) {
              final video = videos[index];
              return SizedBox.expand(
                child: video.videoUrl.isNotEmpty
                    ? VideoPlayerWidget(videoUrl: video.videoUrl)
                    : const Center(
                        child: Text(
                          'Video URL not available',
                          style: TextStyle(color: Colors.white),
                        ),
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
                : Row(
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
            ),
          ),

          // Right Side Action Buttons
          const Positioned(
            right: 16,
            bottom: 100,
            child: VideoActionButtons(),
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