import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reellearning_fe/src/features/auth/data/providers/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/video_action_buttons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _showFullDescription = false;
  
  final String _description = 
    "This is an amazing video showing the beautiful sunset at the beach. "
    "The waves are crashing against the shore while seagulls fly overhead, "
    "creating a perfect moment of peace and tranquility.";

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    
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
    // Add user context
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Video Container
          Container(
            color: Colors.black,
            child: const Center(
              child: Placeholder(), // Replace with actual video player
            ),
          ),

          // Video Info Overlay
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: const AssetImage('assets/placeholder.png'),
                    // need to make the avatar a profile picture of the video creator. so will not be a placeholder
                  ),
                  const SizedBox(width: 12),
                  // Username and Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '@username',
                          style: TextStyle(
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
                            _description,
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
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
} 